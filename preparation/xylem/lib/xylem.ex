defmodule Xylem do
  @moduledoc """
  Data pipeline for fetching Wikidata tree species information.

  The pipeline consists of the following steps:

  1. **CSV Import**: Read tree species with Wikidata IDs from a CSV file
  2. **Wikidata Fetch**: Download entity data as Turtle RDF

  ## Example

      Xylem.run()
      # or with options
      Xylem.run(csv_path: "path/to/species.csv", limit: 10)

  """

  require Logger

  alias Xylem.Import.CSVReader
  alias Xylem.Fetch.Wikidata, as: WikidataFetch

  @default_csv_path "data/Baumarten-wikidata.csv"

  @type result :: %{
          successful: [Path.t()],
          failed_fetches: [map()],
          failed_profiles: [map()]
        }

  @doc """
  Runs the complete pipeline.

  ## Options

  - `:csv_path` - path to input CSV file (default: `data/Baumarten-wikidata.csv`)
  - `:raw_dir` - directory for raw .ttl files (default: `priv/data/wikidata/raw`)
  - `:limit` - limit number of species to process (default: all)
  - `:max_concurrent` - max parallel HTTP fetches (default: 3)
  - `:delay_ms` - delay between HTTP requests in ms (default: 500)
  - `:plug` - Req plug for testing (optional)
  """
  @spec run(keyword()) :: {:ok, result()} | {:error, term()}
  def run(opts \\ []) do
    csv_path = Keyword.get(opts, :csv_path, @default_csv_path)

    with {:ok, species} <- read_csv(csv_path, opts),
         {:ok, fetch_result} <- fetch_entities(species, opts) do
      result = %{
        successful: fetch_result.successful,
        failed_fetches: fetch_result.failed
      }

      log_summary(result, length(species))
      {:ok, result}
    end
  end

  defp read_csv(path, opts) do
    Logger.info("Reading CSV from #{path}")

    with {:ok, species} <- CSVReader.run(path) do
      species =
        if limit = Keyword.get(opts, :limit) do
          Enum.take(species, limit)
        else
          species
        end

      Logger.info("Found #{length(species)} species")
      {:ok, species}
    end
  end

  defp fetch_entities(species, opts) do
    Logger.info("Fetching #{length(species)} Wikidata entities...")
    WikidataFetch.run(species, opts)
  end

  defp log_summary(result, total) do
    successful = length(result.successful)
    failed_fetch = length(result.failed_fetches)

    Logger.info("""
    Pipeline complete:
      Total species: #{total}
      Successful: #{successful}
      Failed fetches: #{failed_fetch}
    """)

    if failed_fetch > 0 do
      Logger.warning(
        "Failed fetches: #{inspect(Enum.map(result.failed_fetches, & &1.wikidata_id))}"
      )
    end
  end
end
