defmodule Xylem.BaumBie.Importer do
  @moduledoc """
  Orchestrates the Wikidata import into the BaumBie attribute model (Supabase).

  Phases:
  - Phase 0/1 – derive `tree_types` from the tree cadastre and set `wikidata_id`
    via botanical-name matching (combined into a single upsert per tree type).
  - Phase 2a – upsert the `"wikidata"` provider and the `tree_type_attributes`.
  - Phase 2b – rewrite `tree_type_attribute_values` (delete Wikidata values of
    the affected tree types, then batch insert).

  `--dry-run` computes and reports the same counts without any write access, so
  it never needs the Supabase connection.
  """

  require Logger

  alias Xylem.BaumBie.Repo
  alias Xylem.BaumBie.Importer.{AttributeWriter, ImportPlan, ReviewCSV, TreeTypeMapper}
  alias Xylem.Import.CSVReader
  alias Xylem.Supabase
  alias Xylem.UnexpectedSupabaseResponseError
  alias Xylem.Wikidata.PropertyConfig

  @default_input "priv/data/wikidata/export.csv"
  @default_trees "../trees2.geojson"
  @provider_name "wikidata"

  @type summary :: %{
          tree_types_derived: non_neg_integer(),
          matched: non_neg_integer(),
          unmatched_cadastre: non_neg_integer(),
          unmatched_mapping: non_neg_integer(),
          attributes: non_neg_integer(),
          values: non_neg_integer(),
          skipped_values: non_neg_integer(),
          warnings: non_neg_integer(),
          dry_run: boolean()
        }

  @doc """
  Runs the import.

  ## Options

  - `:input` - review CSV path (default: `#{@default_input}`)
  - `:config` - property config CSV path (default: `Xylem.Wikidata.PropertyConfig.default_path/0`)
  - `:mapping` - Wikidata mapping CSV path (default: `Xylem.default_csv_path/0`)
  - `:trees` - cadastre GeoJSON path (default: `#{@default_trees}`)
  - `:dry_run` - report without writing (default: `false`)
  """
  @spec run(keyword()) :: {:ok, summary()} | {:error, term()}
  def run(opts \\ []) do
    input = Keyword.get(opts, :input, @default_input)
    config_path = Keyword.get(opts, :config, PropertyConfig.default_path())
    mapping_path = Keyword.get(opts, :mapping, Xylem.default_csv_path())
    trees_path = Keyword.get(opts, :trees, @default_trees)
    dry_run = Keyword.get(opts, :dry_run, false)

    with {:ok, config} <- PropertyConfig.load(path: config_path),
         {:ok, review_rows} <- ReviewCSV.run(input),
         {:ok, mapping} <- CSVReader.run(mapping_path),
         {:ok, features} <- TreeTypeMapper.load_features(trees_path),
         species = TreeTypeMapper.distinct_species(features),
         {:ok, plan} <- ImportPlan.build(config, mapping, review_rows, species) do
      log_plan(plan)

      if dry_run do
        log_dry_run_details(plan)
        {:ok, summary(plan, true)}
      else
        do_import(plan)
      end
    end
  end

  defp log_plan(plan) do
    Enum.each(plan.unmatched_cadastre, fn %{name_botanic: bo} ->
      Logger.info(
        "Cadastre species without Wikidata mapping: #{bo} (tree_type without wikidata_id)"
      )
    end)

    Enum.each(plan.unmatched_mapping, fn %{baumart_bo: bo} ->
      Logger.warning("Mapping entry without cadastre species: #{bo} (no tree_type created)")
    end)

    log_groups(plan.warnings, :code, "Import preflight warnings")
    log_groups(plan.skips, :reason, "Skipped review values")
  end

  defp log_groups(items, key, label) do
    items
    |> Enum.group_by(&Map.fetch!(&1, key))
    |> Enum.sort_by(fn {code, _items} -> code end)
    |> Enum.each(fn {code, grouped} ->
      Logger.warning(
        "#{label}: #{length(grouped)} #{code}; examples: #{inspect(Enum.take(grouped, 3))}"
      )
    end)
  end

  defp log_dry_run_details(plan) do
    details = ImportPlan.details(plan)

    Enum.each(details.species, fn species ->
      Logger.info(
        "Dry-run species: #{species.name_botanic} | status=#{species.status} | " <>
          "wikidata_id=#{species.wikidata_id || "none"} | values=#{species.value_count} | " <>
          "skips=#{format_counts(species.skips)}"
      )
    end)

    Enum.each(details.attributes, fn attribute ->
      Logger.info(
        "Dry-run attribute: #{attribute.property_id} | #{attribute.attribute_name} | " <>
          "type=#{attribute.type} | values=#{attribute.value_count}"
      )
    end)

    Logger.info(
      "Dry-run totals: warnings=#{sum_counts(details.warnings)} | " <>
        "skips=#{sum_counts(details.skips)}"
    )
  end

  defp format_counts(counts) when map_size(counts) == 0, do: "none"

  defp format_counts(counts) do
    counts
    |> Enum.sort_by(fn {reason, _count} -> reason end)
    |> Enum.map_join(",", fn {reason, count} -> "#{reason}=#{count}" end)
  end

  defp sum_counts(counts), do: counts |> Map.values() |> Enum.sum()

  ## Import

  defp do_import(plan) do
    with {:ok, client} <- Supabase.client(),
         {:ok, tree_type_uuids} <- upsert_tree_types(client, plan.species, plan.wikidata_by_bo),
         {:ok, provider_uuid} <- upsert_provider(client),
         {:ok, current_attribute_uuids} <-
           upsert_attributes(client, plan.attribute_defs, provider_uuid),
         {:ok, wikidata_attribute_uuids} <-
           Repo.attribute_uuids_for_provider(client, provider_uuid) do
      write_values(
        client,
        plan,
        tree_type_uuids,
        current_attribute_uuids,
        wikidata_attribute_uuids
      )
    end
  end

  defp upsert_provider(client) do
    Logger.info("Provider setup: #{@provider_name}")

    case Repo.upsert(client, "providers", %{"name" => @provider_name}, "name") do
      {:ok, %{"uuid" => uuid}} -> {:ok, uuid}
      {:ok, other} -> missing_uuid("providers", other)
      {:error, _} = error -> error
    end
  end

  defp upsert_tree_types(client, species, wikidata_by_bo) do
    Logger.info("Phase 0/1: deriving #{length(species)} tree_types")

    Enum.reduce_while(species, {:ok, %{}}, fn sp, {:ok, acc} ->
      row = TreeTypeMapper.build_tree_type_row(sp, Map.get(wikidata_by_bo, sp.name_botanic))

      case Repo.upsert(client, "tree_types", row, "name_botanic") do
        {:ok, %{"uuid" => uuid}} -> {:cont, {:ok, Map.put(acc, sp.name_botanic, uuid)}}
        {:ok, other} -> {:halt, missing_uuid("tree_types", other)}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp upsert_attributes(client, attribute_defs, provider_uuid) do
    Logger.info("Phase 2a: upserting #{length(attribute_defs)} attributes")

    Enum.reduce_while(attribute_defs, {:ok, %{}}, fn adef, {:ok, by_property} ->
      row =
        AttributeWriter.build_attribute_row(
          adef.property_id,
          adef.attribute_name,
          adef.entry,
          provider_uuid
        )

      case Repo.upsert(client, "tree_type_attributes", row, "provider_uuid,name") do
        {:ok, %{"uuid" => uuid}} -> {:cont, {:ok, Map.put(by_property, adef.property_id, uuid)}}
        {:ok, other} -> {:halt, missing_uuid("tree_type_attributes", other)}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp write_values(
         client,
         plan,
         tree_type_uuids,
         current_attribute_uuids,
         wikidata_attribute_uuids
       ) do
    type_by_property = Map.new(plan.attribute_defs, &{&1.property_id, &1.type})

    value_rows =
      Enum.map(plan.value_rows, fn row ->
        AttributeWriter.build_value_row(
          row,
          Map.fetch!(tree_type_uuids, row.baumart_bo),
          Map.fetch!(current_attribute_uuids, row.property_id),
          Map.fetch!(type_by_property, row.property_id)
        )
      end)

    affected_tree_types = Map.values(tree_type_uuids)

    Logger.info("Phase 2b: rewriting #{length(value_rows)} values")

    with :ok <- Repo.delete_values_for(client, affected_tree_types, wikidata_attribute_uuids),
         :ok <- Repo.insert_batch(client, "tree_type_attribute_values", value_rows) do
      {:ok, summary(plan, false)}
    end
  end

  defp missing_uuid(table, response) do
    {:error,
     %UnexpectedSupabaseResponseError{
       operation: :upsert,
       table: table,
       reason: :missing_uuid,
       response: response
     }}
  end

  defp summary(plan, dry_run) do
    warnings = plan |> ImportPlan.warning_counts() |> sum_counts()
    Map.merge(plan.summary, %{warnings: warnings, dry_run: dry_run})
  end
end
