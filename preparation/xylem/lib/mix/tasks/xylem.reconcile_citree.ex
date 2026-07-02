defmodule Mix.Tasks.Xylem.ReconcileCitree do
  @shortdoc "Matches Citree tree names against the BaumBie/Wikidata mapping"

  @moduledoc """
  Reconciles Citree botanical tree names with the BaumBie/Wikidata reference
  mapping to assign Wikidata IDs (and identify the matching `baumart_bo` from BaumBie).

      $ mix xylem.reconcile_citree [options]

  ## Options

  - `--citree` - path to Citree input CSV (default: `priv/data/citree_matching/mapping.csv`)
  - `--baumbie` - path to BaumBie/Wikidata mapping CSV (default: `priv/data/baumbie_wikidata_mapping.csv`)
  - `--synonyms` - path to synonym table CSV (default: `priv/data/citree_matching/synonyms.csv`)
  - `--manual` - path to manual Wikidata ID assignments CSV (default: `priv/data/citree_matching/manual_wikidata_ids.csv`)
  - `--output` - output path (default: overwrites `--citree`)
  - `--dry-run` - show results without writing

  ## Examples

      # Run with defaults
      mix xylem.reconcile_citree

      # Dry run to preview results
      mix xylem.reconcile_citree --dry-run

      # Custom paths
      mix xylem.reconcile_citree --citree path/to/input.csv --output path/to/output.csv

  """

  use Mix.Task

  alias Xylem.Import.CSVReader
  alias Xylem.Reconciliation.CitreeMatcher

  NimbleCSV.define(__MODULE__.CSVParser, separator: ",", escape: "\"")

  alias __MODULE__.CSVParser

  @default_citree_path "priv/data/citree_matching/mapping.csv"
  @default_baumbie_path "priv/data/baumbie_wikidata_mapping.csv"
  @default_synonyms_path "priv/data/citree_matching/synonyms.csv"
  @default_manual_path "priv/data/citree_matching/manual_wikidata_ids.csv"

  @switches [
    citree: :string,
    baumbie: :string,
    synonyms: :string,
    manual: :string,
    output: :string,
    dry_run: :boolean
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _} = OptionParser.parse!(args, strict: @switches)

    citree_path = opts[:citree] || @default_citree_path
    baumbie_path = opts[:baumbie] || @default_baumbie_path
    synonyms_path = opts[:synonyms] || @default_synonyms_path
    manual_path = opts[:manual] || @default_manual_path
    output_path = opts[:output] || citree_path
    dry_run? = opts[:dry_run] || false

    with {:ok, citree_entries} <- read_citree_csv(citree_path),
         {:ok, baumbie_entries} <- CSVReader.run(baumbie_path),
         {:ok, synonyms} <- read_synonyms(synonyms_path),
         {:ok, manual_ids} <- read_manual_ids(manual_path) do
      result =
        CitreeMatcher.run(citree_entries, baumbie_entries,
          synonyms: synonyms,
          manual_ids: manual_ids
        )

      print_report(result)

      unless dry_run? do
        write_output(output_path, citree_entries, result.matches)
        Mix.shell().info("\nWrote #{output_path}")
      end
    else
      {:error, reason} ->
        Mix.shell().error("Failed: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  defp read_citree_csv(path) do
    with {:ok, content} <- File.read(path) do
      rows =
        content
        |> CSVParser.parse_string(skip_headers: true)
        |> Enum.map(fn
          [name, strain, wikidata_id, baumart_bo | _] ->
            %{
              name_botanic: String.trim(name),
              strain: String.trim(strain),
              wikidata_id: String.trim(wikidata_id),
              baumart_bo: String.trim(baumart_bo)
            }

          [name, strain, wikidata_id] ->
            %{
              name_botanic: String.trim(name),
              strain: String.trim(strain),
              wikidata_id: String.trim(wikidata_id),
              baumart_bo: ""
            }

          [name, strain] ->
            %{
              name_botanic: String.trim(name),
              strain: String.trim(strain),
              wikidata_id: "",
              baumart_bo: ""
            }

          [name] ->
            %{name_botanic: String.trim(name), strain: "", wikidata_id: "", baumart_bo: ""}
        end)

      {:ok, rows}
    end
  end

  defp read_synonyms(path) do
    read_optional_csv(path, "synonym file", fn [name_botanic, baumart_bo | _] ->
      %{name_botanic: String.trim(name_botanic), baumart_bo: String.trim(baumart_bo)}
    end)
  end

  defp read_manual_ids(path) do
    read_optional_csv(path, "manual IDs file", fn [name, wikidata_id | _] ->
      %{name_botanic: String.trim(name), wikidata_id: String.trim(wikidata_id)}
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

    Mix.shell().info("=== Reconciliation Report ===\n")
    Mix.shell().info("Matched: #{length(matches)}")

    for {level, count} <- level_counts do
      Mix.shell().info("  #{format_level(level)}: #{count}")
    end

    Mix.shell().info("Unmatched: #{length(unmatched)}")

    if length(unmatched) > 0 do
      Mix.shell().info("\n--- Unmatched entries ---")

      Enum.each(unmatched, fn entry ->
        suffix = if entry.strain && entry.strain != "", do: " (#{entry.strain})", else: ""
        Mix.shell().info("  #{entry.name_botanic}#{suffix}")
      end)
    end
  end

  defp level_order(:existing), do: 0
  defp level_order(:exact), do: 1
  defp level_order(:author_stripped), do: 2
  defp level_order(:normalized), do: 3
  defp level_order(:hybrid_agnostic), do: 4
  defp level_order(:infraspecific_stripped), do: 5
  defp level_order(:synonym), do: 6
  defp level_order(:parenthetical_synonym), do: 7
  defp level_order(:manual), do: 8

  defp format_level(:existing), do: "Existing"
  defp format_level(level), do: "L#{level_order(level)} - #{level}"

  defp write_output(path, citree_entries, matches) do
    match_map =
      Map.new(matches, fn match ->
        {{match.name_botanic, match.strain || ""}, match}
      end)

    lines =
      Enum.map(citree_entries, fn entry ->
        key = {entry.name_botanic, entry.strain || ""}
        match = match_map[key]
        wikidata_id = (match && match.wikidata_id) || entry.wikidata_id || ""

        baumart_bo =
          cond do
            entry.baumart_bo != "" -> entry.baumart_bo
            match && match.baumart_bo -> match.baumart_bo
            true -> ""
          end

        "#{escape_csv(entry.name_botanic)},#{escape_csv(entry.strain)},#{wikidata_id},#{escape_csv(baumart_bo)}"
      end)

    content =
      ["name_botanic,strain,wikidata_id,baumart_bo" | lines]
      |> Enum.join("\n")
      |> Kernel.<>("\n")

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