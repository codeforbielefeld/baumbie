defmodule Xylem.BaumBie.Importer.ImportPlan do
  @moduledoc """
  Builds the complete, side-effect-free decision for a Wikidata import.

  The validated mapping targets are the `tree_types`, so export and import work
  on the same species list.

  The dry-run and write path consume the same plan so validation and skip
  decisions cannot diverge after Supabase writes have started.
  """

  alias Xylem.BaumBie.Importer.TypeMapper
  alias Xylem.Import.Mapping
  alias Xylem.ImportPreflightError
  alias Xylem.Wikidata
  alias Xylem.Wikidata.PropertyConfig

  @enforce_keys [:targets, :attribute_defs, :value_rows, :skips, :warnings, :summary]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          targets: [Mapping.target()],
          attribute_defs: [map()],
          value_rows: [map()],
          skips: [map()],
          warnings: [map()],
          summary: map()
        }

  @doc "Builds and validates an import plan from already parsed inputs."
  @spec build(PropertyConfig.t(), [map()], [map()]) ::
          {:ok, t()} | {:error, ImportPreflightError.t()}
  def build(%PropertyConfig{} = config, mapping, review_rows) do
    indexed_rows = Enum.with_index(review_rows, 2)
    {targets, mapping_warnings, mapping_issues} = prepare_mapping(mapping)
    {review_warnings, review_issues} = validate_review_rows(indexed_rows, targets, config)
    attribute_defs = attribute_defs(config, review_rows)

    issues = mapping_issues ++ review_issues ++ attribute_key_issues(attribute_defs)

    if issues == [] do
      {:ok,
       build_plan(
         config,
         targets,
         indexed_rows,
         attribute_defs,
         mapping_warnings ++ review_warnings ++ datatype_warnings(attribute_defs)
       )}
    else
      {:error, %ImportPreflightError{issues: issues}}
    end
  end

  @doc "Projects deterministic, database-free details for dry-run reporting."
  @spec details(t()) :: map()
  def details(%__MODULE__{} = plan) do
    values_by_species = Enum.frequencies_by(plan.value_rows, & &1.baumart_bo)
    values_by_property = Enum.frequencies_by(plan.value_rows, & &1.property_id)

    skips_by_species =
      plan.skips
      |> Enum.group_by(& &1.baumart_bo)
      |> Map.new(fn {name, skips} -> {name, Enum.frequencies_by(skips, & &1.reason)} end)

    species =
      plan.targets
      |> Enum.sort_by(& &1.baumart_bo)
      |> Enum.map(fn target ->
        %{
          name_botanic: target.baumart_bo,
          wikidata_id: target.wikidata_id,
          value_count: Map.get(values_by_species, target.baumart_bo, 0),
          skips: Map.get(skips_by_species, target.baumart_bo, %{})
        }
      end)

    attributes =
      plan.attribute_defs
      |> Enum.sort_by(& &1.property_id)
      |> Enum.map(fn attribute ->
        %{
          property_id: attribute.property_id,
          attribute_name: attribute.attribute_name,
          type: attribute.type,
          value_count: Map.get(values_by_property, attribute.property_id, 0)
        }
      end)

    %{
      species: species,
      attributes: attributes,
      warnings: warning_counts(plan),
      skips: Enum.frequencies_by(plan.skips, & &1.reason)
    }
  end

  @doc false
  @spec warning_counts(t()) :: %{optional(atom()) => pos_integer()}
  def warning_counts(%__MODULE__{} = plan), do: Enum.frequencies_by(plan.warnings, & &1.code)

  # Delegated so export and import cannot drift apart on what a mapping identity
  # is; the issues come back in this module's shape and join its own preflight.
  defp prepare_mapping(mapping), do: Mapping.validate(mapping)

  defp validate_review_rows(indexed_rows, mapping, config) do
    mapping_by_name = Map.new(mapping, &{Mapping.canonical_name(&1.baumart_bo), &1})

    indexed_rows
    |> Enum.reduce({[], []}, fn {row, line}, {warnings, issues} ->
      {identity_warnings, identity_issues} = validate_identity(row, line, mapping_by_name)
      config_issues = validate_attribute_name(row, line, config)

      {identity_warnings ++ warnings, config_issues ++ identity_issues ++ issues}
    end)
    |> then(fn {warnings, issues} ->
      {warnings |> Enum.reverse() |> Enum.uniq(),
       issues |> Enum.reverse() |> Enum.uniq_by(&Map.delete(&1, :source))}
    end)
  end

  defp validate_identity(row, line, mapping_by_name) do
    mapping = Map.get(mapping_by_name, Mapping.canonical_name(row.baumart_bo))

    cond do
      not Wikidata.valid_id?(row.wikidata_id) ->
        {[],
         [
           %{
             code: :invalid_qid,
             source: {:review, line},
             baumart_bo: row.baumart_bo,
             qid: row.wikidata_id
           }
         ]}

      is_nil(mapping) ->
        {[%{code: :missing_mapping, baumart_bo: row.baumart_bo}], []}

      mapping.wikidata_id != row.wikidata_id ->
        {[],
         [
           %{
             code: :mapping_review_qid_mismatch,
             source: {:review, line},
             baumart_bo: row.baumart_bo,
             mapping_qid: mapping.wikidata_id,
             review_qid: row.wikidata_id
           }
         ]}

      mapping.baumart_de != row.baumart_de ->
        {[
           %{
             code: :mapping_review_name_mismatch,
             baumart_bo: row.baumart_bo,
             mapping_name: mapping.baumart_de,
             review_name: row.baumart_de
           }
         ], []}

      true ->
        {[], []}
    end
  end

  defp validate_attribute_name(row, line, config) do
    if PropertyConfig.importable?(config, row.property_id) do
      case PropertyConfig.attribute_name(config, row.property_id) do
        expected when is_binary(expected) and expected != row.attribute_name ->
          [
            %{
              code: :config_review_attribute_mismatch,
              source: {:review, line},
              property_id: row.property_id,
              config_attribute_name: expected,
              review_attribute_name: row.attribute_name
            }
          ]

        _ ->
          []
      end
    else
      []
    end
  end

  defp attribute_defs(config, review_rows) do
    review_rows
    |> Enum.map(& &1.property_id)
    |> Enum.uniq()
    |> Enum.flat_map(fn property_id ->
      with true <- PropertyConfig.importable?(config, property_id),
           name when is_binary(name) <- PropertyConfig.attribute_name(config, property_id),
           entry <- Map.fetch!(config.entries, property_id) do
        [
          %{
            property_id: property_id,
            attribute_name: name,
            entry: entry,
            type: TypeMapper.map(entry.type, property_id)
          }
        ]
      else
        _ -> []
      end
    end)
  end

  defp attribute_key_issues(attribute_defs) do
    attribute_defs
    |> Enum.group_by(& &1.attribute_name, & &1.property_id)
    |> Enum.flat_map(fn
      {_name, [_property_id]} ->
        []

      {name, property_ids} ->
        [
          %{
            code: :duplicate_attribute_key,
            attribute_name: name,
            property_ids: property_ids
          }
        ]
    end)
    |> Enum.sort_by(& &1.attribute_name)
  end

  defp datatype_warnings(attribute_defs) do
    for %{property_id: property_id, entry: entry} <- attribute_defs,
        not TypeMapper.known?(entry.type) do
      %{code: :unknown_datatype, property_id: property_id, datatype: entry.type}
    end
  end

  defp build_plan(config, targets, indexed_rows, attribute_defs, warnings) do
    target_names = MapSet.new(targets, &Mapping.canonical_name(&1.baumart_bo))
    attributes_by_property = Map.new(attribute_defs, &{&1.property_id, &1})

    {value_rows, skips} =
      classify_values(indexed_rows, config, target_names, attributes_by_property)

    summary = %{
      tree_types: length(targets),
      attributes: length(attribute_defs),
      values: length(value_rows),
      skipped_values: length(skips)
    }

    %__MODULE__{
      targets: targets,
      attribute_defs: attribute_defs,
      value_rows: value_rows,
      skips: skips,
      warnings: Enum.uniq(warnings),
      summary: summary
    }
  end

  # The review CSV is a versioned file and may be older than the mapping. A row
  # for a species that left the mapping has no tree type, so it must be skipped.
  defp classify_values(indexed_rows, config, target_names, attributes_by_property) do
    indexed_rows
    |> Enum.reduce({[], [], MapSet.new()}, fn {row, line}, {values, skips, seen} ->
      attribute = Map.get(attributes_by_property, row.property_id)
      name_key = Mapping.canonical_name(row.baumart_bo)

      reason =
        cond do
          not MapSet.member?(target_names, name_key) -> :missing_mapping
          not PropertyConfig.importable?(config, row.property_id) -> :property_not_importable
          is_nil(attribute) -> :missing_attribute_name
          MapSet.member?(seen, value_key(row, attribute)) -> :duplicate_value
          true -> nil
        end

      if reason do
        {values, [skip(row, line, reason) | skips], seen}
      else
        {[row | values], skips, MapSet.put(seen, value_key(row, attribute))}
      end
    end)
    |> then(fn {values, skips, _seen} -> {Enum.reverse(values), Enum.reverse(skips)} end)
  end

  # Mirrors the database identity (tree_type, attribute, value, unit). The
  # botanical name is canonicalized so deduplication cannot slip past a mere
  # spelling difference; `unit` is a placeholder until the export carries it.
  defp value_key(row, attribute) do
    {Mapping.canonical_name(row.baumart_bo), attribute.attribute_name, row.value, nil}
  end

  defp skip(row, line, reason) do
    %{
      reason: reason,
      line: line,
      baumart_bo: row.baumart_bo,
      property_id: row.property_id
    }
  end
end
