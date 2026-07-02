defmodule Xylem.Wikidata.VocabGeneratorTest do
  use ExUnit.Case

  alias Xylem.Wikidata.VocabGenerator
  alias Xylem.Wikidata.PropertyConfig

  @wd_prefix "http://www.wikidata.org/entity/"
  @wdt_prefix "http://www.wikidata.org/prop/direct/"
  @baumbie_prefix "https://www.baumbie.org/xylem/vocab/"
  @rdfs_label RDF.iri("http://www.w3.org/2000/01/rdf-schema#label")
  @schema_description RDF.iri("http://schema.org/description")

  @test_meta_dir "test/fixtures/meta"
  @test_processed_dir "test/fixtures/vocab_processed"

  setup do
    {:ok, config} = PropertyConfig.load(path: "test/fixtures/test_properties.csv")
    File.mkdir_p!(@test_processed_dir)

    on_exit(fn ->
      File.rm_rf!(@test_processed_dir)
      File.rm_rf!(@test_meta_dir)
    end)

    %{config: config}
  end

  defp write_processed(wikidata_id, graph) do
    path = Path.join(@test_processed_dir, "#{wikidata_id}.ttl")
    content = RDF.Turtle.write_string!(graph)
    File.write!(path, content)
    %{wikidata_id: wikidata_id, processed_path: path}
  end

  defp run_generator(species_results, config, opts \\ []) do
    VocabGenerator.run(
      species_results,
      [
        property_config: config,
        meta_dir: @test_meta_dir,
        descriptions: Keyword.get(opts, :descriptions, RDF.Graph.new())
      ] ++ opts
    )
  end

  describe "run/2" do
    test "includes wdt: property descriptions from SPARQL results", %{config: config} do
      subject = RDF.iri("#{@wd_prefix}Q12345")

      graph =
        RDF.Graph.new()
        |> RDF.Graph.add({subject, wdt("P225"), RDF.literal("Quercus robur")})
        |> RDF.Graph.add({subject, wdt("P685"), RDF.literal("38942")})

      result = write_processed("Q12345", graph)

      descriptions =
        RDF.Graph.new()
        |> RDF.Graph.add(
          {wd("P225"), @rdfs_label, RDF.lang_string("wissenschaftlicher Name", "de")}
        )
        |> RDF.Graph.add({wd("P225"), @rdfs_label, RDF.lang_string("taxon name", "en")})
        |> RDF.Graph.add(
          {wd("P225"), @schema_description, RDF.lang_string("Name der Taxonomie-Einheit", "de")}
        )
        |> RDF.Graph.add({wd("P685"), @rdfs_label, RDF.lang_string("NCBI-Taxonomy-ID", "de")})

      {:ok, path} = run_generator([result], config, descriptions: descriptions)
      vocab = RDF.Turtle.read_file!(path)

      assert has_triple?(
               vocab,
               wd("P225"),
               @rdfs_label,
               RDF.lang_string("wissenschaftlicher Name", "de")
             )

      assert has_triple?(
               vocab,
               wd("P225"),
               @rdfs_label,
               RDF.lang_string("taxon name", "en")
             )

      assert has_triple?(
               vocab,
               wd("P225"),
               @schema_description,
               RDF.lang_string("Name der Taxonomie-Einheit", "de")
             )

      assert has_triple?(
               vocab,
               wd("P685"),
               @rdfs_label,
               RDF.lang_string("NCBI-Taxonomy-ID", "de")
             )
    end

    test "includes inlined property descriptions even when removed from processed graph", %{
      config: config
    } do
      subject = RDF.iri("#{@wd_prefix}Q12345")

      # P105 is inlined with keep_source: false, so wdt:P105 won't be in the processed graph.
      # Instead, baumbie:taxonomischer_rang is added.
      graph =
        RDF.Graph.new()
        |> RDF.Graph.add(
          {subject, RDF.iri("#{@baumbie_prefix}taxonomischer_rang"), RDF.lang_string("Art", "de")}
        )

      result = write_processed("Q12345", graph)

      descriptions =
        RDF.Graph.new()
        |> RDF.Graph.add({wd("P105"), @rdfs_label, RDF.lang_string("taxonomischer Rang", "de")})

      {:ok, path} = run_generator([result], config, descriptions: descriptions)
      vocab = RDF.Turtle.read_file!(path)

      # wd:P105 description included (from inline config, not from processed graph)
      assert has_triple?(
               vocab,
               wd("P105"),
               @rdfs_label,
               RDF.lang_string("taxonomischer Rang", "de")
             )
    end

    test "adds baumbie: property labels from config descriptions", %{config: config} do
      subject = RDF.iri("#{@wd_prefix}Q12345")

      graph =
        RDF.Graph.new()
        |> RDF.Graph.add(
          {subject, RDF.iri("#{@baumbie_prefix}taxonomischer_rang"), RDF.lang_string("Art", "de")}
        )

      result = write_processed("Q12345", graph)
      {:ok, path} = run_generator([result], config)
      vocab = RDF.Turtle.read_file!(path)

      assert has_triple?(
               vocab,
               RDF.iri("#{@baumbie_prefix}taxonomischer_rang"),
               @rdfs_label,
               RDF.lang_string("taxonomischer Rang", "de")
             )
    end

    test "does not add baumbie: labels for inline properties not used in processed graphs", %{
      config: config
    } do
      subject = RDF.iri("#{@wd_prefix}Q12345")

      # Only baumbie:taxonomischer_rang used, not baumbie:uebergeordnetes_taxon
      graph =
        RDF.Graph.new()
        |> RDF.Graph.add(
          {subject, RDF.iri("#{@baumbie_prefix}taxonomischer_rang"), RDF.lang_string("Art", "de")}
        )

      result = write_processed("Q12345", graph)
      {:ok, path} = run_generator([result], config)
      vocab = RDF.Turtle.read_file!(path)

      assert has_predicate?(
               vocab,
               RDF.iri("#{@baumbie_prefix}taxonomischer_rang"),
               @rdfs_label
             )

      refute has_predicate?(
               vocab,
               RDF.iri("#{@baumbie_prefix}uebergeordnetes_taxon"),
               @rdfs_label
             )
    end

    test "combines properties from multiple species", %{config: config} do
      subject1 = RDF.iri("#{@wd_prefix}Q12345")
      subject2 = RDF.iri("#{@wd_prefix}Q67890")

      graph1 =
        RDF.Graph.new()
        |> RDF.Graph.add({subject1, wdt("P225"), RDF.literal("Quercus robur")})

      graph2 =
        RDF.Graph.new()
        |> RDF.Graph.add({subject2, wdt("P685"), RDF.literal("38942")})

      result1 = write_processed("Q12345", graph1)
      result2 = write_processed("Q67890", graph2)

      descriptions =
        RDF.Graph.new()
        |> RDF.Graph.add(
          {wd("P225"), @rdfs_label, RDF.lang_string("wissenschaftlicher Name", "de")}
        )
        |> RDF.Graph.add({wd("P685"), @rdfs_label, RDF.lang_string("NCBI-Taxonomy-ID", "de")})

      {:ok, path} = run_generator([result1, result2], config, descriptions: descriptions)
      vocab = RDF.Turtle.read_file!(path)

      assert has_predicate?(vocab, wd("P225"), @rdfs_label)
      assert has_predicate?(vocab, wd("P685"), @rdfs_label)
    end

    test "deduplicates properties across species", %{config: config} do
      subject1 = RDF.iri("#{@wd_prefix}Q12345")
      subject2 = RDF.iri("#{@wd_prefix}Q67890")

      graph1 =
        RDF.Graph.new()
        |> RDF.Graph.add({subject1, wdt("P225"), RDF.literal("Quercus robur")})

      graph2 =
        RDF.Graph.new()
        |> RDF.Graph.add({subject2, wdt("P225"), RDF.literal("Fagus sylvatica")})

      result1 = write_processed("Q12345", graph1)
      result2 = write_processed("Q67890", graph2)

      descriptions =
        RDF.Graph.new()
        |> RDF.Graph.add(
          {wd("P225"), @rdfs_label, RDF.lang_string("wissenschaftlicher Name", "de")}
        )

      {:ok, path} = run_generator([result1, result2], config, descriptions: descriptions)
      vocab = RDF.Turtle.read_file!(path)

      labels =
        vocab
        |> RDF.Graph.get(wd("P225"))
        |> RDF.Description.get(@rdfs_label)

      assert length(labels) == 1
    end

    test "filters language-tagged literals to de and en", %{config: config} do
      subject = RDF.iri("#{@wd_prefix}Q12345")

      graph =
        RDF.Graph.new()
        |> RDF.Graph.add({subject, wdt("P225"), RDF.literal("Quercus robur")})

      result = write_processed("Q12345", graph)

      descriptions =
        RDF.Graph.new()
        |> RDF.Graph.add(
          {wd("P225"), @rdfs_label, RDF.lang_string("wissenschaftlicher Name", "de")}
        )
        |> RDF.Graph.add({wd("P225"), @rdfs_label, RDF.lang_string("taxon name", "en")})
        |> RDF.Graph.add({wd("P225"), @rdfs_label, RDF.lang_string("nom scientifique", "fr")})

      {:ok, path} = run_generator([result], config, descriptions: descriptions)
      vocab = RDF.Turtle.read_file!(path)

      assert has_triple?(
               vocab,
               wd("P225"),
               @rdfs_label,
               RDF.lang_string("wissenschaftlicher Name", "de")
             )

      assert has_triple?(
               vocab,
               wd("P225"),
               @rdfs_label,
               RDF.lang_string("taxon name", "en")
             )

      refute has_triple?(
               vocab,
               wd("P225"),
               @rdfs_label,
               RDF.lang_string("nom scientifique", "fr")
             )
    end

    test "keeps non-language-tagged values unchanged", %{config: config} do
      subject = RDF.iri("#{@wd_prefix}Q12345")

      graph =
        RDF.Graph.new()
        |> RDF.Graph.add({subject, wdt("P225"), RDF.literal("Quercus robur")})

      result = write_processed("Q12345", graph)

      wikibase_type = RDF.iri("http://wikiba.se/ontology#propertyType")
      wikibase_string = RDF.iri("http://wikiba.se/ontology#String")

      descriptions =
        RDF.Graph.new()
        |> RDF.Graph.add({wd("P225"), wikibase_type, wikibase_string})

      {:ok, path} = run_generator([result], config, descriptions: descriptions)
      vocab = RDF.Turtle.read_file!(path)

      assert has_triple?(vocab, wd("P225"), wikibase_type, wikibase_string)
    end

    test "produces empty vocab for empty input", %{config: config} do
      {:ok, path} = run_generator([], config)

      vocab = RDF.Turtle.read_file!(path)
      assert RDF.Graph.triple_count(vocab) == 0
    end

    test "writes vocab.ttl file to meta_dir", %{config: config} do
      subject = RDF.iri("#{@wd_prefix}Q12345")

      graph =
        RDF.Graph.new()
        |> RDF.Graph.add({subject, wdt("P225"), RDF.literal("Quercus robur")})

      result = write_processed("Q12345", graph)
      {:ok, path} = run_generator([result], config)

      assert path == "#{@test_meta_dir}/vocab.ttl"
      assert File.exists?(path)
    end
  end

  # Helpers

  defp wdt(property_id), do: RDF.iri("#{@wdt_prefix}#{property_id}")
  defp wd(property_id), do: RDF.iri("#{@wd_prefix}#{property_id}")

  defp has_triple?(graph, subject, predicate, object) do
    graph
    |> RDF.Graph.triples()
    |> Enum.any?(fn {s, p, o} -> s == subject and p == predicate and o == object end)
  end

  defp has_predicate?(graph, subject, predicate) do
    case RDF.Graph.get(graph, subject) do
      nil -> false
      desc -> predicate in RDF.Description.predicates(desc)
    end
  end
end
