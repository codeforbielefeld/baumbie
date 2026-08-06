defmodule Xylem.BaumBie.Importer.AttributeWriter do
  @moduledoc """
  Builds the `tree_type_attributes` and `tree_type_attribute_values` rows for
  the Wikidata import.

  Pure row builders only — the actual upserts, deletes and batch inserts are
  orchestrated in `Xylem.BaumBie.Importer`, which owns the UUID caches.
  """

  alias Xylem.BaumBie.Importer.TypeMapper
  alias Xylem.Wikidata.PropertyConfig

  @doc """
  Builds a `tree_type_attributes` upsert row for a property.

  The BaumBie `type` is derived from the property's Wikidata datatype
  (`entry.type`); `provider_attribute_id` is always the original Wikidata
  property ID, and the group stays `NULL` (ungrouped first pass).
  """
  @spec build_attribute_row(String.t(), String.t(), PropertyConfig.entry(), String.t()) :: map()
  def build_attribute_row(property_id, attribute_name, entry, provider_uuid) do
    %{
      "name" => attribute_name,
      "description" => entry.description,
      "type" => TypeMapper.map(entry.type, property_id),
      "provider_uuid" => provider_uuid,
      "provider_attribute_id" => property_id,
      "tree_type_attribute_group_uuid" => nil
    }
  end

  @doc """
  Builds a denormalized `tree_type_attribute_values` insert row.

  `unit` stays `NULL` until the export carries Wikidata quantity units.
  """
  @spec build_value_row(map(), String.t(), String.t(), String.t()) :: map()
  def build_value_row(review_row, tree_type_uuid, attribute_uuid, type) do
    %{
      "tree_type_uuid" => tree_type_uuid,
      "tree_type_attribute_uuid" => attribute_uuid,
      "type" => type,
      "value" => review_row.value,
      "unit" => nil
    }
  end
end
