defmodule Xylem.BaumBie.Importer.TypeMapperTest do
  use ExUnit.Case

  alias Xylem.BaumBie.Importer.TypeMapper

  describe "map/2" do
    test "maps WikibaseItem and String to string" do
      assert TypeMapper.map("WikibaseItem", "P105") == "string"
      assert TypeMapper.map("String", "P225") == "string"
    end

    test "maps Quantity to number" do
      assert TypeMapper.map("Quantity", "P2048") == "number"
    end

    test "maps Url to url" do
      assert TypeMapper.map("Url", "P856") == "url"
    end

    test "maps GeoShape to geoshape" do
      assert TypeMapper.map("GeoShape", "P8485") == "geoshape"
    end

    test "maps CommonsMedia to image by default" do
      assert TypeMapper.map("CommonsMedia", "P18") == "image"
    end

    test "maps the P989 audio outlier to audio" do
      assert TypeMapper.map("CommonsMedia", "P989") == "audio"
    end

    test "falls back to string for unknown datatypes" do
      assert TypeMapper.map("Time", "P574") == "string"
    end
  end
end
