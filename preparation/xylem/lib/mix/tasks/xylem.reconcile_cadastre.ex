defmodule Mix.Tasks.Xylem.ReconcileCadastre do
  @shortdoc "Compares the tree cadastre species with the BaumBie/Wikidata mapping"

  @moduledoc """
  Reports the differences between the species of a tree cadastre and the
  BaumBie/Wikidata mapping. Writes nothing.

      $ mix xylem.reconcile_cadastre [options]

  Run this when a new cadastre arrives: a species missing in the mapping gets no
  `tree_type` until it is added there. Mapping entries missing in the cadastre
  are harmless.

  ## Options

  - `--trees` - cadastre GeoJSON path (default: `../input/trees2.geojson`)
  - `--mapping` - Wikidata mapping CSV path (default: `priv/data/baumbie_wikidata_mapping.csv`)

  ## Examples

      # Check the default cadastre
      mix xylem.reconcile_cadastre

      # Check a new cadastre
      mix xylem.reconcile_cadastre --trees path/to/trees.geojson

  """

  use Mix.Task

  alias Xylem.Import.CSVReader
  alias Xylem.Reconciliation.CadastreDrift

  @requirements ["app.config"]

  @default_trees "../input/trees2.geojson"

  @switches [trees: :string, mapping: :string]

  @impl Mix.Task
  def run(args) do
    {opts, _} = OptionParser.parse!(args, strict: @switches)

    trees_path = opts[:trees] || @default_trees
    mapping_path = opts[:mapping] || Xylem.default_csv_path()

    with {:ok, species} <- CadastreDrift.load_species(trees_path),
         {:ok, mapping} <- CSVReader.run(mapping_path) do
      print_report(species, mapping, CadastreDrift.compare(species, mapping))
    else
      {:error, error} ->
        Mix.shell().error("Failed: #{Exception.message(error)}")
        exit({:shutdown, 1})
    end
  end

  defp print_report(species, mapping, drift) do
    Mix.shell().info("=== Cadastre Report ===\n")
    Mix.shell().info("Cadastre species:    #{length(species)}")
    Mix.shell().info("Mapping rows:        #{length(mapping)}")
    Mix.shell().info("Missing in mapping:  #{length(drift.missing_in_mapping)}")
    Mix.shell().info("Missing in cadastre: #{length(drift.missing_in_cadastre)}")

    print_section(
      "Missing in mapping (no tree_type until added)",
      drift.missing_in_mapping,
      &"#{&1.baumart_bo} | #{&1.baumart_de} | trees: #{&1.tree_count}"
    )

    print_section(
      "Missing in cadastre (harmless)",
      drift.missing_in_cadastre,
      &"#{&1.baumart_bo} | #{&1.wikidata_id}"
    )
  end

  defp print_section(_title, [], _format), do: :ok

  defp print_section(title, entries, format) do
    Mix.shell().info("\n--- #{title} ---")
    Enum.each(entries, &Mix.shell().info("  #{format.(&1)}"))
  end
end
