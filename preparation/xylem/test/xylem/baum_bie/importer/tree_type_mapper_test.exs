defmodule Xylem.BaumBie.Importer.TreeTypeMapperTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias Xylem.BaumBie.Importer.TreeTypeMapper
  alias Xylem.ImportInputError

  defp feature(bo, de, ku \\ "") do
    %{"properties" => %{"Baumart_bo" => bo, "Baumart_de" => de, "Baumart_ku" => ku}}
  end

  describe "distinct_species/1" do
    test "deduplicates by botanical name, keeping first occurrence and ignoring short code" do
      features = [
        feature("Quercus robur", "Stiel-Eiche", "q r"),
        feature("Acer campestre", "Feld-Ahorn", "a c"),
        feature("Quercus robur", "Stiel-Eiche", "q r")
      ]

      assert TreeTypeMapper.distinct_species(features) == [
               %{name_botanic: "Quercus robur", name: "Stiel-Eiche", name_trivial: "Stiel-Eiche"},
               %{name_botanic: "Acer campestre", name: "Feld-Ahorn", name_trivial: "Feld-Ahorn"}
             ]
    end

    test "skips features without a botanical name" do
      features = [feature("", "Unbekannt"), feature("Tilia cordata", "Winter-Linde")]

      assert TreeTypeMapper.distinct_species(features) == [
               %{
                 name_botanic: "Tilia cordata",
                 name: "Winter-Linde",
                 name_trivial: "Winter-Linde"
               }
             ]
    end

    test "warns on conflicting German names and keeps the first" do
      features = [
        feature("Quercus robur", "Stiel-Eiche"),
        feature("Quercus robur", "Deutsche Eiche")
      ]

      result =
        capture_log(fn ->
          assert TreeTypeMapper.distinct_species(features) == [
                   %{
                     name_botanic: "Quercus robur",
                     name: "Stiel-Eiche",
                     name_trivial: "Stiel-Eiche"
                   }
                 ]
        end)

      assert result =~ "conflicting Baumart_de"
    end

    test "merges cadastre names that differ only in whitespace into one tree type" do
      features = [
        feature("Crataegus species", "Weißdorn"),
        feature("Crataegus  species", "Weißdorn")
      ]

      log =
        capture_log(fn ->
          assert TreeTypeMapper.distinct_species(features) == [
                   %{
                     name_botanic: "Crataegus species",
                     name: "Weißdorn",
                     name_trivial: "Weißdorn"
                   }
                 ]
        end)

      assert log =~ ~s(Merging cadastre species "Crataegus  species" into "Crataegus species")
    end

    test "collapses whitespace in the stored botanical name" do
      assert TreeTypeMapper.distinct_species([feature("Abies  species", "Tanne")]) == [
               %{name_botanic: "Abies species", name: "Tanne", name_trivial: "Tanne"}
             ]
    end

    test "does not report a merge when only one spelling occurs" do
      # Every occurrence is double-spaced: the name is normalized, not merged.
      features = List.duplicate(feature("Ulmus  species", "Ulme"), 3)

      log =
        capture_log(fn ->
          assert TreeTypeMapper.distinct_species(features) == [
                   %{name_botanic: "Ulmus species", name: "Ulme", name_trivial: "Ulme"}
                 ]
        end)

      refute log =~ "Merging cadastre species"
    end

    test "reports a merge once regardless of how many features share the name" do
      features =
        [feature("Crataegus species", "Weißdorn")] ++
          List.duplicate(feature("Crataegus  species", "Weißdorn"), 5)

      log =
        capture_log(fn ->
          assert TreeTypeMapper.distinct_species(features) == [
                   %{
                     name_botanic: "Crataegus species",
                     name: "Weißdorn",
                     name_trivial: "Weißdorn"
                   }
                 ]
        end)

      assert log |> String.split("Merging cadastre species") |> length() == 2
    end
  end

  describe "build_tree_type_row/2" do
    test "builds the owned tree type fields without CitTree metadata" do
      species = %{name_botanic: "Quercus robur", name: "Stiel-Eiche", name_trivial: "Stiel-Eiche"}

      assert TreeTypeMapper.build_tree_type_row(species, "Q165145") == %{
               "name" => "Stiel-Eiche",
               "name_trivial" => "Stiel-Eiche",
               "name_botanic" => "Quercus robur",
               "wikidata_id" => "Q165145"
             }
    end

    test "keeps wikidata_id explicit when the species has no mapping" do
      species = %{name_botanic: "Quercus robur", name: "Stiel-Eiche", name_trivial: "Stiel-Eiche"}

      assert TreeTypeMapper.build_tree_type_row(species, nil) == %{
               "name" => "Stiel-Eiche",
               "name_trivial" => "Stiel-Eiche",
               "name_botanic" => "Quercus robur",
               "wikidata_id" => nil
             }
    end
  end

  describe "match_wikidata_ids/2" do
    test "splits into matched, unmatched cadastre and unmatched mapping" do
      species = [
        %{name_botanic: "Quercus robur", name: "Stiel-Eiche", name_trivial: "Stiel-Eiche"},
        %{name_botanic: "Betula utilis", name: "Himalaja-Birke", name_trivial: "Himalaja-Birke"}
      ]

      mapping = [
        %{baumart_bo: "Quercus robur", baumart_de: "Stiel-Eiche", wikidata_id: "Q165145"},
        %{baumart_bo: "Fagus sylvatica", baumart_de: "Rotbuche", wikidata_id: "Q146127"}
      ]

      assert TreeTypeMapper.match_wikidata_ids(species, mapping) ==
               {[{Enum.at(species, 0), "Q165145"}], [Enum.at(species, 1)], [Enum.at(mapping, 1)]}
    end

    test "matches across whitespace and cultivar quote differences" do
      species = [
        %{name_botanic: "Abies  species", name: "Tanne", name_trivial: "Tanne"},
        %{
          name_botanic: "Acer platanoides `Globosum`",
          name: "Kugel-Ahorn",
          name_trivial: "Kugel-Ahorn"
        }
      ]

      mapping = [
        %{baumart_bo: "Abies species", baumart_de: "Tanne", wikidata_id: "Q25243"},
        %{
          baumart_bo: "Acer platanoides 'Globosum'",
          baumart_de: "Kugel-Ahorn",
          wikidata_id: "Q9577526"
        }
      ]

      assert TreeTypeMapper.match_wikidata_ids(species, mapping) ==
               {[
                  {Enum.at(species, 0), "Q25243"},
                  {Enum.at(species, 1), "Q9577526"}
                ], [], []}
    end
  end

  describe "load_features/1" do
    @tag :tmp_dir
    test "returns a structured error for invalid GeoJSON", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "invalid.geojson")
      File.write!(path, "{}")

      assert TreeTypeMapper.load_features(path) ==
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
