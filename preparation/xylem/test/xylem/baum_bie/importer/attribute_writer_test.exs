defmodule Xylem.BaumBie.Importer.AttributeWriterTest do
  use ExUnit.Case

  alias Xylem.BaumBie.Importer.AttributeWriter

  describe "build_attribute_row/4" do
    test "builds a row with the mapped type, provider metadata and no group" do
      entry = %{
        type: "Quantity",
        action: :keep,
        config: nil,
        description: "Höhe – maximale Wuchshöhe",
        import: nil
      }

      assert AttributeWriter.build_attribute_row("P2048", "hoehe", entry, "prov-uuid") == %{
               "name" => "hoehe",
               "description" => "Höhe – maximale Wuchshöhe",
               "type" => "number",
               "provider_uuid" => "prov-uuid",
               "provider_attribute_id" => "P2048",
               "tree_type_attribute_group_uuid" => nil
             }
    end
  end

  describe "build_value_row/4" do
    test "builds a denormalized value row with NULL unit" do
      row = %{
        wikidata_id: "Q165145",
        baumart_bo: "Quercus robur",
        baumart_de: "Stiel-Eiche",
        property_id: "P2827",
        attribute_name: "bluetenfarbe",
        value: "gelb",
        group: ""
      }

      assert AttributeWriter.build_value_row(row, "tt-uuid", "attr-uuid", "string") == %{
               "tree_type_uuid" => "tt-uuid",
               "tree_type_attribute_uuid" => "attr-uuid",
               "type" => "string",
               "value" => "gelb",
               "unit" => nil
             }
    end
  end
end
