defmodule Xylem.BaumBie.ImporterTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Xylem.BaumBie.Importer

  @fixtures "test/fixtures"

  setup do
    previous_level = Logger.level()
    Logger.configure(level: :info)
    on_exit(fn -> Logger.configure(level: previous_level) end)
  end

  test "dry-run reports the exact preflight plan without writing" do
    opts = [
      input: Path.join(@fixtures, "import_plan_review.csv"),
      config: Path.join(@fixtures, "test_properties.csv"),
      mapping: Path.join(@fixtures, "test_species.csv"),
      trees: Path.join(@fixtures, "import_plan_trees.geojson"),
      dry_run: true
    ]

    log =
      capture_log([level: :info], fn ->
        assert Importer.run(opts) ==
                 {:ok,
                  %{
                    tree_types_derived: 1,
                    matched: 1,
                    unmatched_cadastre: 0,
                    unmatched_mapping: 1,
                    attributes: 1,
                    values: 1,
                    skipped_values: 1,
                    warnings: 1,
                    dry_run: true
                  }}
      end)

    assert log =~
             "Dry-run species: Quercus robur | status=matched | wikidata_id=Q165145 | " <>
               "values=1 | skips=duplicate_value=1"

    assert log =~
             "Dry-run attribute: P105 | taxonomischer_rang | type=string | values=1"

    assert log =~ "Dry-run totals: warnings=1 | skips=1"
  end
end
