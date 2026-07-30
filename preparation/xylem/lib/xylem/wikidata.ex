defmodule Xylem.Wikidata do
  @moduledoc """
  Shared Wikidata IRI constants and utilities.
  """

  @wikidata_base_url "https://www.wikidata.org/wiki/Special:EntityData"
  @wdt_prefix "http://www.wikidata.org/prop/direct/"
  @wd_prefix "http://www.wikidata.org/entity/"
  # Entity IDs are numbered from 1 upwards, so neither "Q0" nor a leading zero
  # can denote a real entity.
  @wikidata_id_pattern ~r/^Q[1-9][0-9]*$/

  def wdt_prefix, do: @wdt_prefix
  def wd_prefix, do: @wd_prefix

  @doc "Converts a wdt: property IRI to its wd: entity IRI for label lookup."
  def wdt_to_wd(iri), do: String.replace(iri, @wdt_prefix, @wd_prefix)

  @doc "Extracts the property ID (e.g., 'P225') from a wdt: IRI."
  def property_id(iri), do: String.replace_prefix(iri, @wdt_prefix, "")

  @doc "Extracts the entity ID (e.g., 'Q12345') from a wd: IRI."
  def entity_id(iri), do: String.replace_prefix(iri, @wd_prefix, "")

  @doc """
  Constructs the URL for a Wikidata entity's Turtle representation.

  Uses `uselang=de` so that referenced stub entities include German labels
  (with English fallback). The main entity always includes all languages.
  """
  def entity_url(wikidata_id), do: "#{@wikidata_base_url}/#{wikidata_id}.ttl?uselang=de"

  @doc "Returns whether `id` is a syntactically valid Wikidata entity ID."
  @spec valid_id?(term()) :: boolean()
  def valid_id?(id), do: is_binary(id) and Regex.match?(@wikidata_id_pattern, id)

  @doc "Validates a Wikidata ID (e.g., 'Q12345')."
  def validate_wikidata_id(id) do
    if valid_id?(id) do
      :ok
    else
      {:error, {:invalid_wikidata_id, id}}
    end
  end
end
