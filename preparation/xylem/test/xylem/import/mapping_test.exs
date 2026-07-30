defmodule Xylem.Import.MappingTest do
  use ExUnit.Case

  alias Xylem.Import.Mapping
  alias Xylem.MappingValidationError

  defp row(baumart_bo, baumart_de, wikidata_id) do
    %{baumart_bo: baumart_bo, baumart_de: baumart_de, wikidata_id: wikidata_id}
  end

  defp oak, do: row("Quercus robur", "Stiel-Eiche", "Q165145")
  defp maple, do: row("Acer platanoides", "Spitzahorn", "Q26745")
  defp maple_cultivar, do: row("Acer platanoides 'Columnaris'", "Säulen-Spitzahorn", "Q26745")

  describe "build/2" do
    test "projects targets and entities of a valid mapping" do
      assert Mapping.build([oak(), maple()], path: "mapping.csv") ==
               {:ok,
                %Mapping{
                  path: "mapping.csv",
                  targets: [
                    %{
                      baumart_bo: "Quercus robur",
                      baumart_de: "Stiel-Eiche",
                      wikidata_id: "Q165145",
                      line: 2
                    },
                    %{
                      baumart_bo: "Acer platanoides",
                      baumart_de: "Spitzahorn",
                      wikidata_id: "Q26745",
                      line: 3
                    }
                  ],
                  entities: [
                    %{
                      baumart_bo: "Quercus robur",
                      baumart_de: "Stiel-Eiche",
                      wikidata_id: "Q165145"
                    },
                    %{
                      baumart_bo: "Acer platanoides",
                      baumart_de: "Spitzahorn",
                      wikidata_id: "Q26745"
                    }
                  ],
                  warnings: []
                }}
    end

    test "keeps the cultivar fan-out as two targets but one entity" do
      {:ok, mapping} = Mapping.build([maple(), maple_cultivar()])

      assert Mapping.targets(mapping) == [
               %{
                 baumart_bo: "Acer platanoides",
                 baumart_de: "Spitzahorn",
                 wikidata_id: "Q26745",
                 line: 2
               },
               %{
                 baumart_bo: "Acer platanoides 'Columnaris'",
                 baumart_de: "Säulen-Spitzahorn",
                 wikidata_id: "Q26745",
                 line: 3
               }
             ]

      assert Mapping.entities(mapping) == [
               %{baumart_bo: "Acer platanoides", baumart_de: "Spitzahorn", wikidata_id: "Q26745"}
             ]
    end

    test "rejects a repeated (baumart_bo, QID) with both line numbers" do
      rows = [oak(), maple(), oak()]

      assert Mapping.build(rows, path: "mapping.csv") ==
               {:error,
                %MappingValidationError{
                  path: "mapping.csv",
                  issues: [
                    %{
                      code: :duplicate_mapping,
                      baumart_bo: "Quercus robur",
                      wikidata_id: "Q165145",
                      lines: [2, 4]
                    }
                  ]
                }}
    end

    test "rejects a repeated target even when the German name differs" do
      corrupted = row("Quercus robur", "Stiel-Eiche�", "Q165145")

      assert Mapping.build([oak(), corrupted]) ==
               {:error,
                %MappingValidationError{
                  path: nil,
                  issues: [
                    %{
                      code: :duplicate_mapping,
                      baumart_bo: "Quercus robur",
                      wikidata_id: "Q165145",
                      lines: [2, 3]
                    }
                  ]
                }}
    end

    test "rejects two QIDs for the same botanical name" do
      assert Mapping.build([oak(), row("Quercus robur", "Stiel-Eiche", "Q999")]) ==
               {:error,
                %MappingValidationError{
                  path: nil,
                  issues: [
                    %{
                      code: :conflicting_mapping_qids,
                      baumart_bo: "Quercus robur",
                      qids: ["Q165145", "Q999"],
                      lines: [2, 3]
                    }
                  ]
                }}
    end

    test "rejects names that collide only after canonicalization" do
      assert Mapping.build([
               row("Crataegus species", "Weißdorn", "Q132557"),
               row("Crataegus  species", "Weißdorn", "Q999")
             ]) ==
               {:error,
                %MappingValidationError{
                  path: nil,
                  issues: [
                    %{
                      code: :conflicting_mapping_qids,
                      baumart_bo: "Crataegus species",
                      qids: ["Q132557", "Q999"],
                      lines: [2, 3]
                    }
                  ]
                }}
    end

    test "rejects an invalid QID" do
      assert Mapping.build([row("Quercus robur", "Stiel-Eiche", "165145")]) ==
               {:error,
                %MappingValidationError{
                  path: nil,
                  issues: [
                    %{
                      code: :invalid_qid,
                      source: {:mapping, 2},
                      baumart_bo: "Quercus robur",
                      qid: "165145"
                    }
                  ]
                }}
    end

    test "rejects Q0 and leading zeroes" do
      for qid <- ["Q0", "Q007"] do
        assert {:error, %MappingValidationError{issues: [%{code: :invalid_qid, qid: ^qid}]}} =
                 Mapping.build([row("Quercus robur", "Stiel-Eiche", qid)])
      end
    end

    test "drops a blank QID with a warning" do
      rows = [row("Waldartiger Bestand", "Waldartiger Bestand", ""), oak()]

      assert Mapping.build(rows) ==
               {:ok,
                %Mapping{
                  path: nil,
                  targets: [
                    %{
                      baumart_bo: "Quercus robur",
                      baumart_de: "Stiel-Eiche",
                      wikidata_id: "Q165145",
                      line: 3
                    }
                  ],
                  entities: [
                    %{
                      baumart_bo: "Quercus robur",
                      baumart_de: "Stiel-Eiche",
                      wikidata_id: "Q165145"
                    }
                  ],
                  warnings: [
                    %{code: :blank_mapping_qid, baumart_bo: "Waldartiger Bestand", line: 2}
                  ]
                }}
    end

    test "reports every issue instead of stopping at the first" do
      rows = [
        oak(),
        row("Tilia cordata", "Winter-Linde", "nope"),
        oak()
      ]

      assert {:error, %MappingValidationError{issues: issues}} = Mapping.build(rows)
      assert Enum.map(issues, & &1.code) == [:invalid_qid, :duplicate_mapping]
    end
  end

  describe "validate/1" do
    test "returns targets, warnings and issues without raising" do
      rows = [oak(), row("Waldartiger Bestand", "Waldartiger Bestand", ""), oak()]

      assert Mapping.validate(rows) ==
               {[
                  %{
                    baumart_bo: "Quercus robur",
                    baumart_de: "Stiel-Eiche",
                    wikidata_id: "Q165145",
                    line: 2
                  }
                ], [%{code: :blank_mapping_qid, baumart_bo: "Waldartiger Bestand", line: 3}],
                [
                  %{
                    code: :duplicate_mapping,
                    baumart_bo: "Quercus robur",
                    wikidata_id: "Q165145",
                    lines: [2, 4]
                  }
                ]}
    end
  end

  describe "load/1" do
    test "reads and validates a mapping file" do
      {:ok, mapping} = Mapping.load("test/fixtures/test_species.csv")

      assert mapping.path == "test/fixtures/test_species.csv"

      assert Mapping.entities(mapping) == [
               %{baumart_bo: "Quercus robur", baumart_de: "Stiel-Eiche", wikidata_id: "Q165145"},
               %{
                 baumart_bo: "Carpinus betulus",
                 baumart_de: "Gemeine Hainbuche",
                 wikidata_id: "Q158776"
               }
             ]
    end

    test "propagates a read error" do
      assert {:error, %Xylem.ImportInputError{reason: :file_read}} =
               Mapping.load("nonexistent.csv")
    end
  end

  describe "canonical_name/1" do
    test "collapses whitespace, case and quote variants" do
      assert Mapping.canonical_name("Crataegus  species") == "crataegus species"
      assert Mapping.canonical_name("Abies  species") == "abies species"

      assert Mapping.canonical_name("Acer platanoides `Globosum`") ==
               Mapping.canonical_name("Acer platanoides 'Globosum'")
    end
  end
end
