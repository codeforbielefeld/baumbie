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
      dry_run: true
    ]

    log =
      capture_log([level: :info], fn ->
        assert Importer.run(opts) ==
                 {:ok,
                  %{
                    tree_types: 2,
                    attributes: 1,
                    values: 1,
                    skipped_values: 1,
                    warnings: 0,
                    dry_run: true
                  }}
      end)

    assert log =~
             "Dry-run species: Quercus robur | wikidata_id=Q165145 | " <>
               "values=1 | skips=duplicate_value=1"

    assert log =~
             "Dry-run species: Carpinus betulus | wikidata_id=Q158776 | values=0 | skips=none"

    assert log =~
             "Dry-run attribute: P105 | taxonomischer_rang | type=string | values=1"

    assert log =~ "Dry-run totals: warnings=0 | skips=1"
  end
end
