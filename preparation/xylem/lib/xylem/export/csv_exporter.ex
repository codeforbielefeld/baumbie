defmodule Xylem.Export.CSVExporter do
  @moduledoc """
  Exports processed Wikidata data to a flat review CSV for manual inspection.

  Reads processed TTL files and property config to generate a semicolon-separated
  CSV with one row per property value per species.

  ## Options

  - `:csv_path` - path to input species CSV (default: `priv/data/baumbie_wikidata_mapping.csv`)
  - `:property_config_path` - path to property config CSV (default: `priv/config/wikidata_properties.csv`)
  - `:processed_dir` - directory of processed .ttl files (default: `priv/data/wikidata/processed`)
  - `:output_path` - output CSV path (default: `priv/data/wikidata/export.csv`)
  - `:limit` - limit number of species to export
  """

  require Logger

  alias Xylem.Import.CSVReader
  alias Xylem.Wikidata
  alias Xylem.Wikidata.{Processor, PropertyConfig}

  alias RDF.NS.RDFS
  alias RDF.XSD

  @default_output_path "priv/data/wikidata/export.csv"
  @csv_header "wikidata_id;baumart_bo;baumart_de;property_id;attribute_name;value;group\n"

  @spec run(keyword()) ::
          {:ok,
           %{species_count: non_neg_integer(), row_count: non_neg_integer(), output: Path.t()}}
          | {:error, term()}
  def run(opts \\ []) do
    csv_path = Keyword.get(opts, :csv_path, Xylem.default_csv_path())
    config_path = Keyword.get(opts, :property_config_path, PropertyConfig.default_path())
    processed_dir = Keyword.get(opts, :processed_dir, Processor.default_processed_dir())
    output_path = Keyword.get(opts, :output_path, @default_output_path)

    with {:ok, config} <- PropertyConfig.load(path: config_path),
         {:ok, species_list} <- CSVReader.run(csv_path) do
      species_list = maybe_limit(species_list, opts[:limit])
      importable = PropertyConfig.importable_entries(config)

      Logger.info(
        "Exporting #{length(species_list)} species, #{length(importable)} importable properties"
      )

      File.mkdir_p!(Path.dirname(output_path))
      file = File.open!(output_path, [:write, :utf8])
      IO.write(file, @csv_header)

      {species_count, row_count} =
        Enum.reduce(species_list, {0, 0}, fn species, {sc, rc} ->
          ttl_path = Path.join(processed_dir, "#{species.wikidata_id}.ttl")

          if File.exists?(ttl_path) do
            graph = RDF.Turtle.read_file!(ttl_path)
            rows = export_species(species, graph, importable, config)
            Enum.each(rows, &IO.write(file, &1))
            {sc + 1, rc + length(rows)}
          else
            Logger.warning("No processed file for #{species.wikidata_id}, skipping")
            {sc, rc}
          end
        end)

      File.close(file)

      Logger.info("Exported #{row_count} rows for #{species_count} species to #{output_path}")
      {:ok, %{species_count: species_count, row_count: row_count, output: output_path}}
    end
  end

  defp maybe_limit(list, nil), do: list
  defp maybe_limit(list, n), do: Enum.take(list, n)

  defp export_species(species, graph, importable_props, config) do
    subject = RDF.iri("#{Wikidata.wd_prefix()}#{species.wikidata_id}")
    description = RDF.Graph.get(graph, subject)

    if description do
      Enum.flat_map(importable_props, fn {property_id, entry} ->
        attr_name = PropertyConfig.attribute_name(config, property_id)
        group = PropertyConfig.import_group(config, property_id)

        description
        |> extract_values(property_id, entry, graph)
        |> Enum.map(&format_row(species, property_id, attr_name, &1, group))
      end)
    else
      []
    end
  end

  defp extract_values(description, property_id, entry, graph) do
    case entry.action do
      :inline -> extract_inline_values(description, entry.config.target)
      _keep -> extract_direct_values(description, property_id, graph)
    end
  end

  # Inline properties: values from baumbie:{target}, already resolved labels.
  # Take all values and strip language tags.
  defp extract_inline_values(description, target) do
    predicate = RDF.iri("#{Xylem.baumbie_prefix()}#{target}")

    if objects = RDF.Description.get(description, predicate) do
      Enum.map(objects, &literal_to_string/1)
    else
      []
    end
  end

  # Keep properties: values from wdt:{property_id}, need resolution.
  defp extract_direct_values(description, property_id, graph) do
    predicate = RDF.iri("#{Wikidata.wdt_prefix()}#{property_id}")

    if objects = RDF.Description.get(description, predicate) do
      {iris, literals} = Enum.split_with(objects, &match?(%RDF.IRI{}, &1))
      iri_values = Enum.flat_map(iris, &resolve_iri_label(&1, graph))
      literal_values = resolve_literals(literals)

      iri_values ++ literal_values
    else
      []
    end
  end

  # For wd: IRIs, resolve rdfs:label (de preferred, en fallback).
  # For other IRIs (commons images, external URLs), use the URL as value.
  defp resolve_iri_label(iri, graph) do
    iri_string = to_string(iri)

    if String.starts_with?(iri_string, Wikidata.wd_prefix()) do
      with labels when not is_nil(labels) <-
             graph |> RDF.Graph.description(iri) |> RDF.Description.get(RDFS.label()),
           value when not is_nil(value) <-
             find_preferred_label(labels) do
        [value]
      else
        _ ->
          Logger.warning("No label found for #{iri}")
          []
      end
    else
      [iri_string]
    end
  end

  defp find_preferred_label(labels) do
    find_by_language(labels, "de") ||
      find_by_language(labels, nil) ||
      find_by_language(labels, "en")
  end

  defp find_by_language(labels, nil) do
    Enum.find_value(labels, fn
      %RDF.Literal{literal: %XSD.String{value: value}} -> value
      _ -> nil
    end)
  end

  defp find_by_language(labels, lang) do
    Enum.find_value(labels, fn
      %RDF.Literal{literal: %RDF.LangString{language: ^lang, value: value}} -> value
      _ -> nil
    end)
  end

  # For language-tagged literals: take all @de; if none, take all @en. Strip tags.
  # For plain/typed literals: use value directly.
  defp resolve_literals(literals) do
    {lang_tagged, plain} =
      Enum.split_with(literals, &match?(%RDF.Literal{literal: %RDF.LangString{}}, &1))

    lang_values = resolve_lang_tagged(lang_tagged)
    plain_values = Enum.map(plain, &literal_to_string/1)

    lang_values ++ plain_values
  end

  defp resolve_lang_tagged([]), do: []

  defp resolve_lang_tagged(literals) do
    de_values =
      for %RDF.Literal{literal: %RDF.LangString{language: "de", value: v}} <- literals, do: v

    if de_values != [] do
      de_values
    else
      for %RDF.Literal{literal: %RDF.LangString{language: "en", value: v}} <- literals, do: v
    end
  end

  defp literal_to_string(%RDF.Literal{literal: %RDF.LangString{value: value}}), do: value
  defp literal_to_string(%RDF.Literal{} = literal), do: to_string(RDF.Literal.value(literal))
  defp literal_to_string(other), do: to_string(other)

  defp format_row(species, property_id, attr_name, value, group) do
    [
      species.wikidata_id,
      species.baumart_bo,
      species.baumart_de,
      property_id,
      attr_name || "",
      value,
      group
    ]
    |> Enum.map_join(";", &escape_csv_field/1)
    |> Kernel.<>("\n")
  end

  defp escape_csv_field(value) when is_binary(value) do
    if String.contains?(value, [";", "\"", "\n"]) do
      "\"" <> String.replace(value, "\"", "\"\"") <> "\""
    else
      value
    end
  end

  defp escape_csv_field(value), do: to_string(value)
end
