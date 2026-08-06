defmodule Xylem.BaumBie.Importer.TypeMapper do
  @moduledoc """
  Maps Wikidata datatypes to the BaumBie attribute type vocabulary.

  The BaumBie type is advisory metadata for consumers (LLM chat context,
  frontend rendering) — the value itself is always stored as TEXT. The
  vocabulary is a superset of the CitTree types `{string, number, boolean}`,
  so unknown types degrade gracefully to a text representation.
  """

  @type baumbie_type :: String.t()

  @known_datatypes ~w(WikibaseItem String Quantity Url GeoShape CommonsMedia)

  # CommonsMedia is not homogeneous: mostly images, but a few properties carry
  # audio. Until the export resolves file extensions (follow-up), we default to
  # `image` and override the known audio outlier P989.
  @audio_media_properties ~w(P989)

  @doc """
  Returns the BaumBie type for a Wikidata datatype.

  `property_id` disambiguates non-homogeneous datatypes (currently
  CommonsMedia audio via P989).
  """
  @spec map(String.t(), String.t()) :: baumbie_type()
  def map("WikibaseItem", _property_id), do: "string"
  def map("String", _property_id), do: "string"
  def map("Quantity", _property_id), do: "number"
  def map("Url", _property_id), do: "url"
  def map("GeoShape", _property_id), do: "geoshape"

  def map("CommonsMedia", property_id) do
    if property_id in @audio_media_properties, do: "audio", else: "image"
  end

  def map(_datatype, _property_id), do: "string"

  @doc "Distinguishes explicit mappings from the string fallback for preflight warnings."
  @spec known?(String.t()) :: boolean()
  def known?(datatype), do: datatype in @known_datatypes
end
