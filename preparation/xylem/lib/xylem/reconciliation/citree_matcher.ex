defmodule Xylem.Reconciliation.CitreeMatcher do
  @moduledoc """
  Matches Citree botanical tree names against the BaumBie/Wikidata reference
  mapping to assign Wikidata IDs.

  Uses a multi-level matching pipeline (first match wins):

  1. **Exact** - direct string match on `name_botanic`
  2. **Author-stripped** - strip taxonomic authors, then match
  3. **Normalized** - case, whitespace, quotes, subspecies notation (with author stripping)
  4. **Hybrid-agnostic** - ignore hybrid markers (`×`, `x`)
  5. **Infraspecific-stripped** - drop `subsp.`/`var.`/`f.` for base-species match
  6. **Synonym table** - explicit curated mappings (Citree → BaumBie)
  7. **Parenthetical synonym** - extract synonym from `(...)` in Citree entry, try matching
  8. **Manual** - direct Wikidata ID assignments from curated CSV

  Strains are preserved in the output but not used for matching (yet).
  """

  alias Xylem.Reconciliation.Normalizer

  @type match_result :: %{
          name_botanic: String.t(),
          strain: String.t() | nil,
          wikidata_id: String.t(),
          level: match_level(),
          baumart_bo: String.t() | nil
        }

  @type match_level ::
          :exact
          | :author_stripped
          | :normalized
          | :hybrid_agnostic
          | :infraspecific_stripped
          | :synonym
          | :parenthetical_synonym
          | :manual
          | :existing

  @type unmatched :: %{name_botanic: String.t(), strain: String.t() | nil, reason: :no_match}

  @doc """
  Runs the matching pipeline.

  ## Options

  - `:synonyms` - list of `%{name_botanic: String.t(), baumart_bo: String.t()}` mappings
  - `:manual_ids` - list of `%{name_botanic: String.t(), wikidata_id: String.t()}` direct assignments
  """
  @spec run([map()], [map()], keyword()) :: %{
          matches: [match_result()],
          unmatched: [unmatched()]
        }
  def run(citree_entries, baumbie_entries, opts \\ []) do
    lookups = build_lookups(baumbie_entries)
    synonyms = Keyword.get(opts, :synonyms, [])

    manual_ids =
      Keyword.get(opts, :manual_ids, []) |> Map.new(&{&1.name_botanic, &1.wikidata_id})

    {matches, unmatched} =
      Enum.reduce(citree_entries, {[], []}, fn entry, {matches, unmatched} ->
        name = entry.name_botanic
        strain = entry[:strain]
        existing_id = entry[:wikidata_id]

        cond do
          existing_id not in [nil, ""] ->
            match = %{
              name_botanic: name,
              strain: strain,
              wikidata_id: existing_id,
              level: :existing,
              baumart_bo: entry[:baumart_bo]
            }

            {[match | matches], unmatched}

          true ->
            case match_entry(name, lookups, synonyms, manual_ids) do
              {:ok, match} ->
                {[Map.put(match, :strain, strain) | matches], unmatched}

              :no_match ->
                {matches,
                 [%{name_botanic: name, strain: strain, reason: :no_match} | unmatched]}
            end
        end
      end)

    %{matches: Enum.reverse(matches), unmatched: Enum.reverse(unmatched)}
  end

  defp match_entry(name, lookups, synonyms, manual_ids) do
    with :no_match <- try_exact(name, lookups),
         :no_match <- try_author_stripped(name, lookups),
         :no_match <- try_normalized(name, lookups),
         :no_match <- try_hybrid_agnostic(name, lookups),
         :no_match <- try_infraspecific_stripped(name, lookups),
         :no_match <- try_synonym(name, lookups, synonyms),
         :no_match <- try_parenthetical_synonym(name, lookups),
         :no_match <- try_manual(name, manual_ids) do
      :no_match
    end
  end

  # Level 1: Exact match
  defp try_exact(name, %{exact: exact}) do
    lookup(exact, name, name, :exact)
  end

  # Level 2: Strip authors, exact match
  defp try_author_stripped(name, %{exact: exact}) do
    stripped = Normalizer.strip_authors(name)

    if stripped == name do
      :no_match
    else
      lookup(exact, stripped, name, :author_stripped)
    end
  end

  # Level 3: Strip authors + normalize
  defp try_normalized(name, %{normalized: normalized}) do
    key = name |> Normalizer.strip_authors() |> Normalizer.normalize()
    lookup(normalized, key, name, :normalized)
  end

  # Level 4: Strip authors + hybrid-agnostic
  defp try_hybrid_agnostic(name, %{no_hybrid: no_hybrid}) do
    key = name |> Normalizer.strip_authors() |> Normalizer.remove_hybrid()
    lookup(no_hybrid, key, name, :hybrid_agnostic)
  end

  # Level 5: Strip authors + strip infraspecific markers (subsp./var./f.)
  defp try_infraspecific_stripped(name, %{normalized: normalized}) do
    stripped = name |> Normalizer.strip_authors() |> drop_infraspecific()
    key = Normalizer.normalize(stripped)
    lookup(normalized, key, name, :infraspecific_stripped)
  end

  # Level 6: Synonym table — tries the input as-is and in several stripped forms,
  # so a synonym entry can use the canonical (author-free, infraspecific-free) name.
  defp try_synonym(name, lookups, synonyms) do
    author_stripped = Normalizer.strip_authors(name)

    candidates =
      [
        name,
        author_stripped,
        drop_infraspecific(author_stripped),
        Normalizer.strip_cultivar(name)
      ]
      |> Enum.uniq()

    Enum.find_value(candidates, :no_match, fn candidate ->
      case Enum.find(synonyms, &(&1.name_botanic == candidate)) do
        %{baumart_bo: baumart_bo} -> lookup_synonym_target(baumart_bo, name, lookups)
        nil -> nil
      end
    end)
  end

  # Level 7: Parenthetical synonym — extract synonym from (...) in Citree entry
  # and try matching it via the standard non-stripping levels.
  defp try_parenthetical_synonym(name, lookups) do
    candidates = parenthetical_synonym_candidates(name)

    Enum.find_value(candidates, :no_match, fn candidate ->
      case lookup_parenthetical_target(candidate, lookups) do
        {:ok, match} ->
          {:ok, %{match | name_botanic: name, level: :parenthetical_synonym, baumart_bo: candidate}}

        :no_match ->
          nil
      end
    end)
  end

  # Generate parenthetical synonym candidates from a Citree entry.
  # Extracts top-level parens, expands abbreviated genera, strips authors,
  # and keeps only binomial-like results.
  defp parenthetical_synonym_candidates(name) do
    full_genus = name |> String.split(~r/\s+/, parts: 2) |> List.first()

    name
    |> Normalizer.extract_top_level_parens()
    |> Enum.map(&expand_abbreviated_genus(&1, full_genus))
    |> Enum.map(&Normalizer.strip_authors/1)
    |> Enum.filter(&binomial_like?/1)
    |> Enum.uniq()
  end

  defp expand_abbreviated_genus(parenthetical, full_genus) do
    String.replace(parenthetical, ~r/^[A-Z]\.\s*/, full_genus <> " ")
  end

  defp binomial_like?(string) do
    case String.split(string, ~r/\s+/, trim: true) do
      [genus, species | _] ->
        String.match?(genus, ~r/^[A-Z][a-zA-ZäöüÄÖÜß]+$/) and
          String.match?(species, ~r/^([a-zäöüß]+|×|x)$/)

      _ ->
        false
    end
  end

  # Try matching the parenthetical candidate against BaumBie using only
  # the non-stripping levels (L1-L4) to avoid matching too aggressively.
  defp lookup_parenthetical_target(candidate, lookups) do
    with :no_match <- try_exact(candidate, lookups),
         :no_match <- try_normalized(candidate, lookups),
         :no_match <- try_hybrid_agnostic(candidate, lookups) do
      :no_match
    end
  end

  # Level 8: Manual direct Wikidata ID assignment
  defp try_manual(name, manual_ids) do
    case Map.fetch(manual_ids, name) do
      {:ok, wikidata_id} ->
        {:ok, %{name_botanic: name, wikidata_id: wikidata_id, level: :manual, baumart_bo: nil}}

      :error ->
        :no_match
    end
  end

  defp lookup(map, key, name_botanic, level) do
    case Map.fetch(map, key) do
      {:ok, {wikidata_id, baumart_bo}} ->
        {:ok,
         %{
           name_botanic: name_botanic,
           wikidata_id: wikidata_id,
           level: level,
           baumart_bo: baumart_bo
         }}

      :error ->
        :no_match
    end
  end

  defp lookup_synonym_target(baumart_bo, name_botanic, lookups) do
    with :no_match <- try_exact(baumart_bo, lookups),
         :no_match <- try_normalized(baumart_bo, lookups),
         :no_match <- try_hybrid_agnostic(baumart_bo, lookups) do
      :no_match
    else
      {:ok, match} ->
        {:ok, %{match | name_botanic: name_botanic, level: :synonym, baumart_bo: baumart_bo}}
    end
  end

  defp drop_infraspecific(string) do
    string
    |> String.replace(~r/\s+(subsp\.|ssp\.|var\.|f\.)\s+\S+/i, "")
    |> String.trim()
  end

  # Build lookup maps from BaumBie reference entries
  defp build_lookups(baumbie_entries) do
    %{
      exact: build_exact_map(baumbie_entries),
      normalized: build_normalized_map(baumbie_entries),
      no_hybrid: build_no_hybrid_map(baumbie_entries)
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
end