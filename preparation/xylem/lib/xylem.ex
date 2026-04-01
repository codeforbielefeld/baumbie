defmodule Xylem do
  @moduledoc """
  Data pipeline for processing Wikidata tree species information.

  The pipeline consists of the following steps:

  1. **CSV Import**: Read tree species with Wikidata IDs from a CSV file
  2. **Wikidata Fetch**: Download entity data as Turtle RDF
  3. **Processing**: Filter to relevant `wdt:*` properties, inline configured properties
  4. **Vocabulary**: Generate property descriptions as vocab.ttl
  5. **Config Update**: Auto-append newly discovered properties to the config CSV

  ## Example

      Xylem.run()
      # or with options
      Xylem.run(csv_path: "path/to/species.csv", limit: 10)

  """

  require Logger

  alias Xylem.Import.CSVReader
  alias Xylem.Wikidata
  alias Xylem.Wikidata.{Processor, Fetcher, VocabGenerator, PropertyConfig}
  alias RDF.XSD
  alias RDF.NS.RDFS

  import RDF.Sigils

  @type result :: %{
          successful: [map()],
          failed_fetches: [map()],
          vocab_path: Path.t() | nil
        }

  @default_csv_path "data/Baumarten-wikidata.csv"
  @default_config_path "priv/config/wikidata_properties.csv"

  @baumbie_prefix "https://www.baumbie.org/xylem/vocab/"
  def baumbie_prefix, do: @baumbie_prefix
  def baumbie_prefix?(iri), do: String.starts_with?(to_string(iri), @baumbie_prefix)

  @doc """
  Runs the complete pipeline.

  ## Options

  - `:csv_path` - path to input CSV file (default: `data/Baumarten-wikidata.csv`)
  - `:property_config_path` - path to property config CSV (default: `priv/config/wikidata_properties.csv`)
  - `:fetch` - Wikidata fetch mode: `:auto` (default), `:skip`, `:force`, or `:clear`
  - `:raw_dir` - directory for raw .ttl files (default: `priv/data/wikidata/raw`)
  - `:processed_dir` - directory for processed .ttl files (default: `priv/data/wikidata/processed`)
  - `:meta_dir` - directory for vocab.ttl (default: `priv/data/wikidata/meta`)
  - `:limit` - limit number of species to process (default: all)
  - `:max_concurrent` - max concurrent HTTP fetches (default: 2)
  - `:delay_ms` - delay after each HTTP request in ms (default: 2000)
  - `:plug` - Req plug for testing (optional)
  """
  @spec run(keyword()) :: {:ok, result()} | {:error, term()}
  def run(opts \\ []) do
    csv_path = Keyword.get(opts, :csv_path, @default_csv_path)
    config_path = Keyword.get(opts, :property_config_path, @default_config_path)

    with {:ok, config} <- PropertyConfig.load(path: config_path),
         {:ok, species} <- read_csv(csv_path, opts),
         {:ok, fetch_result} <- fetch_entities(species, opts),
         {:ok, processed} <- process_entities(fetch_result.successful, config, opts),
         {:ok, vocab_path} <- generate_vocab(processed, config, opts),
         :ok <- auto_append_properties(config, config_path, processed, vocab_path) do
      result = %{
        successful: processed,
        failed_fetches: fetch_result.failed,
        vocab_path: vocab_path
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
    Fetcher.run(species, opts)
  end

  defp process_entities(species_with_graphs, config, opts) do
    Logger.info("Processing #{length(species_with_graphs)} entities...")
    Processor.run(species_with_graphs, Keyword.put(opts, :property_config, config))
  end

  defp generate_vocab(processed, config, opts) do
    Logger.info("Generating vocabulary...")
    VocabGenerator.run(processed, Keyword.put(opts, :property_config, config))
  end

  defp auto_append_properties(config, config_path, processed, vocab_path) do
    property_ids = collect_property_ids(processed)
    metadata = extract_vocab_metadata(vocab_path)
    PropertyConfig.append_unknown(config, config_path, property_ids, metadata: metadata)
  end

  defp collect_property_ids(processed) do
    processed
    |> Enum.flat_map(fn result ->
      result.processed_path
      |> RDF.Turtle.read_file!()
      |> RDF.Graph.triples()
      |> Enum.map(fn {_s, p, _o} -> to_string(p) end)
      |> Enum.filter(&String.starts_with?(&1, Wikidata.wdt_prefix()))
      |> Enum.map(&Wikidata.property_id/1)
    end)
    |> Enum.uniq()
  end

  @wikibase_property_type ~I<http://wikiba.se/ontology#propertyType>
  @schema_description ~I<http://schema.org/description>
  @wikibase_ontology_prefix "http://wikiba.se/ontology#"

  defp extract_vocab_metadata(vocab_path) do
    case RDF.Turtle.read_file(vocab_path) do
      {:ok, graph} ->
        graph
        |> RDF.Graph.descriptions()
        |> Enum.flat_map(fn description ->
          subject_str = description |> RDF.Description.subject() |> to_string()

          if String.starts_with?(subject_str, Wikidata.wd_prefix()) do
            property_id = Wikidata.entity_id(subject_str)
            label = find_label(description, RDFS.label())
            schema_desc = find_description(description)
            type = extract_property_type(description)

            description_text = build_description(label, schema_desc)

            [{property_id, %{type: type, label: label, description: description_text}}]
          else
            []
          end
        end)
        |> Map.new()

      _ ->
        Logger.warning("Failed to read vocabulary file #{vocab_path}")
        %{}
    end
  end

  defp find_description(description) do
    if values = RDF.Description.get(description, @schema_description) do
      find_by_language(values, "de") || find_by_language(values, "en")
    end
  end

  defp extract_property_type(description) do
    case RDF.Description.get(description, @wikibase_property_type) do
      [%RDF.IRI{} = iri | _] ->
        iri |> to_string() |> String.replace_prefix(@wikibase_ontology_prefix, "")

      _ ->
        ""
    end
  end

  defp build_description(nil, nil), do: ""
  defp build_description(label, nil), do: label
  defp build_description(nil, desc), do: desc
  defp build_description(label, desc), do: "#{label} – #{desc}"

  defp find_label(description, rdfs_label) do
    if labels = RDF.Description.get(description, rdfs_label) do
      find_by_language(labels, "de") ||
        find_plain_string(labels) ||
        find_by_language(labels, "en")
    end
  end

  defp find_by_language(labels, lang) do
    Enum.find_value(labels, fn
      %RDF.Literal{literal: %RDF.LangString{language: ^lang, value: value}} -> value
      _ -> nil
    end)
  end

  defp find_plain_string(labels) do
    Enum.find_value(labels, fn
      %RDF.Literal{literal: %XSD.String{value: value}} -> value
      _ -> nil
    end)
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
