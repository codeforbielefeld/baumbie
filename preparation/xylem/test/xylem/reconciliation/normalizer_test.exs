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
end
