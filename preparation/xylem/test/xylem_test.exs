defmodule XylemTest do
  use ExUnit.Case
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  import ReqCassette

  alias Xylem.ImportInputError

  @test_raw_dir "test/fixtures/wikidata_raw"
  @test_processed_dir "test/fixtures/wikidata_processed"
  @test_meta_dir "test/fixtures/wikidata_meta"
  @test_config_path "test/fixtures/test_properties_integration.csv"

  setup do
    File.mkdir_p!(@test_raw_dir)
    File.mkdir_p!(@test_processed_dir)
    File.mkdir_p!(@test_meta_dir)

    # Copy test properties CSV so auto-append doesn't modify the original
    File.cp!("test/fixtures/test_properties.csv", @test_config_path)

    on_exit(fn ->
      File.rm_rf!(@test_raw_dir)
      File.rm_rf!(@test_processed_dir)
      File.rm_rf!(@test_meta_dir)
      File.rm(@test_config_path)
    end)

    :ok
  end

  describe "run/1" do
    test "runs complete pipeline" do
      use_cassette "pipeline_integration" do
        with_cassette("pipeline_wikidata", fn plug ->
          {:ok, result} =
            Xylem.run(
              csv_path: "test/fixtures/test_species.csv",
              property_config_path: @test_config_path,
              raw_dir: @test_raw_dir,
              processed_dir: @test_processed_dir,
              meta_dir: @test_meta_dir,
              limit: 1,
              delay_ms: 0,
              plug: plug,
              descriptions: RDF.Graph.new()
            )

          assert length(result.successful) == 1
          assert result.failed_fetches == []
          assert result.vocab_path == "#{@test_meta_dir}/vocab.ttl"

          # Processed TTL file exists
          processed = hd(result.successful)
          assert File.exists?(processed.processed_path)

          # Vocab file exists
          assert File.exists?(result.vocab_path)
        end)
      end
    end

    test "fetches, processes and limits distinct entities rather than mapping rows" do
      test_pid = self()

      ttl = """
      @prefix wd: <http://www.wikidata.org/entity/> .
      @prefix wdt: <http://www.wikidata.org/prop/direct/> .
      wd:Q26745 wdt:P105 "Art" .
      """

      plug = fn conn ->
        send(test_pid, {:fetched, conn.request_path})
        Plug.Conn.resp(conn, 200, ttl)
      end

      # 3 mapping rows, 2 entities: limit 1 must yield the first entity only.
      {:ok, result} =
        Xylem.run(
          csv_path: "test/fixtures/test_species_shared_qid.csv",
          property_config_path: @test_config_path,
          raw_dir: @test_raw_dir,
          processed_dir: @test_processed_dir,
          meta_dir: @test_meta_dir,
          fetch: :force,
          limit: 1,
          delay_ms: 0,
          plug: plug,
          descriptions: RDF.Graph.new()
        )

      assert_received {:fetched, "/wiki/Special:EntityData/Q26745.ttl"}
      refute_received {:fetched, _}

      assert Enum.map(result.successful, & &1.wikidata_id) == ["Q26745"]
      assert Path.wildcard(Path.join(@test_raw_dir, "*")) == ["#{@test_raw_dir}/Q26745.ttl"]

      assert Path.wildcard(Path.join(@test_processed_dir, "*")) == [
               "#{@test_processed_dir}/Q26745.ttl"
             ]
    end

    test "returns error for missing CSV" do
      assert Xylem.run(
               csv_path: "nonexistent.csv",
               property_config_path: @test_config_path
             ) ==
               {:error,
                %ImportInputError{
                  source: :mapping_csv,
                  path: "nonexistent.csv",
                  reason: :file_read,
                  details: :enoent,
                  line: nil
                }}
    end

    test "returns error for missing property config" do
      assert Xylem.run(property_config_path: "nonexistent.csv") ==
               {:error,
                %ImportInputError{
                  source: :property_config,
                  path: "nonexistent.csv",
                  reason: :file_read,
                  details: :enoent,
                  line: nil
                }}
    end
  end
end
