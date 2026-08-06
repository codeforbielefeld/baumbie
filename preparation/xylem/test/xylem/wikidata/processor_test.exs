defmodule Xylem.Wikidata.ProcessorTest do
  use ExUnit.Case

  alias Xylem.Wikidata.Processor
  alias Xylem.Wikidata.PropertyConfig
  alias RDF.NS.RDFS
  alias RDF.{Graph, Turtle}

  import RDF.Sigils

  @wdt_prefix "http://www.wikidata.org/prop/direct/"
  @wd_prefix "http://www.wikidata.org/entity/"
  @test_processed_dir "test/fixtures/processed"

  setup do
    {:ok, config} = PropertyConfig.load(path: "test/fixtures/test_properties.csv")
    File.mkdir_p!(@test_processed_dir)
    on_exit(fn -> File.rm_rf!(@test_processed_dir) end)
    %{config: config}
  end

  defp subject, do: RDF.iri("#{@wd_prefix}Q12345")

  defp build_species(graph) do
    %{
      baumart_bo: "Quercus robur",
      baumart_de: "Stiel-Eiche",
      wikidata_id: "Q12345",
      graph: graph,
      raw_path: "/tmp/Q12345.ttl"
    }
  end

  defp run_processor(species, config) do
    Processor.run(
      [species],
      property_config: config,
      processed_dir: @test_processed_dir
    )
  end

  describe "run/2" do
    test "produces a processed Turtle file", %{config: config} do
      graph = Graph.new({subject(), wdt("P225"), RDF.literal("Quercus robur")})

      {:ok, [result]} = run_processor(build_species(graph), config)

      assert result.wikidata_id == "Q12345"
      assert result.processed_path == "#{@test_processed_dir}/Q12345.ttl"
      assert File.exists?(result.processed_path)
    end

    test "keeps wdt: properties", %{config: config} do
      graph =
        Graph.new([
          {subject(), wdt("P225"), RDF.literal("Quercus robur")},
          {subject(), wdt("P685"), RDF.literal("38942")}
        ])

      {:ok, [result]} = run_processor(build_species(graph), config)
      processed = Turtle.read_file!(result.processed_path)

      assert has_triple?(processed, subject(), wdt("P225"), RDF.literal("Quercus robur"))
      assert has_triple?(processed, subject(), wdt("P685"), RDF.literal("38942"))
    end

    test "removes blacklisted properties", %{config: config} do
      graph =
        Graph.new([
          {subject(), wdt("P225"), RDF.literal("Quercus robur")},
          {subject(), wdt("P18"),
           RDF.iri("http://commons.wikimedia.org/wiki/Special:FilePath/Image.jpg")}
        ])

      {:ok, [result]} = run_processor(build_species(graph), config)
      processed = Turtle.read_file!(result.processed_path)

      assert has_triple?(processed, subject(), wdt("P225"), RDF.literal("Quercus robur"))
      refute has_predicate?(processed, subject(), wdt("P18"))
    end

    test "removes non-wdt properties (p:, ps:, pq:, etc.)", %{config: config} do
      graph =
        Graph.new()
        |> Graph.add({subject(), wdt("P225"), RDF.literal("Quercus robur")})
        |> Graph.add(
          {subject(), RDF.iri("http://www.wikidata.org/prop/P225"),
           RDF.iri("http://www.wikidata.org/entity/statement/q12345-abc")}
        )
        |> Graph.add({subject(), RDF.type(), RDF.iri("http://wikiba.se/ontology#Item")})

      {:ok, [result]} = run_processor(build_species(graph), config)
      processed = Turtle.read_file!(result.processed_path)

      assert has_triple?(processed, subject(), wdt("P225"), RDF.literal("Quercus robur"))
      refute has_predicate?(processed, subject(), RDF.iri("http://www.wikidata.org/prop/P225"))
      refute has_predicate?(processed, subject(), RDF.type())
    end

    test "removes triples from other subjects (schema:Article, etc.)", %{config: config} do
      article = RDF.iri("https://de.wikipedia.org/wiki/Stieleiche")

      graph =
        Graph.new()
        |> Graph.add({subject(), wdt("P225"), RDF.literal("Quercus robur")})
        |> Graph.add({article, RDF.type(), RDF.iri("http://schema.org/Article")})
        |> Graph.add({article, RDF.iri("http://schema.org/about"), subject()})

      {:ok, [result]} = run_processor(build_species(graph), config)
      processed = Turtle.read_file!(result.processed_path)

      assert has_triple?(processed, subject(), wdt("P225"), RDF.literal("Quercus robur"))
      assert Graph.get(processed, article) == nil
    end

    test "keeps rdfs:label in de and en", %{config: config} do
      graph =
        Graph.new()
        |> Graph.add({subject(), wdt("P225"), RDF.literal("Quercus robur")})
        |> Graph.add({subject(), RDFS.label(), ~L"Stieleiche"de})
        |> Graph.add({subject(), RDFS.label(), ~L"Pedunculate oak"en})
        |> Graph.add({subject(), RDFS.label(), ~L"Chêne pédonculé"fr})

      {:ok, [result]} = run_processor(build_species(graph), config)
      processed = Turtle.read_file!(result.processed_path)

      assert has_triple?(processed, subject(), RDFS.label(), ~L"Stieleiche"de)
      assert has_triple?(processed, subject(), RDFS.label(), ~L"Pedunculate oak"en)
      refute has_triple?(processed, subject(), RDFS.label(), ~L"Chêne pédonculé"fr)
    end

    test "filters language-tagged literals on wdt: properties to de and en", %{config: config} do
      graph =
        Graph.new()
        |> Graph.add({subject(), wdt("P1843"), ~L"Stieleiche"de})
        |> Graph.add({subject(), wdt("P1843"), ~L"Pedunculate oak"en})
        |> Graph.add({subject(), wdt("P1843"), ~L"Дуб черешчатый"ru})
        |> Graph.add({subject(), wdt("P1843"), ~L"夏櫟"zh})

      {:ok, [result]} = run_processor(build_species(graph), config)
      processed = Turtle.read_file!(result.processed_path)

      labels = Graph.get(processed, subject()) |> RDF.Description.get(wdt("P1843"))
      assert length(labels) == 2
      assert ~L"Stieleiche"de in labels
      assert ~L"Pedunculate oak"en in labels
    end

    test "keeps non-language-tagged literals unchanged", %{config: config} do
      graph =
        Graph.new()
        |> Graph.add({subject(), wdt("P225"), RDF.literal("Quercus robur")})
        |> Graph.add({subject(), wdt("P685"), RDF.literal("38942")})

      {:ok, [result]} = run_processor(build_species(graph), config)
      processed = Turtle.read_file!(result.processed_path)

      assert has_triple?(processed, subject(), wdt("P225"), RDF.literal("Quercus robur"))
      assert has_triple?(processed, subject(), wdt("P685"), RDF.literal("38942"))
    end

    test "keeps entity IRI values on wdt: properties", %{config: config} do
      # P141 is not in test config, so kept by default
      entity = RDF.iri("#{@wd_prefix}Q211005")

      graph =
        Graph.new()
        |> Graph.add({subject(), wdt("P141"), entity})

      {:ok, [result]} = run_processor(build_species(graph), config)
      processed = Turtle.read_file!(result.processed_path)

      assert has_triple?(processed, subject(), wdt("P141"), entity)
    end

    test "keeps descriptions of secondary wd:* entities referenced by kept properties", %{
      config: config
    } do
      # P141 is not in test config, so kept by default
      entity = RDF.iri("#{@wd_prefix}Q211005")

      graph =
        Graph.new()
        |> Graph.add({subject(), wdt("P141"), entity})
        |> Graph.add({entity, RDFS.label(), ~L"nicht gefährdet"de})
        |> Graph.add({entity, RDFS.label(), ~L"Least Concern"en})

      {:ok, [result]} = run_processor(build_species(graph), config)
      processed = Turtle.read_file!(result.processed_path)

      assert has_triple?(processed, entity, RDFS.label(), ~L"nicht gefährdet"de)
      assert has_triple?(processed, entity, RDFS.label(), ~L"Least Concern"en)
    end

    test "does not keep descriptions of secondary entities only referenced via ignored properties",
         %{config: config} do
      # P18 is ignored in test config
      image_entity = RDF.iri("http://commons.wikimedia.org/wiki/Special:FilePath/Image.jpg")

      graph =
        Graph.new()
        |> Graph.add({subject(), wdt("P225"), RDF.literal("Quercus robur")})
        |> Graph.add({subject(), wdt("P18"), image_entity})
        |> Graph.add({image_entity, RDF.iri("http://schema.org/name"), RDF.literal("Some image")})

      {:ok, [result]} = run_processor(build_species(graph), config)
      processed = Turtle.read_file!(result.processed_path)

      assert Graph.get(processed, image_entity) == nil
    end

    test "applies language filter to secondary resource descriptions too", %{config: config} do
      # P141 is not in test config, so kept by default
      entity = RDF.iri("#{@wd_prefix}Q211005")

      graph =
        Graph.new()
        |> Graph.add({subject(), wdt("P141"), entity})
        |> Graph.add({entity, RDFS.label(), ~L"nicht gefährdet"de})
        |> Graph.add({entity, RDFS.label(), ~L"Préoccupation mineure"fr})

      {:ok, [result]} = run_processor(build_species(graph), config)
      processed = Turtle.read_file!(result.processed_path)

      assert has_triple?(processed, entity, RDFS.label(), ~L"nicht gefährdet"de)
      refute has_triple?(processed, entity, RDFS.label(), ~L"Préoccupation mineure"fr)
    end

    test "inlines entity link as baumbie: property with resolved label", %{config: config} do
      # P105 is configured as inline with target: "taxonomischer_rang" in test CSV
      entity = RDF.iri("#{@wd_prefix}Q7432")

      graph =
        Graph.new()
        |> Graph.add({subject(), wdt("P105"), entity})
        |> Graph.add({entity, RDFS.label(), ~L"Art"de})

      {:ok, [result]} = run_processor(build_species(graph), config)
      processed = Turtle.read_file!(result.processed_path)

      baumbie_prop = RDF.iri("https://www.baumbie.org/xylem/vocab/taxonomischer_rang")

      assert has_triple?(processed, subject(), baumbie_prop, ~L"Art"de)
      # Original link removed (keep_source defaults to false)
      refute has_triple?(processed, subject(), wdt("P105"), entity)
    end

    test "inlining prefers German label, falls back to English", %{config: config} do
      entity = RDF.iri("#{@wd_prefix}Q7432")

      graph =
        Graph.new()
        |> Graph.add({subject(), wdt("P105"), entity})
        |> Graph.add({entity, RDFS.label(), ~L"Species"en})

      {:ok, [result]} = run_processor(build_species(graph), config)
      processed = Turtle.read_file!(result.processed_path)

      baumbie_prop = RDF.iri("https://www.baumbie.org/xylem/vocab/taxonomischer_rang")

      assert has_triple?(processed, subject(), baumbie_prop, ~L"Species"en)
    end

    test "inlining with keep_source: true keeps original link", %{config: config} do
      # P171 is configured as inline with keep_source: true in test CSV
      entity = RDF.iri("#{@wd_prefix}Q12004")

      graph =
        Graph.new()
        |> Graph.add({subject(), wdt("P171"), entity})
        |> Graph.add({entity, RDFS.label(), ~L"Eichen"de})

      {:ok, [result]} = run_processor(build_species(graph), config)
      processed = Turtle.read_file!(result.processed_path)

      baumbie_prop = RDF.iri("https://www.baumbie.org/xylem/vocab/uebergeordnetes_taxon")

      assert has_triple?(processed, subject(), baumbie_prop, ~L"Eichen"de)
      # Original link kept
      assert has_triple?(processed, subject(), wdt("P171"), entity)
    end

    test "inlining skips entities without labels in raw graph", %{config: config} do
      entity = RDF.iri("#{@wd_prefix}Q7432")

      # No rdfs:label for Q7432 in the graph
      graph =
        Graph.new()
        |> Graph.add({subject(), wdt("P105"), entity})

      {:ok, [result]} = run_processor(build_species(graph), config)
      processed = Turtle.read_file!(result.processed_path)

      baumbie_prop = RDF.iri("https://www.baumbie.org/xylem/vocab/taxonomischer_rang")

      refute has_predicate?(processed, subject(), baumbie_prop)
      # Original link still there since inlining was skipped
      assert has_triple?(processed, subject(), wdt("P105"), entity)
    end

    test "inlining removes secondary resource only referenced via inlined property", %{
      config: config
    } do
      entity = RDF.iri("#{@wd_prefix}Q7432")

      graph =
        Graph.new()
        |> Graph.add({subject(), wdt("P105"), entity})
        |> Graph.add({entity, RDFS.label(), ~L"Art"de})

      {:ok, [result]} = run_processor(build_species(graph), config)
      processed = Turtle.read_file!(result.processed_path)

      # Secondary resource removed since it was only referenced via inlined P105
      assert Graph.get(processed, entity) == nil
    end

    test "returns result map without graph and raw_path", %{config: config} do
      graph = Graph.new({subject(), wdt("P225"), RDF.literal("Quercus robur")})

      {:ok, [result]} = run_processor(build_species(graph), config)

      assert result.baumart_bo == "Quercus robur"
      assert result.baumart_de == "Stiel-Eiche"
      assert result.wikidata_id == "Q12345"
      assert result.processed_path
      refute Map.has_key?(result, :graph)
      refute Map.has_key?(result, :raw_path)
    end
  end

  # Helpers

  defp wdt(property_id), do: RDF.iri("#{@wdt_prefix}#{property_id}")

  defp has_triple?(graph, subject, predicate, object) do
    Graph.include?(graph, {subject, predicate, object})
  end

  defp has_predicate?(graph, subject, predicate) do
    if desc = Graph.get(graph, subject) do
      predicate in RDF.Description.predicates(desc)
    else
      false
    end
  end
end
