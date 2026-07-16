defmodule Xylem.BaumBie.Importer.ReviewCSVTest do
  use ExUnit.Case

  alias Xylem.BaumBie.Importer.ReviewCSV
  alias Xylem.ImportInputError

  @fixtures_path "test/fixtures"

  describe "run/2" do
    test "parses the semicolon-separated review CSV" do
      {:ok, rows} = ReviewCSV.run(Path.join(@fixtures_path, "review_test.csv"))

      assert rows == [
               %{
                 wikidata_id: "Q165145",
                 baumart_bo: "Quercus robur",
                 baumart_de: "Stiel-Eiche",
                 property_id: "P2827",
                 attribute_name: "bluetenfarbe",
                 value: "gelb",
                 group: ""
               },
               %{
                 wikidata_id: "Q165145",
                 baumart_bo: "Quercus robur",
                 baumart_de: "Stiel-Eiche",
                 property_id: "P105",
                 attribute_name: "taxonomischer_rang",
                 value: "Art; Unterart",
                 group: ""
               }
             ]
    end

    test "returns an error for a missing file" do
      path = Path.join(@fixtures_path, "does_not_exist.csv")

      assert ReviewCSV.run(path) ==
               {:error,
                %ImportInputError{
                  source: :review_csv,
                  path: path,
                  reason: :file_read,
                  details: :enoent,
                  line: nil
                }}
    end

    @tag :tmp_dir
    test "returns a structured error for malformed CSV quoting", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "malformed.csv")

      File.write!(
        path,
        "wikidata_id;baumart_bo;baumart_de;property_id;attribute_name;value;group\n\"open"
      )

      assert ReviewCSV.run(path) ==
               {:error,
                %ImportInputError{
                  source: :review_csv,
                  path: path,
                  reason: :invalid_csv_format,
                  details: "expected escape character \" but reached the end of file",
                  line: nil
                }}
    end
  end
end
