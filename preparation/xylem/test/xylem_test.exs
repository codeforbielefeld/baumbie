defmodule XylemTest do
  use ExUnit.Case
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  import ReqCassette

  @test_output_dir "test/fixtures/output"
  @test_raw_dir "test/fixtures/wikidata_raw"

  setup do
    File.mkdir_p!(@test_output_dir)
    File.mkdir_p!(@test_raw_dir)

    on_exit(fn ->
      File.rm_rf!(@test_output_dir)
      File.rm_rf!(@test_raw_dir)
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
              output_dir: @test_output_dir,
              raw_dir: @test_raw_dir,
              limit: 1,
              delay_ms: 0,
              plug: plug
            )

          assert length(result.successful) == 1
          assert result.failed_fetches == []
        end)
      end
    end

    test "returns error for missing CSV" do
      assert {:error, :enoent} = Xylem.run(csv_path: "nonexistent.csv")
    end
  end
end
