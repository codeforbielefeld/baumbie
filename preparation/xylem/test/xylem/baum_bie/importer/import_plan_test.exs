defmodule Xylem.BaumBie.Importer.ImportPlanTest do
  use ExUnit.Case, async: true

  alias Xylem.BaumBie.Importer.ImportPlan
  alias Xylem.ImportPreflightError
  alias Xylem.Wikidata.PropertyConfig

  defp mapping(name_botanic, name, qid) do
    %{baumart_bo: name_botanic, baumart_de: name, wikidata_id: qid}
  end

  defp target(mapping_row, line), do: Map.put(mapping_row, :line, line)

  defp review(name_botanic, name, qid, property_id, attribute_name, value) do
    %{
      wikidata_id: qid,
      baumart_bo: name_botanic,
      baumart_de: name,
      property_id: property_id,
      attribute_name: attribute_name,
      value: value,
      group: ""
    }
  end

  defp entry(attribute_name, opts \\ []) do
    %{
      type: Keyword.get(opts, :type, "WikibaseItem"),
      action: :keep,
      config: nil,
      description: Keyword.get(opts, :description, "Beschreibung"),
      import:
        case attribute_name do
          nil -> nil
          name -> %{group: "", attribute_name: name}
        end
    }
  end

  defp config(entries) do
    %PropertyConfig{entries: Map.new(entries, fn {id, value} -> {to_string(id), value} end)}
  end

  describe "build/3" do
    test "builds the complete import decision once" do
      oak_mapping = mapping("Quercus robur", "Stiel-Eiche", "Q165145")
      property = entry("taxonomischer_rang")

      row =
        review(
          "Quercus robur",
          "Stiel-Eiche",
          "Q165145",
          "P105",
          "taxonomischer_rang",
          "Art"
        )

      assert ImportPlan.build(config(P105: property), [oak_mapping], [row]) ==
               {:ok,
                %ImportPlan{
                  targets: [target(oak_mapping, 2)],
                  attribute_defs: [
                    %{
                      property_id: "P105",
                      attribute_name: "taxonomischer_rang",
                      entry: property,
                      type: "string"
                    }
                  ],
                  value_rows: [row],
                  skips: [],
                  warnings: [],
                  summary: %{
                    tree_types: 1,
                    attributes: 1,
                    values: 1,
                    skipped_values: 0
                  }
                }}
    end

    test "plans a tree type for a target without review values" do
      maple_mapping = mapping("Acer campestre", "Feld-Ahorn", "Q158785")

      assert ImportPlan.build(config([]), [maple_mapping], []) ==
               {:ok,
                %ImportPlan{
                  targets: [target(maple_mapping, 2)],
                  attribute_defs: [],
                  value_rows: [],
                  skips: [],
                  warnings: [],
                  summary: %{tree_types: 1, attributes: 0, values: 0, skipped_values: 0}
                }}
    end

    test "allows multiple tree types to share a QID" do
      mapping_rows = [
        mapping("Acer platanoides", "Spitz-Ahorn", "Q26745"),
        mapping("Acer platanoides 'Columnaris'", "Säulen-Ahorn", "Q26745")
      ]

      property = entry("wissenschaftlicher_name")

      review_rows = [
        review(
          "Acer platanoides",
          "Spitz-Ahorn",
          "Q26745",
          "P225",
          "wissenschaftlicher_name",
          "Acer platanoides"
        ),
        review(
          "Acer platanoides 'Columnaris'",
          "Säulen-Ahorn",
          "Q26745",
          "P225",
          "wissenschaftlicher_name",
          "Acer platanoides"
        )
      ]

      assert ImportPlan.build(config(P225: property), mapping_rows, review_rows) ==
               {:ok,
                %ImportPlan{
                  targets: [
                    target(Enum.at(mapping_rows, 0), 2),
                    target(Enum.at(mapping_rows, 1), 3)
                  ],
                  attribute_defs: [
                    %{
                      property_id: "P225",
                      attribute_name: "wissenschaftlicher_name",
                      entry: property,
                      type: "string"
                    }
                  ],
                  value_rows: review_rows,
                  skips: [],
                  warnings: [],
                  summary: %{
                    tree_types: 2,
                    attributes: 1,
                    values: 2,
                    skipped_values: 0
                  }
                }}
    end

    test "rejects malformed QIDs" do
      invalid_mapping = mapping("Acer campestre", "Feld-Ahorn", "q158785")

      assert ImportPlan.build(config([]), [invalid_mapping], []) ==
               {:error,
                %ImportPreflightError{
                  issues: [
                    %{
                      code: :invalid_qid,
                      source: {:mapping, 2},
                      baumart_bo: "Acer campestre",
                      qid: "q158785"
                    }
                  ]
                }}
    end

    test "derives no tree type from a mapping row with an empty QID" do
      empty_mapping = mapping("Waldartiger Bestand", "Waldartiger Bestand", "")

      assert ImportPlan.build(config([]), [empty_mapping], []) ==
               {:ok,
                %ImportPlan{
                  targets: [],
                  attribute_defs: [],
                  value_rows: [],
                  skips: [],
                  warnings: [
                    %{code: :blank_mapping_qid, baumart_bo: "Waldartiger Bestand", line: 2}
                  ],
                  summary: %{tree_types: 0, attributes: 0, values: 0, skipped_values: 0}
                }}
    end

    test "skips review values whose species is absent from the current mapping" do
      property = entry("taxonomischer_rang")

      row =
        review(
          "Tilia × europaea",
          "Holländische Linde",
          "Q163760",
          "P105",
          "taxonomischer_rang",
          "Art"
        )

      assert ImportPlan.build(config(P105: property), [], [row]) ==
               {:ok,
                %ImportPlan{
                  targets: [],
                  attribute_defs: [
                    %{
                      property_id: "P105",
                      attribute_name: "taxonomischer_rang",
                      entry: property,
                      type: "string"
                    }
                  ],
                  value_rows: [],
                  skips: [
                    %{
                      reason: :missing_mapping,
                      line: 2,
                      baumart_bo: "Tilia × europaea",
                      property_id: "P105"
                    }
                  ],
                  warnings: [
                    %{code: :missing_mapping, baumart_bo: "Tilia × europaea"}
                  ],
                  summary: %{tree_types: 0, attributes: 1, values: 0, skipped_values: 1}
                }}
    end

    test "rejects conflicting mapping QIDs for one botanical name" do
      mapping_rows = [
        mapping("Quercus robur", "Stiel-Eiche", "Q165145"),
        mapping("Quercus robur", "Stiel-Eiche", "Q42")
      ]

      assert ImportPlan.build(config([]), mapping_rows, []) ==
               {:error,
                %ImportPreflightError{
                  issues: [
                    %{
                      code: :conflicting_mapping_qids,
                      baumart_bo: "Quercus robur",
                      qids: ["Q165145", "Q42"],
                      lines: [2, 3]
                    }
                  ]
                }}
    end

    test "rejects a review QID that differs from the mapping" do
      oak_mapping = mapping("Quercus robur", "Stiel-Eiche", "Q165145")

      row =
        review(
          "Quercus robur",
          "Stiel-Eiche",
          "Q42",
          "P105",
          "taxonomischer_rang",
          "Art"
        )

      assert ImportPlan.build(config(P105: entry("taxonomischer_rang")), [oak_mapping], [row, row]) ==
               {:error,
                %ImportPreflightError{
                  issues: [
                    %{
                      code: :mapping_review_qid_mismatch,
                      source: {:review, 2},
                      baumart_bo: "Quercus robur",
                      mapping_qid: "Q165145",
                      review_qid: "Q42"
                    }
                  ]
                }}
    end

    test "rejects a malformed review QID" do
      oak_mapping = mapping("Quercus robur", "Stiel-Eiche", "Q165145")
      row = review("Quercus robur", "Stiel-Eiche", "Q0165145", "P105", "unused", "Art")

      assert ImportPlan.build(config([]), [oak_mapping], [row]) ==
               {:error,
                %ImportPreflightError{
                  issues: [
                    %{
                      code: :invalid_qid,
                      source: {:review, 2},
                      baumart_bo: "Quercus robur",
                      qid: "Q0165145"
                    }
                  ]
                }}
    end

    test "rejects an attribute name changed since the review export" do
      oak_mapping = mapping("Quercus robur", "Stiel-Eiche", "Q165145")

      row =
        review(
          "Quercus robur",
          "Stiel-Eiche",
          "Q165145",
          "P105",
          "alter_name",
          "Art"
        )

      assert ImportPlan.build(config(P105: entry("neuer_name")), [oak_mapping], [row]) ==
               {:error,
                %ImportPreflightError{
                  issues: [
                    %{
                      code: :config_review_attribute_mismatch,
                      source: {:review, 2},
                      property_id: "P105",
                      config_attribute_name: "neuer_name",
                      review_attribute_name: "alter_name"
                    }
                  ]
                }}
    end

    test "rejects two properties resolving to the same database attribute key" do
      oak_mapping = mapping("Quercus robur", "Stiel-Eiche", "Q165145")
      first = entry("taxonomie")
      second = entry("taxonomie")

      rows = [
        review("Quercus robur", "Stiel-Eiche", "Q165145", "P105", "taxonomie", "Art"),
        review("Quercus robur", "Stiel-Eiche", "Q165145", "P31", "taxonomie", "Taxon")
      ]

      assert ImportPlan.build(config(P105: first, P31: second), [oak_mapping], rows) ==
               {:error,
                %ImportPreflightError{
                  issues: [
                    %{
                      code: :duplicate_attribute_key,
                      attribute_name: "taxonomie",
                      property_ids: ["P105", "P31"]
                    }
                  ]
                }}
    end

    test "deduplicates identical values and records every skip reason" do
      oak_mapping = mapping("Quercus robur", "Stiel-Eiche", "Q165145")
      property = entry("taxonomischer_rang")
      skipped_property = %{entry("ignored") | import: :skip}
      unnamed_property = entry(nil, description: "")

      value =
        review(
          "Quercus robur",
          "Stiel-Eiche",
          "Q165145",
          "P105",
          "taxonomischer_rang",
          "Art"
        )

      rows = [
        value,
        value,
        review("Quercus robur", "Stiel-Eiche", "Q165145", "P999", "ignored", "x"),
        review("Quercus robur", "Stiel-Eiche", "Q165145", "P998", "", "x"),
        review(
          "Fagus sylvatica",
          "Rotbuche",
          "Q146149",
          "P105",
          "taxonomischer_rang",
          "Art"
        )
      ]

      assert ImportPlan.build(
               config(P105: property, P999: skipped_property, P998: unnamed_property),
               [oak_mapping],
               rows
             ) ==
               {:ok,
                %ImportPlan{
                  targets: [target(oak_mapping, 2)],
                  attribute_defs: [
                    %{
                      property_id: "P105",
                      attribute_name: "taxonomischer_rang",
                      entry: property,
                      type: "string"
                    }
                  ],
                  value_rows: [value],
                  skips: [
                    %{
                      reason: :duplicate_value,
                      line: 3,
                      baumart_bo: "Quercus robur",
                      property_id: "P105"
                    },
                    %{
                      reason: :property_not_importable,
                      line: 4,
                      baumart_bo: "Quercus robur",
                      property_id: "P999"
                    },
                    %{
                      reason: :missing_attribute_name,
                      line: 5,
                      baumart_bo: "Quercus robur",
                      property_id: "P998"
                    },
                    %{
                      reason: :missing_mapping,
                      line: 6,
                      baumart_bo: "Fagus sylvatica",
                      property_id: "P105"
                    }
                  ],
                  warnings: [%{code: :missing_mapping, baumart_bo: "Fagus sylvatica"}],
                  summary: %{tree_types: 1, attributes: 1, values: 1, skipped_values: 4}
                }}
    end

    test "rejects a repeated mapping identity, even with a diverging German name" do
      mapping_rows = [
        mapping("Quercus robur", "Stiel-Eiche", "Q165145"),
        mapping("Quercus robur", "Stiel-Eiche (beschädigt)", "Q165145")
      ]

      assert ImportPlan.build(config([]), mapping_rows, []) ==
               {:error,
                %ImportPreflightError{
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

    test "joins review and mapping through the canonical name" do
      fir_mapping = mapping("Abies species", "Tanne", "Q25243")
      property = entry("taxonomischer_rang")
      row = review("Abies  species", "Tanne", "Q25243", "P105", "taxonomischer_rang", "Gattung")

      assert {:ok, plan} = ImportPlan.build(config(P105: property), [fir_mapping], [row])

      assert plan.value_rows == [row]
      assert plan.skips == []
      assert plan.targets == [target(fir_mapping, 2)]
    end

    test "deduplicates values whose botanical names differ only in spelling" do
      oak_mapping = mapping("Quercus robur", "Stiel-Eiche", "Q165145")
      property = entry("taxonomischer_rang")

      row = review("Quercus robur", "Stiel-Eiche", "Q165145", "P105", "taxonomischer_rang", "Art")
      respelled = %{row | baumart_bo: "Quercus  robur"}

      assert {:ok, plan} =
               ImportPlan.build(config(P105: property), [oak_mapping], [row, respelled])

      assert plan.value_rows == [row]

      assert plan.skips == [
               %{
                 reason: :duplicate_value,
                 line: 3,
                 baumart_bo: "Quercus  robur",
                 property_id: "P105"
               }
             ]
    end

    test "records unknown datatype fallbacks in the plan" do
      oak_mapping = mapping("Quercus robur", "Stiel-Eiche", "Q165145")
      property = entry("zeitpunkt", type: "Time")
      row = review("Quercus robur", "Stiel-Eiche", "Q165145", "P574", "zeitpunkt", "2020")

      assert {:ok, plan} = ImportPlan.build(config(P574: property), [oak_mapping], [row])

      assert plan.warnings == [
               %{code: :unknown_datatype, property_id: "P574", datatype: "Time"}
             ]
    end
  end

  describe "details/1" do
    test "projects deterministic dry-run details from the plan" do
      plan = %ImportPlan{
        targets: [
          target(mapping("Tilia cordata", "Winter-Linde", "Q158746"), 2),
          target(mapping("Acer campestre", "Feld-Ahorn", "Q158785"), 3)
        ],
        attribute_defs: [
          %{property_id: "P225", attribute_name: "wissenschaftlicher_name", type: "string"},
          %{property_id: "P105", attribute_name: "taxonomischer_rang", type: "string"}
        ],
        value_rows: [
          %{baumart_bo: "Acer campestre", property_id: "P225"},
          %{baumart_bo: "Acer campestre", property_id: "P225"},
          %{baumart_bo: "Acer campestre", property_id: "P105"}
        ],
        skips: [
          %{baumart_bo: "Acer campestre", reason: :duplicate_value},
          %{baumart_bo: "Tilia cordata", reason: :property_not_importable}
        ],
        warnings: [
          %{code: :duplicate_mapping},
          %{code: :duplicate_mapping},
          %{code: :unknown_datatype}
        ],
        summary: %{}
      }

      assert ImportPlan.details(plan) == %{
               species: [
                 %{
                   name_botanic: "Acer campestre",
                   wikidata_id: "Q158785",
                   value_count: 3,
                   skips: %{duplicate_value: 1}
                 },
                 %{
                   name_botanic: "Tilia cordata",
                   wikidata_id: "Q158746",
                   value_count: 0,
                   skips: %{property_not_importable: 1}
                 }
               ],
               attributes: [
                 %{
                   property_id: "P105",
                   attribute_name: "taxonomischer_rang",
                   type: "string",
                   value_count: 1
                 },
                 %{
                   property_id: "P225",
                   attribute_name: "wissenschaftlicher_name",
                   type: "string",
                   value_count: 2
                 }
               ],
               warnings: %{duplicate_mapping: 2, unknown_datatype: 1},
               skips: %{duplicate_value: 1, property_not_importable: 1}
             }
    end
  end
end
