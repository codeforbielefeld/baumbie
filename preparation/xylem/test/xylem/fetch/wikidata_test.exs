defmodule Xylem.Fetch.WikidataTest do
  use ExUnit.Case

  import ReqCassette
  import ExUnit.CaptureLog

  alias Xylem.Fetch.Wikidata

  @test_raw_dir "test/fixtures/wikidata_raw"

  setup do
    File.mkdir_p!(@test_raw_dir)
    on_exit(fn -> File.rm_rf!(@test_raw_dir) end)
    :ok
  end

  describe "run/2" do
    test "fetches and parses Wikidata entity" do
      species = [
        %{baumart_bo: "Quercus robur", baumart_de: "Stiel-Eiche", wikidata_id: "Q165145"}
      ]

      with_cassette("wikidata_fetch_q165145", fn plug ->
        {:ok, result} = Wikidata.run(species, raw_dir: @test_raw_dir, delay_ms: 0, plug: plug)

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
