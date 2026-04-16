defmodule Xylem.Reconciliation.CityTreeTypeMatcher do
  @moduledoc """
  Matches city tree type botanical names against Citree/Wikidata entries
  to assign Wikidata IDs.

  Uses a multi-level matching pipeline (first match wins):

  1. **Exact** - direct string match on botanical name
  2. **Normalized** - case, whitespace, quotes, subspecies notation
  3. **Hybrid-agnostic** - ignore hybrid markers (`×`, `x`)
  4. **Cultivar→species** - strip cultivar name, match base species
  5. **Species→genus** - match `"species"` entries to genus level
  6. **Synonym table** - explicit curated mappings
  7. **Manual** - direct Wikidata ID assignments from curated CSV
  """

  alias Xylem.Reconciliation.Normalizer

  @type match_result :: %{
          city_name: String.t(),
          wikidata_id: String.t(),
          level: match_level(),
          citree_name: String.t() | nil
        }

  @type match_level ::
          :exact
          | :normalized
          | :hybrid_agnostic
          | :cultivar_to_species
          | :species_to_genus
          | :synonym
          | :manual

  @type unmatched :: %{city_name: String.t(), reason: :no_match | :non_tree}

  @non_tree_entries ["Nacherfassung", "Waldartiger Bestand"]

  @doc """
  Runs the matching pipeline.

  ## Options

  - `:synonyms` - list of `%{city_name: String.t(), citree_name: String.t()}` mappings
  - `:manual_ids` - list of `%{tree_type_botanic: String.t(), wikidata_id: String.t()}` direct assignments
  """
  @spec run([map()], [map()], keyword()) :: %{
          matches: [match_result()],
          unmatched: [unmatched()]
        }
  def run(city_entries, citree_entries, opts \\ []) do
    lookups = build_lookups(citree_entries)
    synonyms = Keyword.get(opts, :synonyms, [])

    manual_ids =
      Keyword.get(opts, :manual_ids, []) |> Map.new(&{&1.tree_type_botanic, &1.wikidata_id})

    {matches, unmatched} =
      Enum.reduce(city_entries, {[], []}, fn city_entry, {matches, unmatched} ->
        name = city_entry.tree_type_botanic
        existing_id = city_entry[:wikidata_id]

        cond do
          name in @non_tree_entries ->
            {matches, [%{city_name: name, reason: :non_tree} | unmatched]}

          existing_id not in [nil, ""] ->
            match = %{
              city_name: name,
              wikidata_id: existing_id,
              level: :existing,
              citree_name: nil
            }

            {[match | matches], unmatched}

          true ->
            case match_entry(name, lookups, synonyms, manual_ids) do
              {:ok, match} -> {[match | matches], unmatched}
              :no_match -> {matches, [%{city_name: name, reason: :no_match} | unmatched]}
            end
        end
      end)

    %{matches: Enum.reverse(matches), unmatched: Enum.reverse(unmatched)}
  end

  defp match_entry(name, lookups, synonyms, manual_ids) do
    with :no_match <- try_exact(name, lookups),
         :no_match <- try_normalized(name, lookups),
         :no_match <- try_hybrid_agnostic(name, lookups),
         :no_match <- try_cultivar_to_species(name, lookups),
         :no_match <- try_species_to_genus(name, lookups),
         :no_match <- try_synonym(name, lookups, synonyms),
         :no_match <- try_manual(name, manual_ids) do
      :no_match
    end
  end

  # Level 1: Exact match
  defp try_exact(name, %{exact: exact}) do
    case Map.fetch(exact, name) do
      {:ok, {wikidata_id, citree_name}} ->
        {:ok,
         %{city_name: name, wikidata_id: wikidata_id, level: :exact, citree_name: citree_name}}

      :error ->
        :no_match
    end
  end

  # Level 2: Normalized match
  defp try_normalized(name, %{normalized: normalized}) do
    key = Normalizer.normalize(name)

    case Map.fetch(normalized, key) do
      {:ok, {wikidata_id, citree_name}} ->
        {:ok,
         %{
           city_name: name,
           wikidata_id: wikidata_id,
           level: :normalized,
           citree_name: citree_name
         }}

      :error ->
        :no_match
    end
  end

  # Level 3: Hybrid-agnostic match
  defp try_hybrid_agnostic(name, %{no_hybrid: no_hybrid}) do
    key = Normalizer.remove_hybrid(name)

    case Map.fetch(no_hybrid, key) do
      {:ok, {wikidata_id, citree_name}} ->
        {:ok,
         %{
           city_name: name,
           wikidata_id: wikidata_id,
           level: :hybrid_agnostic,
           citree_name: citree_name
         }}

      :error ->
        :no_match
    end
  end

  # Level 4: Strip cultivar, match base species
  defp try_cultivar_to_species(name, %{
         base_species: base_species,
         base_species_no_hybrid: base_no_hybrid
       }) do
    case Normalizer.strip_cultivar(name) do
      ^name ->
        :no_match

      stripped ->
        key = Normalizer.normalize(stripped)

        case Map.fetch(base_species, key) do
          {:ok, {wikidata_id, citree_name}} ->
            {:ok,
             %{
               city_name: name,
               wikidata_id: wikidata_id,
               level: :cultivar_to_species,
               citree_name: citree_name
             }}

          :error ->
            key_nh = Normalizer.remove_hybrid(stripped)

            case Map.fetch(base_no_hybrid, key_nh) do
              {:ok, {wikidata_id, citree_name}} ->
                {:ok,
                 %{
                   city_name: name,
                   wikidata_id: wikidata_id,
                   level: :cultivar_to_species,
                   citree_name: citree_name
                 }}

              :error ->
                :no_match
            end
        end
    end
  end

  # Level 5: "species" entries → genus
  defp try_species_to_genus(name, %{genus: genus}) do
    if species_entry?(name) do
      genus_name = name |> String.split(~r/\s+/) |> hd() |> String.downcase()

      case Map.fetch(genus, genus_name) do
        {:ok, {wikidata_id, citree_name}} ->
          {:ok,
           %{
             city_name: name,
             wikidata_id: wikidata_id,
             level: :species_to_genus,
             citree_name: citree_name
           }}

        :error ->
          :no_match
      end
    else
      :no_match
    end
  end

  # Level 6: Synonym table
  defp try_synonym(name, lookups, synonyms) do
    case Enum.find(synonyms, &(&1.city_name == name)) do
      %{citree_name: citree_name} ->
        # Look up the synonym target through the normal lookup chain
        with :no_match <- try_exact(citree_name, lookups),
             :no_match <- try_normalized(citree_name, lookups),
             :no_match <- try_hybrid_agnostic(citree_name, lookups) do
          :no_match
        else
          {:ok, match} ->
            {:ok, %{match | city_name: name, level: :synonym, citree_name: citree_name}}
        end

      nil ->
        # Try matching with cultivar stripped through synonym table
        stripped = Normalizer.strip_cultivar(name)

        if stripped != name do
          case Enum.find(synonyms, &(&1.city_name == stripped)) do
            %{citree_name: citree_name} ->
              with :no_match <- try_exact(citree_name, lookups),
                   :no_match <- try_normalized(citree_name, lookups),
                   :no_match <- try_hybrid_agnostic(citree_name, lookups) do
                :no_match
              else
                {:ok, match} ->
                  {:ok, %{match | city_name: name, level: :synonym, citree_name: citree_name}}
              end

            nil ->
              :no_match
          end
        else
          :no_match
        end
    end
  end

  # Level 7: Manual direct Wikidata ID assignment
  defp try_manual(name, manual_ids) do
    case Map.fetch(manual_ids, name) do
      {:ok, wikidata_id} ->
        {:ok, %{city_name: name, wikidata_id: wikidata_id, level: :manual, citree_name: nil}}

      :error ->
        :no_match
    end
  end

  defp species_entry?(name), do: name =~ ~r/\bspecies\b/i

  # Build lookup maps from Citree entries
  defp build_lookups(citree_entries) do
    exact = build_exact_map(citree_entries)
    normalized = build_normalized_map(citree_entries)
    no_hybrid = build_no_hybrid_map(citree_entries)
    {base_species, base_no_hybrid} = build_base_species_maps(citree_entries)
    genus = build_genus_map(citree_entries)

    %{
      exact: exact,
      normalized: normalized,
      no_hybrid: no_hybrid,
      base_species: base_species,
      base_species_no_hybrid: base_no_hybrid,
      genus: genus
    }
  end

  defp build_exact_map(entries) do
    for entry <- entries, into: %{} do
      {entry.baumart_bo, {entry.wikidata_id, entry.baumart_bo}}
    end
  end

  defp build_normalized_map(entries) do
    entries
    |> Enum.reduce(%{}, fn entry, acc ->
      key = Normalizer.normalize(entry.baumart_bo)
      Map.put_new(acc, key, {entry.wikidata_id, entry.baumart_bo})
    end)
  end

  defp build_no_hybrid_map(entries) do
    entries
    |> Enum.reduce(%{}, fn entry, acc ->
      key = Normalizer.remove_hybrid(entry.baumart_bo)
      Map.put_new(acc, key, {entry.wikidata_id, entry.baumart_bo})
    end)
  end

  defp build_base_species_maps(entries) do
    Enum.reduce(entries, {%{}, %{}}, fn entry, {base_acc, base_nh_acc} ->
      stripped = Normalizer.strip_cultivar(entry.baumart_bo)

      if stripped == entry.baumart_bo do
        key = Normalizer.normalize(stripped)
        key_nh = Normalizer.remove_hybrid(stripped)

        {
          Map.put_new(base_acc, key, {entry.wikidata_id, entry.baumart_bo}),
          Map.put_new(base_nh_acc, key_nh, {entry.wikidata_id, entry.baumart_bo})
        }
      else
        {base_acc, base_nh_acc}
      end
    end)
  end

  defp build_genus_map(entries) do
    entries
    |> Enum.reduce(%{}, fn entry, acc ->
      parts = String.split(entry.baumart_bo, ~r/\s+/)

      if length(parts) == 1 do
        Map.put_new(acc, String.downcase(entry.baumart_bo), {entry.wikidata_id, entry.baumart_bo})
      else
        acc
      end
    end)
  end
end
