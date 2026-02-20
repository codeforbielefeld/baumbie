defmodule XylemTest do
  use ExUnit.Case
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  import ReqCassette

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

    test "returns error for missing CSV" do
      assert {:error, :enoent} = Xylem.run(csv_path: "nonexistent.csv")
    end

    test "returns error for missing property config" do
      assert {:error, :enoent} = Xylem.run(property_config_path: "nonexistent.csv")
    end
  end
end
