defmodule Xylem.Wikidata.VocabGenerator do
  @moduledoc """
  Generates a vocabulary Turtle file with full descriptions for all properties
  used in the processed graphs.

  Fetches complete German and English descriptions of Wikidata property entities
  (`wd:P*`) via SPARQL CONSTRUCT. For BaumBie properties introduced by inlining,
  descriptions are derived from the property configuration.

  ## Options

  - `:meta_dir` - output directory for vocab.ttl (default: `priv/data/wikidata/meta`)
  - `:property_config` - a loaded `PropertyConfig` struct (for baumbie: labels and inline IRI collection)
  - `:property_config_path` - path to the property config CSV (fallback)
  - `:descriptions` - pre-fetched RDF graph of property descriptions (optional, skips SPARQL)
  - `:batch_size` - number of IRIs per SPARQL query (default: 50)
  """

  require Logger

  alias Xylem.Wikidata
  alias Xylem.Wikidata.PropertyConfig

  alias RDF.NS.RDFS

  @default_meta_dir "priv/data/wikidata/meta"
  @wikidata_sparql_endpoint "https://query.wikidata.org/sparql"
  @rdfs_label RDFS.label()
  @default_batch_size 50
  @max_retries 3
  @kept_languages MapSet.new(["de", "en"])

  @spec run([map()], keyword()) :: {:ok, Path.t()} | {:error, term()}
  def run(species_results, opts \\ []) do
    meta_dir = Keyword.get(opts, :meta_dir, @default_meta_dir)

    with {:ok, config} <- load_config(opts) do
      wd_iris = collect_property_iris(species_results, config)

      with {:ok, descriptions} <- fetch_descriptions(wd_iris, opts) do
        vocab_graph =
          descriptions
          |> add_baumbie_descriptions(species_results, config)
          |> filter_languages()

        File.mkdir_p!(meta_dir)
        path = Path.join(meta_dir, "vocab.ttl")
        content = RDF.Turtle.write_string!(vocab_graph)
        File.write!(path, content)

        Logger.info(
          "Generated vocabulary file: #{path} (#{RDF.Graph.triple_count(vocab_graph)} triples)"
        )

        {:ok, path}
      end
    end
  end

  defp load_config(opts) do
    case Keyword.get(opts, :property_config) do
      %PropertyConfig{} = config ->
        {:ok, config}

      nil ->
        config_path = Keyword.get(opts, :property_config_path)

        if config_path do
          PropertyConfig.load(path: config_path)
        else
          {:ok, %PropertyConfig{}}
        end
    end
  end

  # Collect all wd:P* entity IRIs that need descriptions
  defp collect_property_iris(species_results, config) do
    graph_iris = collect_from_processed_graphs(species_results)
    inline_iris = collect_from_inline_configs(config)
    source_iris = collect_from_inline_sources(config)

    (graph_iris ++ inline_iris ++ source_iris)
    |> Enum.uniq()
  end

  # wdt:* predicates from processed graphs → wd:* entity IRIs
  defp collect_from_processed_graphs(species_results) do
    species_results
    |> Enum.flat_map(fn result ->
      result.processed_path
      |> RDF.Turtle.read_file!()
      |> RDF.Graph.triples()
      |> Enum.map(fn {_s, p, _o} -> to_string(p) end)
      |> Enum.filter(&String.starts_with?(&1, Wikidata.wdt_prefix()))
      |> Enum.map(&Wikidata.wdt_to_wd/1)
    end)
  end

  # wd:* IRIs for all inline-configured properties (even if removed from processed graph)
  defp collect_from_inline_configs(config) do
    config
    |> PropertyConfig.all_property_ids()
    |> Enum.filter(&(PropertyConfig.inline_config(config, &1) != nil))
    |> Enum.map(&"#{Wikidata.wd_prefix()}#{&1}")
  end

  # Source properties from inline configs (only Wikidata properties)
  defp collect_from_inline_sources(config) do
    config
    |> PropertyConfig.all_property_ids()
    |> Enum.flat_map(fn property_id ->
      case PropertyConfig.inline_config(config, property_id) do
        %{source: source} ->
          cond do
            String.starts_with?(source, Wikidata.wdt_prefix()) ->
              [Wikidata.wdt_to_wd(source)]

            String.match?(source, ~r/^P\d+$/) ->
              ["#{Wikidata.wd_prefix()}#{source}"]

            true ->
              []
          end

        _ ->
          []
      end
    end)
  end

  defp fetch_descriptions(iris, opts) do
    case Keyword.get(opts, :descriptions) do
      %RDF.Graph{} = graph ->
        {:ok, graph}

      nil ->
        if iris == [] do
          {:ok, RDF.Graph.new()}
        else
          Logger.info("Fetching descriptions for #{length(iris)} properties...")
          fetch_via_sparql(iris, opts)
        end
    end
  end

  defp fetch_via_sparql(iris, opts) do
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)

    iris
    |> Enum.chunk_every(batch_size)
    |> Enum.reduce_while({:ok, RDF.Graph.new()}, fn batch, {:ok, acc} ->
      case fetch_batch(batch) do
        {:ok, graph} ->
          {:cont, {:ok, RDF.Graph.add(acc, graph)}}

        {:error, reason} ->
          Logger.warning(
            "SPARQL CONSTRUCT failed: #{inspect(reason)}, continuing with partial data"
          )

          {:cont, {:ok, acc}}
      end
    end)
  end

  defp fetch_batch(iris) do
    query = build_construct_query(iris)
    sparql_construct(query)
  end

  defp build_construct_query(iris) do
    values = iris |> Enum.map(&"<#{&1}>") |> Enum.join(" ")

    """
    CONSTRUCT {
      ?item ?p ?o .
    }
    WHERE {
      VALUES ?item { #{values} }
      ?item ?p ?o .
      FILTER(
        !isLiteral(?o) ||
        LANG(?o) = "" ||
        LANG(?o) IN ("de", "en")
      )
    }
    """
  end

  defp sparql_construct(query, retries \\ 0) do
    case SPARQL.Client.query(query, @wikidata_sparql_endpoint,
           request_method: :get,
           headers: %{"User-Agent" => "XylemBot/1.0 (BaumBie project; bielefeld@codefor.de)"}
         ) do
      {:ok, graph} ->
        {:ok, graph}

      {:error, %SPARQL.Client.HTTPError{status: status}} when status in [429, 503] ->
        if retries < @max_retries do
          delay = min(1000 * :math.pow(2, retries), 30_000) |> round()

          Logger.warning(
            "Wikidata rate limited (#{status}), retrying in #{delay}ms (attempt #{retries + 1}/#{@max_retries})..."
          )

          Process.sleep(delay)
          sparql_construct(query, retries + 1)
        else
          Logger.error("Wikidata rate limiting persists after #{@max_retries} retries")
          {:error, :rate_limit_exceeded}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Add rdfs:label descriptions for baumbie:* properties that appear in processed graphs
  defp add_baumbie_descriptions(graph, species_results, config) do
    used_baumbie_iris = collect_baumbie_predicates(species_results)

    baumbie_triples =
      config
      |> PropertyConfig.all_property_ids()
      |> Enum.flat_map(fn property_id ->
        case PropertyConfig.inline_config(config, property_id) do
          %{target: target} ->
            baumbie_iri = RDF.iri("#{Xylem.baumbie_prefix()}#{target}")

            if baumbie_iri in used_baumbie_iris do
              description = get_in(config.entries, [property_id, :description])

              label =
                if description && description != "", do: description, else: humanize(target)

              [{baumbie_iri, @rdfs_label, RDF.lang_string(label, "de")}]
            else
              []
            end

          _ ->
            []
        end
      end)

    RDF.Graph.add(graph, baumbie_triples)
  end

  defp collect_baumbie_predicates(species_results) do
    species_results
    |> Enum.flat_map(fn result ->
      result.processed_path
      |> RDF.Turtle.read_file!()
      |> RDF.Graph.triples()
      |> Enum.map(fn {_s, p, _o} -> p end)
      |> Enum.filter(&Xylem.baumbie_prefix?/1)
    end)
    |> Enum.uniq()
  end

  defp filter_languages(graph) do
    graph
    |> RDF.Graph.triples()
    |> Enum.filter(&keep_triple?/1)
    |> RDF.Graph.new()
  end

  defp keep_triple?({_s, _p, %RDF.Literal{literal: %RDF.LangString{language: lang}}}) do
    MapSet.member?(@kept_languages, lang)
  end

  defp keep_triple?(_triple), do: true

  defp humanize(target), do: String.replace(target, "_", " ")
end
