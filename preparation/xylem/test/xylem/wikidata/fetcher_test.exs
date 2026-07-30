defmodule Xylem.Wikidata.FetcherTest do
  use ExUnit.Case

  import ReqCassette
  import ExUnit.CaptureLog

  alias Xylem.Wikidata.Fetcher

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

  @maple %{baumart_bo: "Acer platanoides", baumart_de: "Spitz-Ahorn", wikidata_id: "Q26745"}
  @maple_cultivar %{
    baumart_bo: "Acer platanoides 'Columnaris'",
    baumart_de: "Säulen-Ahorn",
    wikidata_id: "Q26745"
  }

  # Records every request so tests can assert on the exact number of fetches.
  defp recording_plug do
    test_pid = self()

    fn conn ->
      send(test_pid, {:fetched, conn.request_path})
      Plug.Conn.resp(conn, 200, @valid_ttl)
    end
  end

  describe "run/2" do
    test "fetches and parses Wikidata entity" do
      with_cassette("wikidata_fetch_q165145", fn plug ->
        {:ok, result} =
          Fetcher.run(@test_species, raw_dir: @test_raw_dir, delay_ms: 0, plug: plug)

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
                 Fetcher.run(species, raw_dir: @test_raw_dir, delay_ms: 0)
               end)

      assert log =~ "Failed to fetch INVALID123: {:invalid_wikidata_id, \"INVALID123\"}"

      assert result.successful == []
      assert length(result.failed) == 1
      assert hd(result.failed).error == {:invalid_wikidata_id, "INVALID123"}
    end

    test "fetches a QID shared by several tree types exactly once" do
      {:ok, result} =
        Fetcher.run([@maple, @maple_cultivar],
          raw_dir: @test_raw_dir,
          fetch: :force,
          delay_ms: 0,
          plug: recording_plug()
        )

      assert_received {:fetched, "/wiki/Special:EntityData/Q26745.ttl"}
      refute_received {:fetched, _}

      assert Enum.map(result.successful, & &1.wikidata_id) == ["Q26745"]
      assert result.failed == []

      # One raw file, and no temporary file left behind by the atomic write.
      assert Path.wildcard(Path.join(@test_raw_dir, "*")) == [
               Path.join(@test_raw_dir, "Q26745.ttl")
             ]
    end
  end

  describe "run/2 fetch modes" do
    test "skip loads existing .ttl files from disk" do
      File.write!(Path.join(@test_raw_dir, "Q165145.ttl"), @valid_ttl)

      {:ok, result} =
        Fetcher.run(@test_species, raw_dir: @test_raw_dir, fetch: :skip, delay_ms: 0)

      assert length(result.successful) == 1
      assert [loaded] = result.successful
      assert loaded.wikidata_id == "Q165145"
      assert %RDF.Graph{} = loaded.graph
      assert result.failed == []
    end

    test "skip reports missing .ttl files as failed" do
      {:ok, result} =
        Fetcher.run(@test_species, raw_dir: @test_raw_dir, fetch: :skip, delay_ms: 0)

      assert result.successful == []
      assert length(result.failed) == 1
      assert hd(result.failed).wikidata_id == "Q165145"
    end

    test "auto loads existing data when raw directory has .ttl files" do
      File.write!(Path.join(@test_raw_dir, "Q165145.ttl"), @valid_ttl)

      {:ok, result} =
        Fetcher.run(@test_species, raw_dir: @test_raw_dir, fetch: :auto, delay_ms: 0)

      assert length(result.successful) == 1
      assert hd(result.successful).wikidata_id == "Q165145"
    end

    test "auto loads what is cached, fetches only the rest and reports stale files" do
      File.write!(Path.join(@test_raw_dir, "Q165145.ttl"), @valid_ttl)
      stale_file = Path.join(@test_raw_dir, "Q999.ttl")
      File.write!(stale_file, @valid_ttl)

      {:ok, result} =
        Fetcher.run(@test_species ++ [@maple],
          raw_dir: @test_raw_dir,
          fetch: :auto,
          delay_ms: 0,
          plug: recording_plug()
        )

      assert_received {:fetched, "/wiki/Special:EntityData/Q26745.ttl"}
      refute_received {:fetched, _}

      assert Enum.map(result.successful, & &1.wikidata_id) == ["Q165145", "Q26745"]
      assert result.failed == []
      assert result.stale == [stale_file]
      assert File.exists?(stale_file)
    end

    test "a malformed 200 response leaves a valid cached file untouched" do
      path = Path.join(@test_raw_dir, "Q165145.ttl")
      File.write!(path, @valid_ttl)

      plug = fn conn -> Plug.Conn.resp(conn, 200, "this is not turtle") end

      {{:ok, result}, _log} =
        with_log(fn ->
          Fetcher.run(@test_species,
            raw_dir: @test_raw_dir,
            fetch: :force,
            delay_ms: 0,
            plug: plug
          )
        end)

      assert result.successful == []
      assert [%{wikidata_id: "Q165145"}] = result.failed

      # The cached graph must survive, otherwise the next :auto run would treat
      # the entity as cached and load the broken file instead of refetching.
      assert File.read!(path) == @valid_ttl
      assert Path.wildcard(Path.join(@test_raw_dir, "*")) == [path]
    end

    test "stale reporting judges against the full scope, not the requested subset" do
      File.write!(Path.join(@test_raw_dir, "Q165145.ttl"), @valid_ttl)
      File.write!(Path.join(@test_raw_dir, "Q26745.ttl"), @valid_ttl)
      stale_file = Path.join(@test_raw_dir, "Q999.ttl")
      File.write!(stale_file, @valid_ttl)

      # Only one entity requested (as with --limit), but both are known.
      {:ok, result} =
        Fetcher.run(@test_species,
          raw_dir: @test_raw_dir,
          fetch: :auto,
          delay_ms: 0,
          stale_scope: ["Q165145", "Q26745"]
        )

      assert result.stale == [stale_file]
    end

    test "auto fetches when raw directory is empty" do
      with_cassette("wikidata_fetch_q165145", fn plug ->
        {:ok, result} =
          Fetcher.run(@test_species,
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
          Fetcher.run(@test_species,
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
          Fetcher.run(@test_species,
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
        {:ok, result} = Fetcher.fetch_species(species, @test_raw_dir, plug: plug)

        assert result.wikidata_id == "Q434"
        assert %RDF.Graph{} = result.graph
      end)
    end
  end
end
