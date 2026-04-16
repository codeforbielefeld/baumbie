defmodule Mix.Tasks.Xylem.ReconcileCityTreeTypes do
  @shortdoc "Matches city tree types to Citree/Wikidata entries"

  @moduledoc """
  Reconciles the botanical names from the city tree registry with
  Citree/Wikidata data to assign Wikidata IDs.

      $ mix xylem.reconcile_city_tree_types [options]

  ## Options

  - `--city` - path to city tree type CSV (default: `priv/data/city_tree_type_matching/mapping.csv`)
  - `--citree` - path to Citree/Wikidata CSV (default: `priv/data/citree_wikidata_mapping.csv`)
  - `--synonyms` - path to synonym table CSV (default: `priv/data/city_tree_type_matching/synonyms.csv`)
  - `--manual` - path to manual Wikidata ID assignments CSV (default: `priv/data/city_tree_type_matching/manual_wikidata_ids.csv`)
  - `--output` - output path (default: overwrites `--city`)
  - `--dry-run` - show results without writing

  ## Examples

      # Run with defaults
      mix xylem.reconcile_city_tree_types

      # Dry run to preview results
      mix xylem.reconcile_city_tree_types --dry-run

      # Custom paths
      mix xylem.reconcile_city_tree_types --city path/to/input.csv --output path/to/output.csv

  """

  use Mix.Task

  alias Xylem.Import.CSVReader
  alias Xylem.Reconciliation.CityTreeTypeMatcher

  NimbleCSV.define(__MODULE__.CSVParser, separator: ",", escape: "\"")

  alias __MODULE__.CSVParser

  @default_city_path "priv/data/city_tree_type_matching/mapping.csv"
  @default_citree_path "priv/data/citree_wikidata_mapping.csv"
  @default_synonyms_path "priv/data/city_tree_type_matching/synonyms.csv"
  @default_manual_path "priv/data/city_tree_type_matching/manual_wikidata_ids.csv"

  @switches [
    city: :string,
    citree: :string,
    synonyms: :string,
    manual: :string,
    output: :string,
    dry_run: :boolean
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _} = OptionParser.parse!(args, strict: @switches)

    city_path = opts[:city] || @default_city_path
    citree_path = opts[:citree] || @default_citree_path
    synonyms_path = opts[:synonyms] || @default_synonyms_path
    manual_path = opts[:manual] || @default_manual_path
    output_path = opts[:output] || city_path
    dry_run? = opts[:dry_run] || false

    with {:ok, city_entries} <- read_city_csv(city_path),
         {:ok, citree_entries} <- CSVReader.run(citree_path),
         {:ok, synonyms} <- read_synonyms(synonyms_path),
         {:ok, manual_ids} <- read_manual_ids(manual_path) do
      result =
        CityTreeTypeMatcher.run(city_entries, citree_entries,
          synonyms: synonyms,
          manual_ids: manual_ids
        )

      print_report(result)

      unless dry_run? do
        write_output(output_path, city_entries, result.matches)
        Mix.shell().info("\nWrote #{output_path}")
      end
    else
      {:error, reason} ->
        Mix.shell().error("Failed: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  defp read_city_csv(path) do
    with {:ok, content} <- File.read(path) do
      rows =
        content
        |> CSVParser.parse_string(skip_headers: true)
        |> Enum.map(fn
          [name, wikidata_id, citree_name | _] ->
            %{
              tree_type_botanic: String.trim(name),
              wikidata_id: String.trim(wikidata_id),
              citree_name: String.trim(citree_name)
            }

          [name, wikidata_id] ->
            %{
              tree_type_botanic: String.trim(name),
              wikidata_id: String.trim(wikidata_id),
              citree_name: ""
            }

          [name] ->
            %{tree_type_botanic: String.trim(name), wikidata_id: "", citree_name: ""}
        end)

      {:ok, rows}
    end
  end

  defp read_synonyms(path) do
    read_optional_csv(path, "synonym file", fn [city_name, citree_name | _] ->
      %{city_name: String.trim(city_name), citree_name: String.trim(citree_name)}
    end)
  end

  defp read_manual_ids(path) do
    read_optional_csv(path, "manual IDs file", fn [name, wikidata_id | _] ->
      %{tree_type_botanic: String.trim(name), wikidata_id: String.trim(wikidata_id)}
    end)
  end

  defp read_optional_csv(path, description, row_mapper) do
    case File.read(path) do
      {:ok, content} ->
        rows = content |> CSVParser.parse_string(skip_headers: true) |> Enum.map(row_mapper)
        {:ok, rows}

      {:error, :enoent} ->
        Mix.shell().info("No #{description} found at #{path}, proceeding without")
        {:ok, []}
    end
  end

  defp print_report(%{matches: matches, unmatched: unmatched}) do
    level_counts =
      matches
      |> Enum.frequencies_by(& &1.level)
      |> Enum.sort_by(fn {level, _} -> level_order(level) end)

    total_matched = length(matches)
    total_unmatched = Enum.count(unmatched, &(&1.reason == :no_match))
    non_trees = Enum.count(unmatched, &(&1.reason == :non_tree))

    Mix.shell().info("=== Reconciliation Report ===\n")
    Mix.shell().info("Matched: #{total_matched}")

    for {level, count} <- level_counts do
      Mix.shell().info("  #{format_level(level)}: #{count}")
    end

    Mix.shell().info("Unmatched: #{total_unmatched}")
    Mix.shell().info("Non-tree entries: #{non_trees}")

    if total_unmatched > 0 do
      Mix.shell().info("\n--- Unmatched entries ---")

      unmatched
      |> Enum.filter(&(&1.reason == :no_match))
      |> Enum.each(fn entry -> Mix.shell().info("  #{entry.city_name}") end)
    end
  end

  defp level_order(:existing), do: 0
  defp level_order(:exact), do: 1
  defp level_order(:normalized), do: 2
  defp level_order(:hybrid_agnostic), do: 3
  defp level_order(:cultivar_to_species), do: 4
  defp level_order(:species_to_genus), do: 5
  defp level_order(:synonym), do: 6
  defp level_order(:manual), do: 7

  defp format_level(:existing), do: "Existing"
  defp format_level(level), do: "L#{level_order(level)} - #{level}"

  defp write_output(path, city_entries, matches) do
    match_map = Map.new(matches, &{&1.city_name, &1})

    lines =
      Enum.map(city_entries, fn entry ->
        match = match_map[entry.tree_type_botanic]
        wikidata_id = (match && match.wikidata_id) || entry.wikidata_id || ""

        citree_name =
          cond do
            entry.citree_name != "" -> entry.citree_name
            match && match.citree_name -> match.citree_name
            true -> ""
          end

        "#{escape_csv(entry.tree_type_botanic)},#{wikidata_id},#{escape_csv(citree_name)}"
      end)

    content =
      ["tree_type_botanic,wikidata_id,citree_name" | lines] |> Enum.join("\n") |> Kernel.<>("\n")

    File.write!(path, content)
  end

  defp escape_csv(value) do
    if String.contains?(value, [",", "\"", "\n"]) do
      "\"#{String.replace(value, "\"", "\"\"")}\""
    else
      value
    end
  end
end
