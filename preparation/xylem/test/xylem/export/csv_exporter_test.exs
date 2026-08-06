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

  test "skips species without processed TTL and reports how many" do
    assert {:ok, result} =
             CSVExporter.run(
               csv_path: @test_species_path,
               property_config_path: @test_config_path,
               processed_dir: @test_processed_dir,
               output_path: @test_output_path
             )

    # Q165145 has a TTL, Q158776 does not
    assert result.species_count == 1
    assert result.missing_processed == 1
  end

  describe "shared entities and multi-values" do
    @shared_qid_path "test/fixtures/export_test/shared_qid.csv"

    @multi_value_ttl """
    @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
    @prefix wdt: <http://www.wikidata.org/prop/direct/> .
    @prefix wd: <http://www.wikidata.org/entity/> .

    wd:Q26745
        rdfs:label "Spitzahorn"@de ;
        <https://www.baumbie.org/xylem/vocab/uebergeordnetes_taxon> "Seifenbaumartige"@de, "Ahorne"@de ;
        wdt:P171 wd:Q42292, wd:Q156901 ;
        wdt:P225 "Acer platanoides", "Acer platanoides L." .

    wd:Q42292 rdfs:label "Seifenbaumartige"@de .
    wd:Q156901 rdfs:label "Ahorne"@de .
    """

    setup do
      File.write!(Path.join(@test_processed_dir, "Q26745.ttl"), @multi_value_ttl)

      File.write!(@shared_qid_path, """
      baumart_bo,baumart_de,wikidata_id
      Acer platanoides,Spitz-Ahorn,Q26745
      Acer platanoides 'Columnaris',Säulen-Ahorn,Q26745
      """)

      :ok
    end

    test "emits every value once per target and keeps genuine multi-values" do
      assert {:ok, result} =
               CSVExporter.run(
                 csv_path: @shared_qid_path,
                 property_config_path: @test_config_path,
                 processed_dir: @test_processed_dir,
                 output_path: @test_output_path
               )

      assert result.species_count == 2

      [_header | rows] = @test_output_path |> File.read!() |> String.split("\n", trim: true)

      # Sorted because the object order within one property is not guaranteed by
      # RDF.ex; every other aspect of the expectation is exact.
      assert Enum.sort(rows) ==
               Enum.sort([
                 "Q26745;Acer platanoides;Spitz-Ahorn;P171;uebergeordnetes_taxon;Seifenbaumartige;",
                 "Q26745;Acer platanoides;Spitz-Ahorn;P171;uebergeordnetes_taxon;Ahorne;",
                 "Q26745;Acer platanoides;Spitz-Ahorn;P225;wissenschaftlicher_name;Acer platanoides;",
                 "Q26745;Acer platanoides;Spitz-Ahorn;P225;wissenschaftlicher_name;Acer platanoides L.;",
                 "Q26745;Acer platanoides 'Columnaris';Säulen-Ahorn;P171;uebergeordnetes_taxon;Seifenbaumartige;",
                 "Q26745;Acer platanoides 'Columnaris';Säulen-Ahorn;P171;uebergeordnetes_taxon;Ahorne;",
                 "Q26745;Acer platanoides 'Columnaris';Säulen-Ahorn;P225;wissenschaftlicher_name;Acer platanoides;",
                 "Q26745;Acer platanoides 'Columnaris';Säulen-Ahorn;P225;wissenschaftlicher_name;Acer platanoides L.;"
               ])

      assert length(rows) == length(Enum.uniq(rows))
    end
  end

  describe "output safety" do
    @sentinel "reviewed;content;must;survive\n"
    @broken_mapping_path "test/fixtures/export_test/broken_mapping.csv"

    setup do
      File.write!(@test_output_path, @sentinel)
      :ok
    end

    test "leaves an existing export untouched when the mapping is invalid" do
      File.write!(@broken_mapping_path, """
      baumart_bo,baumart_de,wikidata_id
      Quercus robur,Stiel-Eiche,Q165145
      Quercus robur,Stiel-Eiche,Q165145
      """)

      assert {:error, %Xylem.MappingValidationError{issues: [%{code: :duplicate_mapping}]}} =
               CSVExporter.run(
                 csv_path: @broken_mapping_path,
                 property_config_path: @test_config_path,
                 processed_dir: @test_processed_dir,
                 output_path: @test_output_path
               )

      assert File.read!(@test_output_path) == @sentinel
    end

    @tag :write_failure
    test "leaves an existing export untouched when the write itself fails" do
      dir = Path.dirname(@test_output_path)
      File.chmod!(dir, 0o500)
      on_exit(fn -> File.chmod(dir, 0o755) end)

      result =
        CSVExporter.run(
          csv_path: @test_species_path,
          property_config_path: @test_config_path,
          processed_dir: @test_processed_dir,
          output_path: @test_output_path
        )

      assert {:error, :eacces} = result
      assert File.read!(@test_output_path) == @sentinel
    end

    test "leaves an existing export untouched when a processed TTL is broken" do
      File.write!(Path.join(@test_processed_dir, "Q165145.ttl"), "this is not turtle")

      assert {:error, %Xylem.ImportInputError{source: :processed_ttl, reason: :invalid_turtle}} =
               CSVExporter.run(
                 csv_path: @test_species_path,
                 property_config_path: @test_config_path,
                 processed_dir: @test_processed_dir,
                 output_path: @test_output_path
               )

      assert File.read!(@test_output_path) == @sentinel
      assert Path.wildcard(@test_output_path <> "*") == [@test_output_path]
    end
  end
end
