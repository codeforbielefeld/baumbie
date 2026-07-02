defmodule Xylem.Reconciliation.NormalizerTest do
  use ExUnit.Case

  alias Xylem.Reconciliation.Normalizer

  describe "normalize_quotes/1" do
    test "replaces modifier letter reversed comma" do
      assert Normalizer.normalize_quotes("ʽWredei'") == "'Wredei'"
    end

    test "replaces left/right single quotation marks" do
      assert Normalizer.normalize_quotes("\u2018Skyline\u2019") == "'Skyline'"
    end

    test "replaces backticks" do
      assert Normalizer.normalize_quotes("`Royalty`") == "'Royalty'"
    end

    test "handles mixed quote styles" do
      assert Normalizer.normalize_quotes("ʽPaul\u2019s Scarlet'") == "'Paul's Scarlet'"
    end
  end

  describe "normalize/1" do
    test "lowercases" do
      assert Normalizer.normalize("Acer Platanoides") == "acer platanoides"
    end

    test "collapses whitespace" do
      assert Normalizer.normalize("Acer  species") == "acer species"
    end

    test "normalizes quotes" do
      assert Normalizer.normalize("Malus `Royalty`") == "malus 'royalty'"
    end

    test "normalizes subspecies notation" do
      assert Normalizer.normalize("Prunus domestica ssp. Syriaca") ==
               "prunus domestica subsp. syriaca"
    end

    test "trims" do
      assert Normalizer.normalize("  Quercus robur  ") == "quercus robur"
    end
  end

  describe "remove_hybrid/1" do
    test "removes Unicode multiplication sign" do
      assert Normalizer.remove_hybrid("Acer × zoeschense") == "acer zoeschense"
    end

    test "removes ASCII x as hybrid marker" do
      assert Normalizer.remove_hybrid("Acer x zoeschense") == "acer zoeschense"
    end

    test "does not remove x within words" do
      assert Normalizer.remove_hybrid("Taxus baccata") == "taxus baccata"
    end

    test "handles × without trailing space" do
      assert Normalizer.remove_hybrid("Malus ×moerlandsii") == "malus moerlandsii"
    end
  end

  describe "strip_cultivar/1" do
    test "strips single-quoted cultivar" do
      assert Normalizer.strip_cultivar("Acer platanoides 'Globosum'") == "Acer platanoides"
    end

    test "strips backtick-quoted cultivar" do
      assert Normalizer.strip_cultivar("Malus `Royalty`") == "Malus"
    end

    test "strips Aggregat suffix" do
      assert Normalizer.strip_cultivar("Prunus avium Aggregat") == "Prunus avium"
    end

    test "strips f. infraspecific epithet" do
      assert Normalizer.strip_cultivar("Fagus sylvatica f. purpurea") == "Fagus sylvatica"
    end

    test "strips var. infraspecific epithet" do
      assert Normalizer.strip_cultivar("Acer pseudoplatanus var. purpurascens") ==
               "Acer pseudoplatanus"
    end

    test "leaves plain species name unchanged" do
      assert Normalizer.strip_cultivar("Quercus robur") == "Quercus robur"
    end
  end

  describe "strip_authors/1" do
    test "strips single author abbreviation" do
      assert Normalizer.strip_authors("Acer buergerianum Miq.") == "Acer buergerianum"
    end

    test "strips L. and keeps subsp." do
      assert Normalizer.strip_authors("Acer campestre L. subsp. campestre") ==
               "Acer campestre subsp. campestre"
    end

    test "strips parenthetical author plus following name" do
      assert Normalizer.strip_authors(
               "Acer cappadocicum Gleditsch subsp. lobelii (Ten.) de Jong"
             ) == "Acer cappadocicum subsp. lobelii"
    end

    test "strips author and keeps var." do
      assert Normalizer.strip_authors("Acer velutinum Boiss. var. velutinum") ==
               "Acer velutinum var. velutinum"
    end

    test "keeps hybrid marker ×" do
      assert Normalizer.strip_authors("Acer × zoeschense Pax") == "Acer × zoeschense"
    end

    test "leaves plain binomial unchanged" do
      assert Normalizer.strip_authors("Acer monspessulanum") == "Acer monspessulanum"
    end

    test "handles empty/short input" do
      assert Normalizer.strip_authors("Acer") == "Acer"
      assert Normalizer.strip_authors("") == ""
    end

    test "inserts missing space before parenthetical author" do
      assert Normalizer.strip_authors("Chamaecyparis lawsoniana(A.Murray) Parl.") ==
               "Chamaecyparis lawsoniana"
    end
  end

  describe "extract_top_level_parens/1" do
    test "extracts single parenthetical" do
      assert Normalizer.extract_top_level_parens("Foo (bar) baz") == ["bar"]
    end

    test "extracts multiple parentheticals" do
      assert Normalizer.extract_top_level_parens("Foo (bar) (qux)") == ["bar", "qux"]
    end

    test "preserves nested parentheses inside extracted content" do
      assert Normalizer.extract_top_level_parens("Foo (bar (nested)) baz") ==
               ["bar (nested)"]
    end

    test "handles citree-style synonym in parentheses" do
      assert Normalizer.extract_top_level_parens(
               "Crataegus x persimilis Sarg. 'MacLeod' (C.x prunifolia Pers.)"
             ) == ["C.x prunifolia Pers."]
    end

    test "handles nested author citations" do
      assert Normalizer.extract_top_level_parens(
               "Thuja orientalis L. (Platycladus orientalis (L.) Franco)"
             ) == ["Platycladus orientalis (L.) Franco"]
    end

    test "returns empty list when no parens" do
      assert Normalizer.extract_top_level_parens("Acer platanoides") == []
    end
  end
end
