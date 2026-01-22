defmodule Mix.Tasks.Xylem.Generate do
  @shortdoc "Fetches species from Wikidata"

  @moduledoc """
  Runs the Xylem pipeline to fetch Wikidata data.

      $ mix xylem.generate [options]

  ## Options

  - `--csv` - path to input CSV file (default: `data/Baumarten-wikidata.csv`)
  - `--raw` - directory for raw .ttl files (default: `priv/data/wikidata/raw`)
  - `--limit` - limit number of species to process

  ## Examples

      # Process all species
      mix xylem.generate

      # Process first 10 species
      mix xylem.generate --limit 10

      # Use custom paths
      mix xylem.generate --csv my_species.csv

  """

  use Mix.Task

  @switches [
    csv: :string,
    raw: :string,
    limit: :integer
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _} = OptionParser.parse!(args, strict: @switches)

    Application.ensure_all_started(:xylem)

    xylem_opts =
      []
      |> maybe_put(:csv_path, opts[:csv])
      |> maybe_put(:raw_dir, opts[:raw])
      |> maybe_put(:limit, opts[:limit])

    case Xylem.run(xylem_opts) do
      {:ok, result} ->
        Mix.shell().info("Processed #{length(result.successful)} species")

        if length(result.failed_fetches) > 0 do
          Mix.shell().info("Failed fetches: #{length(result.failed_fetches)}")
        end

      {:error, reason} ->
        Mix.shell().error("Pipeline failed: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
