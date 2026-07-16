defmodule Xylem.BaumBie.Importer.ImportPlanTest do
  use ExUnit.Case, async: true

  alias Xylem.BaumBie.Importer.ImportPlan
  alias Xylem.ImportPreflightError
  alias Xylem.Wikidata.PropertyConfig

  defp species(name_botanic, name) do
    %{name_botanic: name_botanic, name: name, name_trivial: name}
  end

  defp mapping(name_botanic, name, qid) do
    %{baumart_bo: name_botanic, baumart_de: name, wikidata_id: qid}
  end

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

  describe "build/4" do
    test "builds the complete import decision once" do
      oak = species("Quercus robur", "Stiel-Eiche")
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

      assert ImportPlan.build(config(P105: property), [oak_mapping], [row], [oak]) ==
               {:ok,
                %ImportPlan{
                  species: [oak],
                  wikidata_by_bo: %{"Quercus robur" => "Q165145"},
                  attribute_defs: [
                    %{
                      property_id: "P105",
                      attribute_name: "taxonomischer_rang",
                      entry: property,
                      type: "string"
                    }
                  ],
                  value_rows: [row],
                  unmatched_cadastre: [],
                  unmatched_mapping: [],
                  skips: [],
                  warnings: [],
                  summary: %{
                    tree_types_derived: 1,
                    matched: 1,
                    unmatched_cadastre: 0,
                    unmatched_mapping: 0,
                    attributes: 1,
                    values: 1,
                    skipped_values: 0
                  }
                }}
    end

    test "allows multiple tree types to share a QID" do
      species_list = [
        species("Acer platanoides", "Spitz-Ahorn"),
        species("Acer platanoides 'Columnaris'", "Säulen-Ahorn")
      ]

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

      assert ImportPlan.build(
               config(P225: property),
               mapping_rows,
               review_rows,
               species_list
             ) ==
               {:ok,
                %ImportPlan{
                  species: species_list,
                  wikidata_by_bo: %{
                    "Acer platanoides" => "Q26745",
                    "Acer platanoides 'Columnaris'" => "Q26745"
                  },
                  attribute_defs: [
                    %{
                      property_id: "P225",
                      attribute_name: "wissenschaftlicher_name",
                      entry: property,
                      type: "string"
                    }
                  ],
                  value_rows: review_rows,
                  unmatched_cadastre: [],
                  unmatched_mapping: [],
                  skips: [],
                  warnings: [],
                  summary: %{
                    tree_types_derived: 2,
                    matched: 2,
                    unmatched_cadastre: 0,
                    unmatched_mapping: 0,
                    attributes: 1,
                    values: 2,
                    skipped_values: 0
                  }
                }}
    end

    test "rejects malformed QIDs" do
      maple = species("Acer campestre", "Feld-Ahorn")
      invalid_mapping = mapping("Acer campestre", "Feld-Ahorn", "q158785")

      assert ImportPlan.build(config([]), [invalid_mapping], [], [maple]) ==
               {:error,
                %ImportPreflightError{
                  issues: [
                    %{
                      code: :invalid_qid,
                      source: :mapping,
                      baumart_bo: "Acer campestre",
                      qid: "q158785"
                    }
                  ]
                }}
    end

    test "treats an empty mapping QID as an unmapped cadastre species" do
      stock = species("Waldartiger Bestand", "Waldartiger Bestand")
      empty_mapping = mapping("Waldartiger Bestand", "Waldartiger Bestand", "")

      assert ImportPlan.build(config([]), [empty_mapping], [], [stock]) ==
               {:ok,
                %ImportPlan{
                  species: [stock],
                  wikidata_by_bo: %{},
                  attribute_defs: [],
                  value_rows: [],
                  unmatched_cadastre: [stock],
                  unmatched_mapping: [],
                  skips: [],
                  warnings: [
                    %{code: :blank_mapping_qid, baumart_bo: "Waldartiger Bestand"}
                  ],
                  summary: %{
                    tree_types_derived: 1,
                    matched: 0,
                    unmatched_cadastre: 1,
                    unmatched_mapping: 0,
                    attributes: 0,
                    values: 0,
                    skipped_values: 0
                  }
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

      assert ImportPlan.build(config(P105: property), [], [row], []) ==
               {:ok,
                %ImportPlan{
                  species: [],
                  wikidata_by_bo: %{},
                  attribute_defs: [
                    %{
                      property_id: "P105",
                      attribute_name: "taxonomischer_rang",
                      entry: property,
                      type: "string"
                    }
                  ],
                  value_rows: [],
                  unmatched_cadastre: [],
                  unmatched_mapping: [],
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
                  summary: %{
                    tree_types_derived: 0,
                    matched: 0,
                    unmatched_cadastre: 0,
                    unmatched_mapping: 0,
                    attributes: 1,
                    values: 0,
                    skipped_values: 1
                  }
                }}
    end

    test "rejects conflicting mapping QIDs for one botanical name" do
      oak = species("Quercus robur", "Stiel-Eiche")

      mapping_rows = [
        mapping("Quercus robur", "Stiel-Eiche", "Q165145"),
        mapping("Quercus robur", "Stiel-Eiche", "Q42")
      ]

      assert ImportPlan.build(config([]), mapping_rows, [], [oak]) ==
               {:error,
                %ImportPreflightError{
                  issues: [
                    %{
                      code: :conflicting_mapping_qids,
                      baumart_bo: "Quercus robur",
                      qids: ["Q165145", "Q42"]
                    }
                  ]
                }}
    end

    test "rejects a review QID that differs from the mapping" do
      oak = species("Quercus robur", "Stiel-Eiche")
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

      assert ImportPlan.build(
               config(P105: entry("taxonomischer_rang")),
               [oak_mapping],
               [row, row],
               [oak]
             ) ==
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
      oak = species("Quercus robur", "Stiel-Eiche")
      oak_mapping = mapping("Quercus robur", "Stiel-Eiche", "Q165145")
      row = review("Quercus robur", "Stiel-Eiche", "Q0165145", "P105", "unused", "Art")

      assert ImportPlan.build(config([]), [oak_mapping], [row], [oak]) ==
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
      oak = species("Quercus robur", "Stiel-Eiche")
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

      assert ImportPlan.build(config(P105: entry("neuer_name")), [oak_mapping], [row], [oak]) ==
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
      oak = species("Quercus robur", "Stiel-Eiche")
      oak_mapping = mapping("Quercus robur", "Stiel-Eiche", "Q165145")
      first = entry("taxonomie")
      second = entry("taxonomie")

      rows = [
        review("Quercus robur", "Stiel-Eiche", "Q165145", "P105", "taxonomie", "Art"),
        review("Quercus robur", "Stiel-Eiche", "Q165145", "P31", "taxonomie", "Taxon")
      ]

      assert ImportPlan.build(
               config(P105: first, P31: second),
               [oak_mapping],
               rows,
               [oak]
             ) ==
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
      oak = species("Quercus robur", "Stiel-Eiche")

      mapping_rows = [
        mapping("Quercus robur", "Stiel-Eiche", "Q165145"),
        mapping("Fagus sylvatica", "Rotbuche", "Q146149")
      ]

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
               mapping_rows,
               rows,
               [oak]
             ) ==
               {:ok,
                %ImportPlan{
                  species: [oak],
                  wikidata_by_bo: %{"Quercus robur" => "Q165145"},
                  attribute_defs: [
                    %{
                      property_id: "P105",
                      attribute_name: "taxonomischer_rang",
                      entry: property,
                      type: "string"
                    }
                  ],
                  value_rows: [value],
                  unmatched_cadastre: [],
                  unmatched_mapping: [Enum.at(mapping_rows, 1)],
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
                      reason: :no_cadastre_tree_type,
                      line: 6,
                      baumart_bo: "Fagus sylvatica",
                      property_id: "P105"
                    }
                  ],
                  warnings: [],
                  summary: %{
                    tree_types_derived: 1,
                    matched: 1,
                    unmatched_cadastre: 0,
                    unmatched_mapping: 1,
                    attributes: 1,
                    values: 1,
                    skipped_values: 4
                  }
                }}
    end

    test "deduplicates repeated mapping identities with a warning" do
      oak = species("Quercus robur", "Stiel-Eiche")

      mapping_rows = [
        mapping("Quercus robur", "Stiel-Eiche", "Q165145"),
        mapping("Quercus robur", "Stiel-Eiche (beschädigt)", "Q165145")
      ]

      assert ImportPlan.build(config([]), mapping_rows, [], [oak]) ==
               {:ok,
                %ImportPlan{
                  species: [oak],
                  wikidata_by_bo: %{"Quercus robur" => "Q165145"},
                  attribute_defs: [],
                  value_rows: [],
                  unmatched_cadastre: [],
                  unmatched_mapping: [],
                  skips: [],
                  warnings: [
                    %{
                      code: :duplicate_mapping,
                      baumart_bo: "Quercus robur",
                      wikidata_id: "Q165145"
                    }
                  ],
                  summary: %{
                    tree_types_derived: 1,
                    matched: 1,
                    unmatched_cadastre: 0,
                    unmatched_mapping: 0,
                    attributes: 0,
                    values: 0,
                    skipped_values: 0
                  }
                }}
    end

    test "records unknown datatype fallbacks in the plan" do
      oak = species("Quercus robur", "Stiel-Eiche")
      oak_mapping = mapping("Quercus robur", "Stiel-Eiche", "Q165145")
      property = entry("zeitpunkt", type: "Time")
      row = review("Quercus robur", "Stiel-Eiche", "Q165145", "P574", "zeitpunkt", "2020")

      assert {:ok, plan} =
               ImportPlan.build(config(P574: property), [oak_mapping], [row], [oak])

      assert plan.warnings == [
               %{code: :unknown_datatype, property_id: "P574", datatype: "Time"}
             ]
    end
  end

  describe "details/1" do
    test "projects deterministic dry-run details from the plan" do
      plan = %ImportPlan{
        species: [
          species("Tilia cordata", "Winter-Linde"),
          species("Acer campestre", "Feld-Ahorn")
        ],
        wikidata_by_bo: %{"Acer campestre" => "Q158785"},
        attribute_defs: [
          %{property_id: "P225", attribute_name: "wissenschaftlicher_name", type: "string"},
          %{property_id: "P105", attribute_name: "taxonomischer_rang", type: "string"}
        ],
        value_rows: [
          %{baumart_bo: "Acer campestre", property_id: "P225"},
          %{baumart_bo: "Acer campestre", property_id: "P225"},
          %{baumart_bo: "Acer campestre", property_id: "P105"}
        ],
        unmatched_cadastre: [],
        unmatched_mapping: [],
        skips: [
          %{baumart_bo: "Acer campestre", reason: :duplicate_value},
          %{baumart_bo: "Tilia cordata", reason: :missing_mapping}
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
                   status: :matched,
                   wikidata_id: "Q158785",
                   value_count: 3,
                   skips: %{duplicate_value: 1}
                 },
                 %{
                   name_botanic: "Tilia cordata",
                   status: :unmatched,
                   wikidata_id: nil,
                   value_count: 0,
                   skips: %{missing_mapping: 1}
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
               skips: %{duplicate_value: 1, missing_mapping: 1}
             }
    end
  end
end
