defmodule Xylem.Wikidata do
  @moduledoc """
  Shared Wikidata IRI constants and utilities.
  """

  @wikidata_base_url "https://www.wikidata.org/wiki/Special:EntityData"
  @wdt_prefix "http://www.wikidata.org/prop/direct/"
  @wd_prefix "http://www.wikidata.org/entity/"
  @wikidata_id_pattern ~r/^Q\d+$/

  def wdt_prefix, do: @wdt_prefix
  def wd_prefix, do: @wd_prefix

  @doc "Converts a wdt: property IRI to its wd: entity IRI for label lookup."
  def wdt_to_wd(iri), do: String.replace(iri, @wdt_prefix, @wd_prefix)

  @doc "Extracts the property ID (e.g., 'P225') from a wdt: IRI."
  def property_id(iri), do: String.replace_prefix(iri, @wdt_prefix, "")

  @doc "Extracts the entity ID (e.g., 'Q12345') from a wd: IRI."
  def entity_id(iri), do: String.replace_prefix(iri, @wd_prefix, "")

  @doc "Constructs the URL for a Wikidata entity's Turtle representation."
  def entity_url(wikidata_id), do: "#{@wikidata_base_url}/#{wikidata_id}.ttl"

  @doc "Validates a Wikidata ID (e.g., 'Q12345')."
  def validate_wikidata_id(id) do
    if Regex.match?(@wikidata_id_pattern, id) do
      :ok
    else
      {:error, {:invalid_wikidata_id, id}}
    end
  end
end
