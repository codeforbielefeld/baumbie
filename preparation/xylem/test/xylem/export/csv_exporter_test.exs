defmodule Xylem.Export.CSVExporterTest do
  use ExUnit.Case

  alias Xylem.Export.CSVExporter

  @test_species_path "test/fixtures/test_species.csv"
  @test_config_path "test/fixtures/test_properties.csv"
  @test_processed_dir "test/fixtures/export_test/processed"
  @test_output_path "test/fixtures/export_test/output.csv"

  @test_ttl """
  @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
  @prefix wdt: <http://www.wikidata.org/prop/direct/> .
  @prefix wd: <http://www.wikidata.org/entity/> .

  wd:Q165145
      rdfs:label "Stieleiche"@de, "Quercus robur"@en ;
      <https://www.baumbie.org/xylem/vocab/taxonomischer_rang> "Art"@de ;
      <https://www.baumbie.org/xylem/vocab/uebergeordnetes_taxon> "Eichen"@de ;
      wdt:P171 wd:Q12004 ;
      wdt:P225 "Quercus robur" ;
      wdt:P685 "38942" .

  wd:Q12004
      rdfs:label "Eichen"@de, "oaks"@en .
  """

  setup do
    File.mkdir_p!(@test_processed_dir)
    File.write!(Path.join(@test_processed_dir, "Q165145.ttl"), @test_ttl)

    on_exit(fn -> File.rm_rf!("test/fixtures/export_test") end)

    :ok
  end

  test "exports processed species data to CSV" do
    assert {:ok, result} =
             CSVExporter.run(
               csv_path: @test_species_path,
               property_config_path: @test_config_path,
               processed_dir: @test_processed_dir,
               output_path: @test_output_path,
               limit: 1
             )

    assert result.species_count == 1
    assert result.output == @test_output_path

    rows =
      @test_output_path
      |> File.read!()
      |> String.split("\n", trim: true)

    [header | data_rows] = rows

    assert header == "wikidata_id;baumart_bo;baumart_de;property_id;attribute_name;value;group"

    # P105 inline → baumbie:taxonomischer_rang "Art"@de
    assert "Q165145;Quercus robur;Stiel-Eiche;P105;taxonomischer_rang;Art;" in data_rows

    # P171 inline → baumbie:uebergeordnetes_taxon "Eichen"@de
    assert "Q165145;Quercus robur;Stiel-Eiche;P171;uebergeordnetes_taxon;Eichen;" in data_rows

    # P225 keep → wdt:P225 "Quercus robur" (plain string)
    assert "Q165145;Quercus robur;Stiel-Eiche;P225;wissenschaftlicher_name;Quercus robur;" in data_rows

    # P685 keep → wdt:P685 "38942" (ExternalId)
    assert "Q165145;Quercus robur;Stiel-Eiche;P685;ncbi_id;38942;" in data_rows

    # P18 and P41 are ignored → should not appear
    refute Enum.any?(data_rows, &String.contains?(&1, ";P18;"))
    refute Enum.any?(data_rows, &String.contains?(&1, ";P41;"))
  end

  test "skips species without processed TTL" do
    assert {:ok, result} =
             CSVExporter.run(
               csv_path: @test_species_path,
               property_config_path: @test_config_path,
               processed_dir: @test_processed_dir,
               output_path: @test_output_path
             )

    # Q165145 has a TTL, Q158776 does not
    assert result.species_count == 1
  end
end
