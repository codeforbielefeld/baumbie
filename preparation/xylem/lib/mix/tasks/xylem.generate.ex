defmodule Mix.Tasks.Xylem.Generate do
  @shortdoc "Runs the Xylem data pipeline for Wikidata tree species"

  @moduledoc """
  Runs the Xylem pipeline to fetch, process, and describe Wikidata tree species data.

      $ mix xylem.generate [options]

  ## Options

  - `--csv` - path to input CSV file (default: `priv/data/baumbie_wikidata_mapping.csv`)
  - `--config` - path to property config CSV (default: `priv/config/wikidata_properties.csv`)
  - `--fetch` - Wikidata fetch mode: `auto` (default), `skip`, `force`, or `clear`.
    `auto` loads already cached entities and fetches only the missing ones.
  - `--raw` - directory for raw .ttl files (default: `priv/data/wikidata/raw`)
  - `--processed` - directory for processed .ttl files (default: `priv/data/wikidata/processed`)
  - `--meta` - directory for vocab.ttl (default: `priv/data/wikidata/meta`)
  - `--limit` - limit number of Wikidata entities to process. Counts distinct
    entities, not mapping rows — several tree types may share one entity.

  ## Examples

      # Process all entities
      mix xylem.generate

      # Process the first 10 entities, without fetching
      mix xylem.generate --limit 10 --fetch skip

      # Re-fetch everything from scratch, dropping obsolete raw files
      mix xylem.generate --fetch clear

      # Use custom paths
      mix xylem.generate --csv my_species.csv --processed output/processed

  """

  use Mix.Task

  @requirements ["app.config"]

  @valid_fetch_modes Enum.map(Xylem.Wikidata.Fetcher.fetch_modes(), &to_string/1)

  @switches [
    csv: :string,
    config: :string,
    fetch: :string,
    raw: :string,
    processed: :string,
    meta: :string,
    limit: :integer
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _} = OptionParser.parse!(args, strict: @switches)

    Mix.Task.run("app.start")

    xylem_opts =
      []
      |> maybe_put(:csv_path, opts[:csv])
      |> maybe_put(:property_config_path, opts[:config])
      |> maybe_put_fetch_mode(opts[:fetch])
      |> maybe_put(:raw_dir, opts[:raw])
      |> maybe_put(:processed_dir, opts[:processed])
      |> maybe_put(:meta_dir, opts[:meta])
      |> maybe_put(:limit, opts[:limit])

    case Xylem.run(xylem_opts) do
      {:ok, result} ->
        Mix.shell().info("Processed #{length(result.successful)} entities")

        if length(result.failed_fetches) > 0 do
          Mix.shell().info("Failed fetches: #{length(result.failed_fetches)}")
        end

        report_appended_properties(result)

      {:error, reason} ->
        Mix.shell().error("Pipeline failed: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  # Auto-appended properties carry defaults derived from their Wikidata type,
  # which must be reviewed before the next export.
  defp report_appended_properties(%{appended_properties: []}), do: :ok

  defp report_appended_properties(result) do
    Mix.shell().info(
      "#{length(result.appended_properties)} new properties appended to " <>
        "#{result.property_config_path}, please review: " <>
        Enum.join(result.appended_properties, ", ")
    )
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp maybe_put_fetch_mode(opts, nil), do: opts

  defp maybe_put_fetch_mode(opts, mode) when mode in @valid_fetch_modes do
    Keyword.put(opts, :fetch, String.to_atom(mode))
  end

  defp maybe_put_fetch_mode(_opts, invalid) do
    Mix.raise(
      "Invalid --fetch value: #{inspect(invalid)}. Must be one of: #{Enum.join(@valid_fetch_modes, ", ")}"
    )
  end
end
