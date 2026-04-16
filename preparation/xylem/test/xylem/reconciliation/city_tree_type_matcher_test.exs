defmodule Xylem.Reconciliation.CityTreeTypeMatcherTest do
  use ExUnit.Case

  alias Xylem.Reconciliation.CityTreeTypeMatcher

  @citree_entries [
    %{baumart_bo: "Quercus robur", baumart_de: "Stiel-Eiche", wikidata_id: "Q165145"},
    %{baumart_bo: "Acer platanoides", baumart_de: "Spitz-Ahorn", wikidata_id: "Q26745"},
    %{
      baumart_bo: "Acer platanoides 'Globosum'",
      baumart_de: "Kugelahorn",
      wikidata_id: "Q9577526"
    },
    %{baumart_bo: "Tilia × europaea", baumart_de: "Holländische Linde", wikidata_id: "Q163760"},
    %{
      baumart_bo: "Amelanchier × lamarckii",
      baumart_de: "Kupfer-Felsenbirne",
      wikidata_id: "Q161702"
    },
    %{baumart_bo: "Acer", baumart_de: "Ahorn", wikidata_id: "Q42292"},
    %{
      baumart_bo: "Robinia pseudoacacia 'Semperflorens'",
      baumart_de: "Robinie",
      wikidata_id: "Q130467211"
    },
    %{
      baumart_bo: "Gleditsia triacanthos 'Skyline'",
      baumart_de: "Gleditschie",
      wikidata_id: "Q131573892"
    },
    %{
      baumart_bo: "Prunus domestica subsp. syriaca",
      baumart_de: "Mirabelle",
      wikidata_id: "Q149741"
    },
    %{baumart_bo: "Picea glauca", baumart_de: "Kanadische Fichte", wikidata_id: "Q128116"},
    %{baumart_bo: "Sorbus intermedia", baumart_de: "Schwedische Mehlbeere", wikidata_id: "Q27980"}
  ]

  describe "run/3" do
    test "Level 1: exact match" do
      city = [%{tree_type_botanic: "Quercus robur", wikidata_id: ""}]
      %{matches: [match], unmatched: []} = CityTreeTypeMatcher.run(city, @citree_entries)

      assert match.level == :exact
      assert match.wikidata_id == "Q165145"
    end

    test "Level 2: normalized match (case, whitespace, quotes)" do
      city = [
        %{tree_type_botanic: "Robinia Pseudoacacia `Semperflorens`", wikidata_id: ""}
      ]

      %{matches: [match], unmatched: []} = CityTreeTypeMatcher.run(city, @citree_entries)

      assert match.level == :normalized
      assert match.wikidata_id == "Q130467211"
    end

    test "Level 2: normalized match (ssp. → subsp.)" do
      city = [%{tree_type_botanic: "Prunus domestica ssp. Syriaca", wikidata_id: ""}]
      %{matches: [match], unmatched: []} = CityTreeTypeMatcher.run(city, @citree_entries)

      assert match.level == :normalized
      assert match.wikidata_id == "Q149741"
    end

    test "Level 3: hybrid-agnostic match (x → ×)" do
      city = [%{tree_type_botanic: "Tilia x euchlora", wikidata_id: ""}]

      citree = [
        %{baumart_bo: "Tilia × euchlora", baumart_de: "Krim-Linde", wikidata_id: "Q159657"}
      ]

      %{matches: [match], unmatched: []} = CityTreeTypeMatcher.run(city, citree)

      assert match.level == :hybrid_agnostic
      assert match.wikidata_id == "Q159657"
    end

    test "Level 3: hybrid-agnostic match (missing hybrid marker)" do
      city = [%{tree_type_botanic: "Amelanchier lamarckii", wikidata_id: ""}]
      %{matches: [match], unmatched: []} = CityTreeTypeMatcher.run(city, @citree_entries)

      assert match.level == :hybrid_agnostic
      assert match.wikidata_id == "Q161702"
    end

    test "Level 4: cultivar to species match" do
      city = [%{tree_type_botanic: "Acer platanoides 'Columnaris'", wikidata_id: ""}]
      %{matches: [match], unmatched: []} = CityTreeTypeMatcher.run(city, @citree_entries)

      assert match.level == :cultivar_to_species
      assert match.wikidata_id == "Q26745"
    end

    test "Level 4: prefers exact cultivar match over species fallback" do
      city = [%{tree_type_botanic: "Acer platanoides 'Globosum'", wikidata_id: ""}]
      %{matches: [match], unmatched: []} = CityTreeTypeMatcher.run(city, @citree_entries)

      assert match.level == :exact
      assert match.wikidata_id == "Q9577526"
    end

    test "Level 5: species to genus match" do
      city = [%{tree_type_botanic: "Acer  species", wikidata_id: ""}]
      %{matches: [match], unmatched: []} = CityTreeTypeMatcher.run(city, @citree_entries)

      assert match.level == :species_to_genus
      assert match.wikidata_id == "Q42292"
    end

    test "Level 6: synonym match" do
      city = [%{tree_type_botanic: "Picea glauka", wikidata_id: ""}]
      synonyms = [%{city_name: "Picea glauka", citree_name: "Picea glauca"}]

      %{matches: [match], unmatched: []} =
        CityTreeTypeMatcher.run(city, @citree_entries, synonyms: synonyms)

      assert match.level == :synonym
      assert match.wikidata_id == "Q128116"
    end

    test "Level 6: synonym match with cultivar stripping" do
      city = [%{tree_type_botanic: "Crataegus oxyacantha 'Paul's Scarlet'", wikidata_id: ""}]

      citree = [
        %{
          baumart_bo: "Crataegus laevigata",
          baumart_de: "Zweigriffeliger Weißdorn",
          wikidata_id: "Q159553"
        }
      ]

      synonyms = [%{city_name: "Crataegus oxyacantha", citree_name: "Crataegus laevigata"}]

      %{matches: [match], unmatched: []} =
        CityTreeTypeMatcher.run(city, citree, synonyms: synonyms)

      assert match.level == :synonym
      assert match.wikidata_id == "Q159553"
    end

    test "German name matched via synonym table" do
      city = [%{tree_type_botanic: "Schwedische Mehlbeere", wikidata_id: ""}]
      synonyms = [%{city_name: "Schwedische Mehlbeere", citree_name: "Sorbus intermedia"}]

      %{matches: [match], unmatched: []} =
        CityTreeTypeMatcher.run(city, @citree_entries, synonyms: synonyms)

      assert match.level == :synonym
      assert match.wikidata_id == "Q27980"
    end

    test "non-tree entries are skipped" do
      city = [%{tree_type_botanic: "Nacherfassung", wikidata_id: ""}]
      %{matches: [], unmatched: [entry]} = CityTreeTypeMatcher.run(city, @citree_entries)
      assert entry.reason == :non_tree
    end

    test "preserves existing wikidata_id" do
      city = [%{tree_type_botanic: "Some Tree", wikidata_id: "Q999"}]
      %{matches: [match], unmatched: []} = CityTreeTypeMatcher.run(city, @citree_entries)

      assert match.wikidata_id == "Q999"
      assert match.level == :existing
    end

    test "Level 7: manual Wikidata ID assignment" do
      city = [%{tree_type_botanic: "Staphylea colchica", wikidata_id: ""}]
      manual = [%{tree_type_botanic: "Staphylea colchica", wikidata_id: "Q2671147"}]

      %{matches: [match], unmatched: []} =
        CityTreeTypeMatcher.run(city, @citree_entries, manual_ids: manual)

      assert match.level == :manual
      assert match.wikidata_id == "Q2671147"
      assert match.citree_name == nil
    end

    test "unmatched entries reported" do
      city = [%{tree_type_botanic: "Nothofagus antarctica", wikidata_id: ""}]
      %{matches: [], unmatched: [entry]} = CityTreeTypeMatcher.run(city, @citree_entries)
      assert entry.reason == :no_match
    end
  end
end
