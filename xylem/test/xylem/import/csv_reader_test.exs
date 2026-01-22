defmodule Xylem.Import.CSVReaderTest do
  use ExUnit.Case

  alias Xylem.Import.CSVReader

  @fixtures_path "test/fixtures"

  describe "run/2" do
    test "parses valid CSV file" do
      {:ok, species} = CSVReader.run(Path.join(@fixtures_path, "test_species.csv"))

      assert length(species) == 2

      assert hd(species) == %{
               baumart_bo: "Quercus robur",
               baumart_de: "Stiel-Eiche",
               wikidata_id: "Q165145"
             }
    end

    test "returns error for missing file" do
      assert {:error, :enoent} = CSVReader.run("nonexistent.csv")
    end

    @tag :tmp_dir
    test "returns error for missing columns", %{tmp_dir: tmp_dir} do
      csv_content = "name,baumart_de,wikidata_id\nvalue1,value2,Q123\n"
      path = Path.join(tmp_dir, "invalid.csv")
      File.write!(path, csv_content)

      assert {:error, {:missing_column, "baumart_bo"}} = CSVReader.run(path)
    after
      File.rm_rf!(tmp_dir)
    end
  end
end
