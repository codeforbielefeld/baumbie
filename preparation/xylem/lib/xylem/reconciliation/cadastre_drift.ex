defmodule Xylem.Reconciliation.CadastreDrift do
  @moduledoc """
  Compares the species of the tree cadastre with the species mapping.

  The mapping is the only species source of the import, so a species new to the
  cadastre would silently get no `tree_type`. This check is what notices it. The
  cadastre stays a check input here and never becomes a pipeline dependency.
  """

  alias Xylem.Import.CSVReader
  alias Xylem.Import.Mapping
  alias Xylem.ImportInputError

  @type species :: %{
          baumart_bo: String.t(),
          baumart_de: String.t(),
          tree_count: pos_integer()
        }

  @type t :: %{
          missing_in_mapping: [species()],
          missing_in_cadastre: [CSVReader.species()]
        }

  @doc "Loads the distinct species of the cadastre GeoJSON at `path`."
  @spec load_species(Path.t()) :: {:ok, [species()]} | {:error, ImportInputError.t()}
  def load_species(path) do
    case File.read(path) do
      {:ok, content} -> decode_species(content, path)
      {:error, reason} -> input_error(path, :file_read, reason)
    end
  end

  defp decode_species(content, path) do
    case Jason.decode(content) do
      {:ok, %{"features" => features}} when is_list(features) ->
        {:ok, distinct_species(features)}

      {:ok, _other} ->
        input_error(path, :invalid_geojson)

      {:error, error} ->
        input_error(path, :invalid_json, Exception.message(error))
    end
  end

  @doc """
  Reduces GeoJSON features to distinct species with their tree count.

  Spellings differing only in whitespace or quoting count as one species. Names
  come with collapsed whitespace, ready to be copied into the mapping.
  """
  @spec distinct_species([map()]) :: [species()]
  def distinct_species(features) do
    features
    |> Enum.map(&feature_species/1)
    |> Enum.reject(&(&1.baumart_bo == ""))
    |> Enum.group_by(&Mapping.canonical_name(&1.baumart_bo))
    |> Enum.map(fn {_key, [first | _] = all} -> Map.put(first, :tree_count, length(all)) end)
    |> Enum.sort_by(& &1.baumart_bo)
  end

  defp feature_species(feature) do
    properties = Map.get(feature, "properties", %{})

    %{
      baumart_bo: property(properties, "Baumart_bo"),
      baumart_de: property(properties, "Baumart_de")
    }
  end

  defp property(properties, key) do
    properties |> Map.get(key) |> to_string() |> String.split() |> Enum.join(" ")
  end

  @doc """
  Compares cadastre species with all mapping rows.

  Rows with an empty QID count as known: they mark deliberate non-species such
  as `Waldartiger Bestand`, which should not be reported on every check.

  - `missing_in_mapping` needs action, these species get no `tree_type`
  - `missing_in_cadastre` is harmless, the mapping may run ahead of the cadastre
  """
  @spec compare([species()], [CSVReader.species()]) :: t()
  def compare(species, mapping_rows) do
    species_names = names(species)
    mapping_names = names(mapping_rows)

    %{
      missing_in_mapping: Enum.reject(species, &member?(mapping_names, &1)),
      missing_in_cadastre: Enum.reject(mapping_rows, &member?(species_names, &1))
    }
  end

  defp names(entries), do: MapSet.new(entries, &Mapping.canonical_name(&1.baumart_bo))

  defp member?(names, entry), do: MapSet.member?(names, Mapping.canonical_name(entry.baumart_bo))

  defp input_error(path, reason, details \\ nil) do
    {:error,
     %ImportInputError{
       source: :tree_geojson,
       path: path,
       reason: reason,
       details: details,
       line: nil
     }}
  end
end
