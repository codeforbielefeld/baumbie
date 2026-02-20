defmodule Xylem.Wikidata.PropertyConfigTest do
  use ExUnit.Case

  alias Xylem.Wikidata.PropertyConfig

  @test_csv_path "test/fixtures/test_properties.csv"

  describe "load/1" do
    test "loads and parses semicolon-separated CSV" do
      assert {:ok, %PropertyConfig{}} = PropertyConfig.load(path: @test_csv_path)
    end

    test "returns error for missing file" do
      assert {:error, :enoent} = PropertyConfig.load(path: "nonexistent.csv")
    end

    test "parses all entries" do
      assert {:ok, config} = PropertyConfig.load(path: @test_csv_path)

      assert PropertyConfig.all_property_ids(config) |> Enum.sort() ==
               ~w[
                  P105
                  P171
                  P18
                  P225
                  P41
                  P685
                ]
    end
  end

  test "ignored?/2" do
    {:ok, config} = PropertyConfig.load(path: @test_csv_path)

    assert PropertyConfig.ignored?(config, "P18")
    assert PropertyConfig.ignored?(config, "P41")
    refute PropertyConfig.ignored?(config, "P105")
    refute PropertyConfig.ignored?(config, "P225")
    # returns false for unknown properties
    refute PropertyConfig.ignored?(config, "P99999")
  end

  test "known?/2" do
    {:ok, config} = PropertyConfig.load(path: @test_csv_path)
    assert PropertyConfig.known?(config, "P18")
    assert PropertyConfig.known?(config, "P225")
    refute PropertyConfig.known?(config, "P99999")
  end

  describe "inline_config/2" do
    setup do
      {:ok, config} = PropertyConfig.load(path: @test_csv_path)
      %{config: config}
    end

    test "returns inline config with defaults", %{config: config} do
      assert %{target: "taxonomischer_rang", source: "rdfs:label", keep_source: false} =
               PropertyConfig.inline_config(config, "P105")
    end

    test "returns inline config with explicit keep_source", %{config: config} do
      assert %{target: "uebergeordnetes_taxon", source: "rdfs:label", keep_source: true} =
               PropertyConfig.inline_config(config, "P171")
    end

    test "returns nil for non-inline properties", %{config: config} do
      assert PropertyConfig.inline_config(config, "P18") == nil
      assert PropertyConfig.inline_config(config, "P225") == nil
    end

    test "returns nil for unknown properties", %{config: config} do
      assert PropertyConfig.inline_config(config, "P99999") == nil
    end
  end

  describe "properties without action" do
    setup do
      {:ok, config} = PropertyConfig.load(path: @test_csv_path)
      %{config: config}
    end

    test "properties with empty action are treated as keep", %{config: config} do
      refute PropertyConfig.ignored?(config, "P225")
      assert PropertyConfig.inline_config(config, "P225") == nil
      assert PropertyConfig.known?(config, "P225")
    end
  end

  describe "append_unknown/4" do
    @append_csv_path "test/fixtures/test_append.csv"

    setup do
      # Create a copy of the test CSV to append to
      File.cp!(@test_csv_path, @append_csv_path)
      {:ok, config} = PropertyConfig.load(path: @append_csv_path)
      on_exit(fn -> File.rm(@append_csv_path) end)
      %{config: config}
    end

    test "appends unknown properties to CSV", %{config: config} do
      :ok = PropertyConfig.append_unknown(config, @append_csv_path, ["P999", "P888"])

      {:ok, updated} = PropertyConfig.load(path: @append_csv_path)
      assert PropertyConfig.known?(updated, "P999")
      assert PropertyConfig.known?(updated, "P888")
    end

    test "uses labels for descriptions", %{config: config} do
      :ok =
        PropertyConfig.append_unknown(config, @append_csv_path, ["P999"],
          labels: %{"P999" => "Testbeschreibung"}
        )

      {:ok, updated} = PropertyConfig.load(path: @append_csv_path)
      assert updated.entries["P999"].description == "Testbeschreibung"
    end

    test "skips already known properties", %{config: config} do
      :ok = PropertyConfig.append_unknown(config, @append_csv_path, ["P18", "P225", "P999"])

      {:ok, updated} = PropertyConfig.load(path: @append_csv_path)
      # P18 and P225 already exist, only P999 is new
      assert PropertyConfig.known?(updated, "P999")
      # Total: 6 original + 1 new
      assert length(PropertyConfig.all_property_ids(updated)) == 7
    end

    test "does nothing for empty list", %{config: config} do
      original_content = File.read!(@append_csv_path)
      :ok = PropertyConfig.append_unknown(config, @append_csv_path, [])
      assert File.read!(@append_csv_path) == original_content
    end

    test "does nothing when all properties are known", %{config: config} do
      original_content = File.read!(@append_csv_path)
      :ok = PropertyConfig.append_unknown(config, @append_csv_path, ["P18", "P225"])
      assert File.read!(@append_csv_path) == original_content
    end

    test "deduplicates property IDs", %{config: config} do
      :ok = PropertyConfig.append_unknown(config, @append_csv_path, ["P999", "P999", "P999"])

      {:ok, updated} = PropertyConfig.load(path: @append_csv_path)
      assert length(PropertyConfig.all_property_ids(updated)) == 7
    end

    test "new properties default to keep action", %{config: config} do
      :ok = PropertyConfig.append_unknown(config, @append_csv_path, ["P999"])

      {:ok, updated} = PropertyConfig.load(path: @append_csv_path)
      refute PropertyConfig.ignored?(updated, "P999")
      assert PropertyConfig.inline_config(updated, "P999") == nil
    end

    test "sorts appended properties by ID", %{config: config} do
      :ok =
        PropertyConfig.append_unknown(config, @append_csv_path, ["P999", "P100", "P500"],
          labels: %{"P100" => "first", "P500" => "second", "P999" => "third"}
        )

      content = File.read!(@append_csv_path)
      p100_pos = :binary.match(content, "P100") |> elem(0)
      p500_pos = :binary.match(content, "P500") |> elem(0)
      p999_pos = :binary.match(content, "P999") |> elem(0)

      assert p100_pos < p500_pos
      assert p500_pos < p999_pos
    end
  end

  describe "inline config with custom source" do
    test "parses custom source property" do
      csv = """
      property_id;action;config;description
      P999;inline;{"target": "test_prop", "source": "schema:description"};Test
      """

      path = "test/fixtures/test_custom_source.csv"
      File.write!(path, csv)

      on_exit(fn -> File.rm(path) end)

      {:ok, config} = PropertyConfig.load(path: path)

      assert %{target: "test_prop", source: "schema:description", keep_source: false} =
               PropertyConfig.inline_config(config, "P999")
    end
  end
end
