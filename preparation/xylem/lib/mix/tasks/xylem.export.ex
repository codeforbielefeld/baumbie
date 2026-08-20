defmodule Mix.Tasks.Xylem.Export do
  @shortdoc "Exports processed Wikidata data to a flat review CSV"

  @moduledoc """
  Exports processed Wikidata RDF data to a flat CSV for manual review
  before Supabase import.

      $ mix xylem.export [options]

  One row is written per property value per target, where a target is a
  validated `(baumart_bo, wikidata_id)` pair. The mapping is validated before
  the output file is opened, and the result replaces the previous export only
  once the run has completed — a failure leaves a reviewed CSV untouched.

  ## Options

  - `--csv` - path to input species CSV (default: `priv/data/baumbie_wikidata_mapping.csv`)
  - `--config` - path to property config CSV (default: `priv/config/wikidata_properties.csv`)
  - `--processed` - directory of processed .ttl files (default: `priv/cache/wikidata/processed`)
  - `--output` - output CSV path (default: `priv/data/wikidata/export.csv`)
  - `--limit` - limit number of targets to export

  ## Examples

      # Export all targets
      mix xylem.export

      # Export the first 10 targets
      mix xylem.export --limit 10

      # Custom output path
      mix xylem.export --output review.csv

  """

  use Mix.Task

  @requirements ["app.config"]

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

    Mix.Task.run("app.start")

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
          "Exported #{result.row_count} rows for #{result.species_count} targets to #{result.output}"
        )

        if result.missing_processed > 0 do
          Mix.shell().info("Entities without a processed file: #{result.missing_processed}")
        end

      {:error, reason} ->
        Mix.shell().error("Export failed: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
