defmodule Xylem.Reconciliation.CadastreDriftTest do
  use ExUnit.Case, async: true

  alias Xylem.ImportInputError
  alias Xylem.Reconciliation.CadastreDrift

  defp feature(bo, de) do
    %{"properties" => %{"Baumart_bo" => bo, "Baumart_de" => de}}
  end

  defp species(bo, de, tree_count) do
    %{baumart_bo: bo, baumart_de: de, tree_count: tree_count}
  end

  defp mapping(bo, de, qid) do
    %{baumart_bo: bo, baumart_de: de, wikidata_id: qid}
  end

  describe "distinct_species/1" do
    test "counts the trees per species and sorts by botanical name" do
      features = [
        feature("Quercus robur", "Stiel-Eiche"),
        feature("Acer campestre", "Feld-Ahorn"),
        feature("Quercus robur", "Stiel-Eiche")
      ]

      assert CadastreDrift.distinct_species(features) == [
               species("Acer campestre", "Feld-Ahorn", 1),
               species("Quercus robur", "Stiel-Eiche", 2)
             ]
    end

    test "skips features without a botanical name" do
      features = [
        feature("", "Unbekannt"),
        feature(nil, "Unbekannt"),
        %{"properties" => %{}},
        %{},
        feature("Tilia cordata", "Winter-Linde")
      ]

      assert CadastreDrift.distinct_species(features) == [
               species("Tilia cordata", "Winter-Linde", 1)
             ]
    end

    test "merges spellings of one species and collapses whitespace" do
      features = [
        feature("Crataegus  species", "Weißdorn"),
        feature("Crataegus species", "Weißdorn"),
        feature("Acer platanoides `Globosum`", "Kugel-Ahorn"),
        feature("Acer platanoides 'Globosum'", "Kugel-Ahorn")
      ]

      assert CadastreDrift.distinct_species(features) == [
               species("Acer platanoides `Globosum`", "Kugel-Ahorn", 2),
               species("Crataegus species", "Weißdorn", 2)
             ]
    end
  end

  describe "compare/2" do
    test "reports the differences in both directions" do
      oak = species("Quercus robur", "Stiel-Eiche", 3)
      birch = species("Betula utilis", "Himalaja-Birke", 1)
      oak_mapping = mapping("Quercus robur", "Stiel-Eiche", "Q165145")
      elm_mapping = mapping("Zelkova serrata", "Japanische Zelkove", "Q920344")

      assert CadastreDrift.compare([oak, birch], [oak_mapping, elm_mapping]) == %{
               missing_in_mapping: [birch],
               missing_in_cadastre: [elm_mapping]
             }
    end

    test "treats mapping rows with an empty QID as known" do
      stock = species("Waldartiger Bestand", "Waldartiger Bestand", 629)
      stock_mapping = mapping("Waldartiger Bestand", "Waldartiger Bestand", "")

      assert CadastreDrift.compare([stock], [stock_mapping]) == %{
               missing_in_mapping: [],
               missing_in_cadastre: []
             }
    end

    test "matches across whitespace and cultivar quote differences" do
      maple = species("Acer platanoides `Globosum`", "Kugel-Ahorn", 1)
      maple_mapping = mapping("Acer  platanoides 'Globosum'", "Kugel-Ahorn", "Q9577526")

      assert CadastreDrift.compare([maple], [maple_mapping]) == %{
               missing_in_mapping: [],
               missing_in_cadastre: []
             }
    end
  end

  describe "load_species/1" do
    @describetag :tmp_dir

    test "reads the distinct species of a GeoJSON file", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "trees.geojson")

      File.write!(
        path,
        Jason.encode!(%{"features" => [feature("Quercus robur", "Stiel-Eiche")]})
      )

      assert CadastreDrift.load_species(path) ==
               {:ok, [species("Quercus robur", "Stiel-Eiche", 1)]}
    end

    test "returns a structured error for a missing file", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "missing.geojson")

      assert CadastreDrift.load_species(path) ==
               {:error,
                %ImportInputError{
                  source: :tree_geojson,
                  path: path,
                  reason: :file_read,
                  details: :enoent,
                  line: nil
                }}
    end

    test "returns a structured error for invalid GeoJSON", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "invalid.geojson")
      File.write!(path, "{}")

      assert CadastreDrift.load_species(path) ==
               {:error,
                %ImportInputError{
                  source: :tree_geojson,
                  path: path,
                  reason: :invalid_geojson,
                  details: nil,
                  line: nil
                }}
    end
  end
end
