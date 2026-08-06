defmodule Xylem.BaumBie.Importer.TreeTypeMapper do
  @moduledoc """
  Derives `tree_types` from the Bielefeld tree cadastre (Phase 0) and matches
  them against the Wikidata mapping to assign `wikidata_id` (Phase 1).

  The pure transformation functions are separated from GeoJSON I/O so they can
  be unit-tested without the 52 MB cadastre file.
  """

  require Logger

  alias Xylem.Import.Mapping
  alias Xylem.ImportInputError

  @type species :: %{name_botanic: String.t(), name: String.t(), name_trivial: String.t()}

  @doc """
  Reduces raw GeoJSON features to distinct tree species.

  Deduplicates by the canonical form of `Baumart_bo`, keeping the first
  occurrence, so that cadastre spellings differing only in whitespace or quoting
  yield a single `tree_type`. The stored `name_botanic` keeps the cadastre
  spelling with whitespace collapsed; the cadastre stays authoritative for
  content.

  `name` and `name_trivial` are both taken from `Baumart_de`; `Baumart_ku`
  (internal short code) is ignored. A `Baumart_bo` mapped to conflicting
  `Baumart_de` values is logged and the first value wins.
  """
  @spec distinct_species([map()]) :: [species()]
  def distinct_species(features) do
    features
    |> Enum.reduce({%{}, [], MapSet.new()}, fn feature, {seen, order, merges} ->
      props = Map.get(feature, "properties", %{})
      raw_botanic = props |> Map.get("Baumart_bo", "") |> String.trim()
      name_de = props |> Map.get("Baumart_de", "") |> String.trim()
      key = Mapping.canonical_name(raw_botanic)

      cond do
        raw_botanic == "" ->
          {seen, order, merges}

        existing = Map.get(seen, key) ->
          maybe_warn_conflict(raw_botanic, existing.species.name, name_de)
          {seen, order, collect_merge(merges, existing.raw, raw_botanic)}

        true ->
          entry = %{
            raw: raw_botanic,
            species: %{
              name_botanic: collapse_whitespace(raw_botanic),
              name: name_de,
              name_trivial: name_de
            }
          }

          {Map.put(seen, key, entry), [key | order], merges}
      end
    end)
    |> then(fn {seen, order, merges} ->
      log_merges(merges)
      order |> Enum.reverse() |> Enum.map(&Map.fetch!(seen, &1).species)
    end)
  end

  defp collapse_whitespace(string), do: String.replace(string, ~r/\s+/, " ")

  # Compares the raw cadastre spellings, so a name that is merely normalized
  # (every occurrence double-spaced) is not mistaken for a merge of two names.
  defp collect_merge(merges, kept, kept), do: merges
  defp collect_merge(merges, kept, merged), do: MapSet.put(merges, {kept, merged})

  defp log_merges(merges) do
    Enum.each(merges, fn {kept, merged} ->
      Logger.warning(
        "Merging cadastre species #{inspect(merged)} into #{inspect(kept)} " <>
          "(same canonical name)"
      )
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
  Matches derived species against the Wikidata mapping by canonical botanical
  name, so that spelling differences between cadastre and mapping (double
  spaces, cultivar quote variants) do not cost a species its Wikidata data.

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
    mapping_by_key =
      Map.new(mapping, fn %{baumart_bo: bo} = entry -> {Mapping.canonical_name(bo), entry} end)

    {matched, unmatched_cadastre} =
      Enum.split_with(species_list, fn %{name_botanic: bo} ->
        Map.has_key?(mapping_by_key, Mapping.canonical_name(bo))
      end)

    matched_pairs =
      Enum.map(matched, fn %{name_botanic: bo} = species ->
        {species, mapping_by_key[Mapping.canonical_name(bo)].wikidata_id}
      end)

    species_keys = MapSet.new(species_list, &Mapping.canonical_name(&1.name_botanic))

    unmatched_mapping =
      Enum.reject(mapping, &MapSet.member?(species_keys, Mapping.canonical_name(&1.baumart_bo)))

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
