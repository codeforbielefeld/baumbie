defmodule Xylem.BaumBie.Importer.TreeTypeMapper do
  @moduledoc """
  Derives `tree_types` from the Bielefeld tree cadastre (Phase 0) and matches
  them against the Wikidata mapping to assign `wikidata_id` (Phase 1).

  The pure transformation functions are separated from GeoJSON I/O so they can
  be unit-tested without the 52 MB cadastre file.
  """

  require Logger

  alias Xylem.ImportInputError

  @type species :: %{name_botanic: String.t(), name: String.t(), name_trivial: String.t()}

  @doc """
  Reduces raw GeoJSON features to distinct tree species.

  Deduplicates by `Baumart_bo` (botanical name), keeping the first occurrence.
  `name` and `name_trivial` are both taken from `Baumart_de`; `Baumart_ku`
  (internal short code) is ignored. A `Baumart_bo` mapped to conflicting
  `Baumart_de` values is logged and the first value wins.
  """
  @spec distinct_species([map()]) :: [species()]
  def distinct_species(features) do
    features
    |> Enum.reduce({%{}, []}, fn feature, {seen, order} ->
      props = Map.get(feature, "properties", %{})
      name_botanic = props |> Map.get("Baumart_bo", "") |> String.trim()
      name_de = props |> Map.get("Baumart_de", "") |> String.trim()

      cond do
        name_botanic == "" ->
          {seen, order}

        Map.has_key?(seen, name_botanic) ->
          maybe_warn_conflict(name_botanic, seen[name_botanic], name_de)
          {seen, order}

        true ->
          {Map.put(seen, name_botanic, name_de), [name_botanic | order]}
      end
    end)
    |> then(fn {seen, order} ->
      order
      |> Enum.reverse()
      |> Enum.map(fn name_botanic ->
        name_de = Map.fetch!(seen, name_botanic)
        %{name_botanic: name_botanic, name: name_de, name_trivial: name_de}
      end)
    end)
  end

  defp maybe_warn_conflict(_name_botanic, existing, existing), do: :ok

  defp maybe_warn_conflict(name_botanic, existing, other) do
    Logger.warning(
      "Baumart_bo #{inspect(name_botanic)} maps to conflicting Baumart_de " <>
        "(#{inspect(existing)} vs #{inspect(other)}), keeping the first"
    )
  end

  @doc """
  Builds a `tree_types` upsert row from a derived species.

  Citree-owned fields are omitted so reruns cannot clear existing metadata.
  """
  @spec build_tree_type_row(species(), String.t() | nil) :: map()
  def build_tree_type_row(
        %{name_botanic: name_botanic, name: name, name_trivial: name_trivial},
        wikidata_id
      ) do
    %{
      "name" => name,
      "name_trivial" => name_trivial,
      "name_botanic" => name_botanic,
      "wikidata_id" => wikidata_id
    }
  end

  @doc """
  Matches derived species against the Wikidata mapping by botanical name.

  Returns a triple:
  - `matched` — `[{species, wikidata_id}]` (cadastre species with a mapping)
  - `unmatched_cadastre` — species without a mapping entry (created without
    `wikidata_id`, info-level)
  - `unmatched_mapping` — mapping entries with no cadastre species (warning,
    no auto-create)
  """
  @spec match_wikidata_ids([species()], [map()]) ::
          {[{species(), String.t()}], [species()], [map()]}
  def match_wikidata_ids(species_list, mapping) do
    mapping_by_bo = Map.new(mapping, fn %{baumart_bo: bo} = entry -> {bo, entry} end)

    {matched, unmatched_cadastre} =
      Enum.split_with(species_list, fn %{name_botanic: bo} ->
        Map.has_key?(mapping_by_bo, bo)
      end)

    matched_pairs =
      Enum.map(matched, fn %{name_botanic: bo} = species ->
        {species, mapping_by_bo[bo].wikidata_id}
      end)

    matched_bos = MapSet.new(species_list, & &1.name_botanic)
    unmatched_mapping = Enum.reject(mapping, &MapSet.member?(matched_bos, &1.baumart_bo))

    {matched_pairs, unmatched_cadastre, unmatched_mapping}
  end

  @doc """
  Loads and decodes GeoJSON features from the cadastre file at `path`.
  """
  @spec load_features(Path.t()) :: {:ok, [map()]} | {:error, term()}
  def load_features(path) do
    case File.read(path) do
      {:ok, content} -> decode_features(content, path)
      {:error, reason} -> input_error(path, :file_read, reason)
    end
  end

  defp decode_features(content, path) do
    case Jason.decode(content) do
      {:ok, %{"features" => features}} when is_list(features) -> {:ok, features}
      {:ok, _other} -> input_error(path, :invalid_geojson)
      {:error, error} -> input_error(path, :invalid_json, Exception.message(error))
    end
  end

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
