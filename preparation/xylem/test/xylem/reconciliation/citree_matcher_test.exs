defmodule Xylem.Reconciliation.CitreeMatcherTest do
  use ExUnit.Case

  alias Xylem.Reconciliation.CitreeMatcher

  @baumbie_entries [
    %{baumart_bo: "Acer buergerianum", baumart_de: "Burgen Ahorn", wikidata_id: "Q941891"},
    %{baumart_bo: "Acer campestre", baumart_de: "Feld-Ahorn", wikidata_id: "Q158785"},
    %{baumart_bo: "Acer platanoides", baumart_de: "Spitz-Ahorn", wikidata_id: "Q26745"},
    %{baumart_bo: "Acer × zoeschense", baumart_de: "Zoeschener Ahorn", wikidata_id: "Q4673185"},
    %{
      baumart_bo: "Acer cappadocicum",
      baumart_de: "Kolchischer-Ahorn",
      wikidata_id: "Q766133"
    },
    %{
      baumart_bo: "Acer velutinum",
      baumart_de: "Samtblatt-Ahorn",
      wikidata_id: "Q4673123"
    }
  ]

  describe "run/3" do
    test "Level 1: exact match (without author)" do
      citree = [%{name_botanic: "Acer platanoides", strain: "Allgemein"}]

      %{matches: [match], unmatched: []} = CitreeMatcher.run(citree, @baumbie_entries)

      assert match.level == :exact
      assert match.wikidata_id == "Q26745"
      assert match.baumart_bo == "Acer platanoides"
      assert match.strain == "Allgemein"
    end

    test "Level 2: author-stripped match" do
      citree = [%{name_botanic: "Acer buergerianum Miq.", strain: "Allgemein"}]

      %{matches: [match], unmatched: []} = CitreeMatcher.run(citree, @baumbie_entries)

      assert match.level == :author_stripped
      assert match.wikidata_id == "Q941891"
      assert match.baumart_bo == "Acer buergerianum"
    end

    test "Level 4: hybrid-agnostic match (after author stripping)" do
      citree = [%{name_botanic: "Acer x zoeschense Pax", strain: "Allgemein"}]

      %{matches: [match], unmatched: []} = CitreeMatcher.run(citree, @baumbie_entries)

      assert match.level == :hybrid_agnostic
      assert match.wikidata_id == "Q4673185"
    end

    test "Level 5: infraspecific-stripped match" do
      citree = [
        %{
          name_botanic: "Acer cappadocicum Gleditsch subsp. lobelii (Ten.) de Jong",
          strain: "Allgemein"
        }
      ]

      %{matches: [match], unmatched: []} = CitreeMatcher.run(citree, @baumbie_entries)

      assert match.level == :infraspecific_stripped
      assert match.wikidata_id == "Q766133"
    end

    test "Level 5: infraspecific-stripped (subsp. with same epithet)" do
      citree = [
        %{name_botanic: "Acer campestre L. subsp. campestre", strain: "Allgemein"}
      ]

      %{matches: [match], unmatched: []} = CitreeMatcher.run(citree, @baumbie_entries)

      assert match.level == :infraspecific_stripped
      assert match.wikidata_id == "Q158785"
    end

    test "Level 6: synonym match" do
      citree = [%{name_botanic: "Acer obscurum X. Y.", strain: "Allgemein"}]
      synonyms = [%{name_botanic: "Acer obscurum", baumart_bo: "Acer platanoides"}]

      %{matches: [match], unmatched: []} =
        CitreeMatcher.run(citree, @baumbie_entries, synonyms: synonyms)

      assert match.level == :synonym
      assert match.wikidata_id == "Q26745"
      assert match.baumart_bo == "Acer platanoides"
    end

    test "Level 7: parenthetical synonym (abbreviated genus)" do
      citree = [
        %{
          name_botanic: "Crataegus x persimilis Sarg. 'MacLeod' (C.x prunifolia Pers.)",
          strain: "Allgemein"
        }
      ]

      baumbie = [
        %{
          baumart_bo: "Crataegus x prunifolia",
          baumart_de: "Pflaumenblättriger Weißdorn",
          wikidata_id: "Q15536927"
        }
      ]

      %{matches: [match], unmatched: []} = CitreeMatcher.run(citree, baumbie)

      assert match.level == :parenthetical_synonym
      assert match.wikidata_id == "Q15536927"
      assert match.baumart_bo == "Crataegus x prunifolia"
    end

    test "Level 7: parenthetical synonym (full genus)" do
      citree = [
        %{
          name_botanic: "Platanus x hispanica Münchh.(Platanus x acerifolia (Ait.))",
          strain: "Allgemein"
        }
      ]

      baumbie = [
        %{
          baumart_bo: "Platanus x acerifolia",
          baumart_de: "Gewöhnliche Platane",
          wikidata_id: "Q24853030"
        }
      ]

      %{matches: [match], unmatched: []} = CitreeMatcher.run(citree, baumbie)

      assert match.level == :parenthetical_synonym
      assert match.wikidata_id == "Q24853030"
      assert match.baumart_bo == "Platanus x acerifolia"
    end

    test "Level 7: ignores non-binomial parentheticals (author-only)" do
      citree = [
        %{name_botanic: "Acer pseudoplatanus L.", strain: "Allgemein"}
      ]

      # No match in baumbie, no parenthetical synonym available
      %{matches: [], unmatched: [_]} = CitreeMatcher.run(citree, [])
    end

    test "Level 8: manual Wikidata ID assignment" do
      citree = [%{name_botanic: "Acer obscurum L.", strain: "Allgemein"}]
      manual = [%{name_botanic: "Acer obscurum L.", wikidata_id: "Q999"}]

      %{matches: [match], unmatched: []} =
        CitreeMatcher.run(citree, @baumbie_entries, manual_ids: manual)

      assert match.level == :manual
      assert match.wikidata_id == "Q999"
      assert match.baumart_bo == nil
    end

    test "preserves existing wikidata_id" do
      citree = [
        %{name_botanic: "Some Tree", strain: "X", wikidata_id: "Q42", baumart_bo: "preset"}
      ]

      %{matches: [match], unmatched: []} = CitreeMatcher.run(citree, @baumbie_entries)

      assert match.wikidata_id == "Q42"
      assert match.level == :existing
    end

    test "unmatched entries reported with strain" do
      citree = [%{name_botanic: "Nothofagus antarctica", strain: "Allgemein"}]
      %{matches: [], unmatched: [entry]} = CitreeMatcher.run(citree, @baumbie_entries)
      assert entry.reason == :no_match
      assert entry.strain == "Allgemein"
    end

    test "strain preserved across all match levels" do
      citree = [
        %{name_botanic: "Acer platanoides L.", strain: "Apollo"},
        %{name_botanic: "Acer platanoides L.", strain: "Columnare"}
      ]

      %{matches: matches, unmatched: []} = CitreeMatcher.run(citree, @baumbie_entries)

      assert length(matches) == 2
      assert Enum.map(matches, & &1.strain) == ["Apollo", "Columnare"]
      assert Enum.all?(matches, &(&1.wikidata_id == "Q26745"))
    end
  end
end