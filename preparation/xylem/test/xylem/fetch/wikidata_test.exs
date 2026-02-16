defmodule Xylem.Fetch.WikidataTest do
  use ExUnit.Case

  import ReqCassette
  import ExUnit.CaptureLog

  alias Xylem.Fetch.Wikidata

  @test_raw_dir "test/fixtures/wikidata_raw"
  @valid_ttl """
  @prefix wd: <http://www.wikidata.org/entity/> .
  @prefix wdt: <http://www.wikidata.org/prop/direct/> .
  wd:Q165145 wdt:P31 wd:Q16521 .
  """

  setup do
    File.mkdir_p!(@test_raw_dir)
    on_exit(fn -> File.rm_rf!(@test_raw_dir) end)
    :ok
  end

  @test_species [
    %{baumart_bo: "Quercus robur", baumart_de: "Stiel-Eiche", wikidata_id: "Q165145"}
  ]

  describe "run/2" do
    test "fetches and parses Wikidata entity" do
      with_cassette("wikidata_fetch_q165145", fn plug ->
        {:ok, result} =
          Wikidata.run(@test_species, raw_dir: @test_raw_dir, delay_ms: 0, plug: plug)

        assert length(result.successful) == 1
        assert result.failed == []

        [fetched] = result.successful
        assert fetched.wikidata_id == "Q165145"
        assert %RDF.Graph{} = fetched.graph
        assert File.exists?(fetched.raw_path)
      end)
    end

    test "rejects invalid Wikidata IDs" do
      species = [
        %{baumart_bo: "Invalid", baumart_de: "Invalid", wikidata_id: "INVALID123"}
      ]

      assert {{:ok, result}, log} =
               with_log(fn ->
                 Wikidata.run(species, raw_dir: @test_raw_dir, delay_ms: 0)
               end)

      assert log =~ "Failed to fetch INVALID123: {:invalid_wikidata_id, \"INVALID123\"}"

      assert result.successful == []
      assert length(result.failed) == 1
      assert hd(result.failed).error == {:invalid_wikidata_id, "INVALID123"}
    end
  end

  describe "run/2 fetch modes" do
    test "skip loads existing .ttl files from disk" do
      File.write!(Path.join(@test_raw_dir, "Q165145.ttl"), @valid_ttl)

      {:ok, result} =
        Wikidata.run(@test_species, raw_dir: @test_raw_dir, fetch: :skip, delay_ms: 0)

      assert length(result.successful) == 1
      assert [loaded] = result.successful
      assert loaded.wikidata_id == "Q165145"
      assert %RDF.Graph{} = loaded.graph
      assert result.failed == []
    end

    test "skip reports missing .ttl files as failed" do
      {:ok, result} =
        Wikidata.run(@test_species, raw_dir: @test_raw_dir, fetch: :skip, delay_ms: 0)

      assert result.successful == []
      assert length(result.failed) == 1
      assert hd(result.failed).wikidata_id == "Q165145"
    end

    test "auto loads existing data when raw directory has .ttl files" do
      File.write!(Path.join(@test_raw_dir, "Q165145.ttl"), @valid_ttl)

      {:ok, result} =
        Wikidata.run(@test_species, raw_dir: @test_raw_dir, fetch: :auto, delay_ms: 0)

      assert length(result.successful) == 1
      assert hd(result.successful).wikidata_id == "Q165145"
    end

    test "auto fetches when raw directory is empty" do
      with_cassette("wikidata_fetch_q165145", fn plug ->
        {:ok, result} =
          Wikidata.run(@test_species,
            raw_dir: @test_raw_dir,
            fetch: :auto,
            delay_ms: 0,
            plug: plug
          )

        assert length(result.successful) == 1
      end)
    end

    test "force fetches even when raw directory has .ttl files" do
      File.mkdir_p!(@test_raw_dir)
      File.write!(Path.join(@test_raw_dir, "Q165145.ttl"), "dummy")

      with_cassette("wikidata_fetch_q165145", fn plug ->
        {:ok, result} =
          Wikidata.run(@test_species,
            raw_dir: @test_raw_dir,
            fetch: :force,
            delay_ms: 0,
            plug: plug
          )

        assert length(result.successful) == 1
      end)
    end

    test "clear deletes existing .ttl files and re-fetches" do
      File.mkdir_p!(@test_raw_dir)
      extra_file = Path.join(@test_raw_dir, "Q999.ttl")
      File.write!(extra_file, "dummy")

      with_cassette("wikidata_fetch_q165145", fn plug ->
        {:ok, result} =
          Wikidata.run(@test_species,
            raw_dir: @test_raw_dir,
            fetch: :clear,
            delay_ms: 0,
            plug: plug
          )

        assert length(result.successful) == 1
        refute File.exists?(extra_file)
      end)
    end
  end

  describe "fetch_species/2" do
    test "fetches single entity successfully" do
      species = %{baumart_bo: "Pyrus", baumart_de: "Birne", wikidata_id: "Q434"}

      with_cassette("wikidata_fetch_q434", fn plug ->
        {:ok, result} = Wikidata.fetch_species(species, @test_raw_dir, plug: plug)

        assert result.wikidata_id == "Q434"
        assert %RDF.Graph{} = result.graph
      end)
    end
  end
end
