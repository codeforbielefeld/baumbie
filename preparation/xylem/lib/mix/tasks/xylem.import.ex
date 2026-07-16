defmodule Mix.Tasks.Xylem.Import do
  @shortdoc "Imports the Wikidata review CSV into the BaumBie attribute model"

  @moduledoc """
  Imports the reviewed Wikidata data into Supabase.

      $ mix xylem.import [options]

  Derives `tree_types` from the tree cadastre, sets `wikidata_id` via
  botanical-name matching, and writes provider/attributes/values.

  ## Options

  - `--input` - review CSV path (default: `priv/data/wikidata/export.csv`)
  - `--config` - property config CSV path (default: `priv/config/wikidata_properties.csv`)
  - `--mapping` - Wikidata mapping CSV path (default: `priv/data/baumbie_wikidata_mapping.csv`)
  - `--trees` - cadastre GeoJSON path (default: `../trees2.geojson`)
  - `--dry-run` - report what would be imported without any write access

  ## Examples

      # Full import
      mix xylem.import

      # Preview without writing
      mix xylem.import --dry-run

  """

  use Mix.Task

  @requirements ["app.config"]

  @switches [
    input: :string,
    config: :string,
    mapping: :string,
    trees: :string,
    dry_run: :boolean
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _} = OptionParser.parse!(args, strict: @switches)

    unless opts[:dry_run], do: Mix.Task.run("app.start")

    importer_opts =
      []
      |> maybe_put(:input, opts[:input])
      |> maybe_put(:config, opts[:config])
      |> maybe_put(:mapping, opts[:mapping])
      |> maybe_put(:trees, opts[:trees])
      |> maybe_put(:dry_run, opts[:dry_run])

    case Xylem.BaumBie.Importer.run(importer_opts) do
      {:ok, summary} ->
        Mix.shell().info(format_summary(summary))

      {:error, reason} ->
        Mix.shell().error("Import failed: #{format_error(reason)}")
        exit({:shutdown, 1})
    end
  end

  defp format_summary(summary) do
    prefix = if summary.dry_run, do: "[dry-run] ", else: ""

    """
    #{prefix}Import summary:
      tree_types derived:    #{summary.tree_types_derived}
      matched (wikidata_id): #{summary.matched}
      unmatched cadastre:    #{summary.unmatched_cadastre}
      unmatched mapping:     #{summary.unmatched_mapping}
      attributes:            #{summary.attributes}
      values written:        #{summary.values}
      values skipped:        #{summary.skipped_values}
      warnings:              #{summary.warnings}\
    """
  end

  defp format_error(%{__exception__: true} = error), do: Exception.message(error)
  defp format_error(error), do: inspect(error)

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
