defmodule Xylem.Wikidata.Processor do
  @moduledoc """
  Filters and processes raw Wikidata RDF graphs for tree species.

  Produces cleaned Turtle files containing only relevant direct properties (`wdt:*`)
  and `rdfs:label` values in German and English.
  """

  require Logger

  alias Xylem.Wikidata
  alias Xylem.Wikidata.PropertyConfig

  alias RDF.NS.RDFS

  @default_processed_dir "priv/data/wikidata/processed"
  def default_processed_dir, do: @default_processed_dir

  @kept_languages MapSet.new(["de", "en"])

  @type species_with_graph :: %{
          baumart_bo: String.t(),
          baumart_de: String.t(),
          wikidata_id: String.t(),
          graph: RDF.Graph.t(),
          raw_path: Path.t()
        }

  @type species_processed :: %{
          baumart_bo: String.t(),
          baumart_de: String.t(),
          wikidata_id: String.t(),
          processed_path: Path.t()
        }

  @doc """
  Processes raw RDF graphs into filtered Turtle files.

  ## Options

  - `:property_config` - a loaded `PropertyConfig` struct (takes precedence)
  - `:property_config_path` - path to the property config CSV (default: `#{PropertyConfig.default_path()}`)
  - `:processed_dir` - output directory for processed .ttl files (default: `#{@default_processed_dir}`)
  """
  @spec run([species_with_graph()], keyword()) ::
          {:ok, [species_processed()]}
          | {:error, term()}
  def run(species_list, opts \\ []) do
    processed_dir = Keyword.get(opts, :processed_dir, @default_processed_dir)

    with {:ok, config} <- load_config(opts) do
      File.mkdir_p!(processed_dir)

      {:ok, Enum.map(species_list, &process_species(&1, config, processed_dir))}
    end
  end

  defp load_config(opts) do
    case Keyword.get(opts, :property_config) do
      %PropertyConfig{} = config ->
        {:ok, config}

      nil ->
        config_path = Keyword.get(opts, :property_config_path, PropertyConfig.default_path())
        PropertyConfig.load(path: config_path)
    end
  end

  defp process_species(species, config, processed_dir) do
    subject = RDF.iri("#{Wikidata.wd_prefix()}#{species.wikidata_id}")
    path = Path.join(processed_dir, "#{species.wikidata_id}.ttl")

    species.graph
    |> filter_main_entity(subject, config)
    |> inline_properties(subject, config, species.graph)
    |> add_secondary_resources(species.graph)
    |> filter_languages()
    |> RDF.Turtle.write_file!(path, force: true)

    Logger.debug("Processed #{species.wikidata_id} -> #{path}")

    %{
      baumart_bo: species.baumart_bo,
      baumart_de: species.baumart_de,
      wikidata_id: species.wikidata_id,
      processed_path: path
    }
  end

  # Filter the main entity to only wdt:* properties (+ rdfs:label), applying blacklist
  defp filter_main_entity(graph, subject, config) do
    if description = RDF.Graph.get(graph, subject) do
      filtered_predicates =
        description
        |> RDF.Description.predicates()
        |> Enum.filter(fn predicate ->
          predicate == RDFS.label() or
            (wdt_property?(predicate) and not ignored?(predicate, config))
        end)

      filtered_triples =
        Enum.flat_map(filtered_predicates, fn predicate ->
          description
          |> RDF.Description.get(predicate)
          |> Enum.map(&{subject, predicate, &1})
        end)

      RDF.Graph.new(filtered_triples)
    else
      RDF.Graph.new()
    end
  end

  # Apply inlining: for inline-configured properties, add baumbie: triples
  # and optionally remove the original link triple.
  # Labels are resolved from the original raw graph.
  defp inline_properties(graph, subject, config, original_graph) do
    if description = RDF.Graph.get(graph, subject) do
      description
      |> RDF.Description.predicates()
      |> Enum.filter(&wdt_property?/1)
      |> Enum.reduce(graph, fn predicate, acc ->
        property_id = predicate |> to_string() |> Wikidata.property_id()

        if inline_cfg = PropertyConfig.inline_config(config, property_id) do
          apply_inline(acc, subject, predicate, inline_cfg, original_graph)
        else
          acc
        end
      end)
    else
      graph
    end
  end

  defp apply_inline(graph, subject, predicate, inline_cfg, original_graph) do
    baumbie_predicate = RDF.iri("#{Xylem.baumbie_prefix()}#{inline_cfg.target}")

    objects =
      graph
      |> RDF.Graph.get(subject)
      |> RDF.Description.get(predicate)

    Enum.reduce(objects, graph, fn object, acc ->
      if value = resolve_inline_value(object, original_graph) do
        acc
        |> RDF.Graph.add({subject, baumbie_predicate, value})
        |> maybe_remove_original(subject, predicate, object, inline_cfg)
      else
        acc
      end
    end)
  end

  # Resolve the inline value for an entity IRI by looking up its rdfs:label
  # in the original raw graph (preferring German, falling back to English)
  defp resolve_inline_value(%RDF.IRI{} = iri, original_graph) do
    if description = RDF.Graph.get(original_graph, iri) do
      if labels = RDF.Description.get(description, RDFS.label()) do
        find_preferred_label(labels)
      end
    end
  end

  defp resolve_inline_value(_object, _original_graph), do: nil

  defp find_preferred_label(labels) do
    Enum.find(labels, &match?(%RDF.Literal{literal: %RDF.LangString{language: "de"}}, &1)) ||
      Enum.find(labels, &match?(%RDF.Literal{literal: %RDF.LangString{language: "en"}}, &1))
  end

  defp maybe_remove_original(graph, _subject, _predicate, _object, %{keep_source: true}),
    do: graph

  defp maybe_remove_original(graph, subject, predicate, object, _inline_cfg) do
    RDF.Graph.delete(graph, {subject, predicate, object})
  end

  # Add descriptions of secondary wd:* entities referenced by kept properties
  defp add_secondary_resources(filtered_graph, original_graph) do
    secondary_iris =
      filtered_graph
      |> RDF.Graph.triples()
      |> Enum.flat_map(fn
        {_s, _p, %RDF.IRI{} = iri} ->
          if String.starts_with?(to_string(iri), Wikidata.wd_prefix()), do: [iri], else: []

        _ ->
          []
      end)
      |> Enum.uniq()

    Enum.reduce(secondary_iris, filtered_graph, fn iri, graph ->
      if description = RDF.Graph.get(original_graph, iri) do
        RDF.Graph.add(graph, description)
      else
        graph
      end
    end)
  end

  defp wdt_property?(predicate) do
    to_string(predicate) |> String.starts_with?(Wikidata.wdt_prefix())
  end

  defp ignored?(predicate, config) do
    property_id = predicate |> to_string() |> Wikidata.property_id()
    PropertyConfig.ignored?(config, property_id)
  end

  # Filter language-tagged literals to only de and en
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
end
