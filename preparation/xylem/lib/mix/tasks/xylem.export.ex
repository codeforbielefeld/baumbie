defmodule Mix.Tasks.Xylem.Export do
  @shortdoc "Exports processed Wikidata data to a flat review CSV"

  @moduledoc """
  Exports processed Wikidata RDF data to a flat CSV for manual review
  before Supabase import.

      $ mix xylem.export [options]

  ## Options

  - `--csv` - path to input species CSV (default: `priv/data/citree_wikidata_mapping.csv`)
  - `--config` - path to property config CSV (default: `priv/config/wikidata_properties.csv`)
  - `--processed` - directory of processed .ttl files (default: `priv/data/wikidata/processed`)
  - `--output` - output CSV path (default: `priv/data/wikidata/export.csv`)
  - `--limit` - limit number of species to export

  ## Examples

      # Export all species
      mix xylem.export

      # Export first 10 species
      mix xylem.export --limit 10

      # Custom output path
      mix xylem.export --output review.csv

  """

  use Mix.Task

  @switches [
    csv: :string,
    config: :string,
    processed: :string,
    output: :string,
    limit: :integer
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _} = OptionParser.parse!(args, strict: @switches)

    Application.ensure_all_started(:xylem)

    exporter_opts =
      []
      |> maybe_put(:csv_path, opts[:csv])
      |> maybe_put(:property_config_path, opts[:config])
      |> maybe_put(:processed_dir, opts[:processed])
      |> maybe_put(:output_path, opts[:output])
      |> maybe_put(:limit, opts[:limit])

    case Xylem.Export.CSVExporter.run(exporter_opts) do
      {:ok, result} ->
        Mix.shell().info(
          "Exported #{result.row_count} rows for #{result.species_count} species to #{result.output}"
        )

      {:error, reason} ->
        Mix.shell().error("Export failed: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
