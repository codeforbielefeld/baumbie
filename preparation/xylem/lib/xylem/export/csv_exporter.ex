defmodule Xylem.Export.CSVExporter do
  @moduledoc """
  Exports processed Wikidata data to a flat review CSV for manual inspection.

  Reads processed TTL files and property config to generate a semicolon-separated
  CSV with one row per property value per target.

  Iterating validated targets rather than raw mapping rows is what keeps the
  export free of duplicates: a QID serving several tree types contributes its
  values to each of them exactly once.

  The mapping is validated before the output path is touched, and rows are
  written to a temporary file that only replaces the previous export once the
  run has completed — a failure never truncates a reviewed CSV.

  ## Options

  - `:csv_path` - path to input species CSV (default: `priv/data/baumbie_wikidata_mapping.csv`)
  - `:property_config_path` - path to property config CSV (default: `priv/config/wikidata_properties.csv`)
  - `:processed_dir` - directory of processed .ttl files (default: `priv/cache/wikidata/processed`)
  - `:output_path` - output CSV path (default: `priv/data/wikidata/export.csv`)
  - `:limit` - limit number of targets to export
  """

  require Logger

  alias Xylem.Import.Mapping
  alias Xylem.ImportInputError
  alias Xylem.Wikidata
  alias Xylem.Wikidata.{Processor, PropertyConfig}

  alias RDF.NS.RDFS
  alias RDF.XSD

  @default_output_path "priv/data/wikidata/export.csv"
  @csv_header "wikidata_id;baumart_bo;baumart_de;property_id;attribute_name;value;group\n"

  @type summary :: %{
          species_count: non_neg_integer(),
          row_count: non_neg_integer(),
          missing_processed: non_neg_integer(),
          output: Path.t()
        }

  @spec run(keyword()) :: {:ok, summary()} | {:error, term()}
  def run(opts \\ []) do
    csv_path = Keyword.get(opts, :csv_path, Xylem.default_csv_path())
    config_path = Keyword.get(opts, :property_config_path, PropertyConfig.default_path())
    processed_dir = Keyword.get(opts, :processed_dir, Processor.default_processed_dir())
    output_path = Keyword.get(opts, :output_path, @default_output_path)

    with {:ok, config} <- PropertyConfig.load(path: config_path),
         {:ok, mapping} <- Mapping.load(csv_path) do
      Mapping.log_warnings(mapping)

      targets = maybe_limit(Mapping.targets(mapping), opts[:limit])
      importable = PropertyConfig.importable_entries(config)

      Logger.info(
        "Exporting #{length(targets)} targets, #{length(importable)} importable properties"
      )

      write_export(targets, processed_dir, output_path, importable, config)
    end
  end

  defp write_export(targets, processed_dir, output_path, importable, config) do
    File.mkdir_p!(Path.dirname(output_path))
    tmp_path = "#{output_path}.#{:erlang.unique_integer([:positive])}.tmp"

    # The rows are built as iodata and written in one checked call: a streaming
    # writer would have to inspect every `IO.write/2` and the final flush, and a
    # single missed error would publish a truncated review CSV.
    with {:ok, iodata, stats} <- build_rows(targets, processed_dir, importable, config),
         :ok <- File.write(tmp_path, iodata),
         :ok <- File.rename(tmp_path, output_path) do
      Logger.info(
        "Exported #{stats.row_count} rows for #{stats.species_count} targets to #{output_path}"
      )

      if stats.missing_processed > 0 do
        Logger.warning("#{stats.missing_processed} entities had no processed file")
      end

      {:ok, Map.put(stats, :output, output_path)}
    else
      {:error, reason} ->
        File.rm(tmp_path)
        {:error, reason}
    end
  end

  defp build_rows(targets, processed_dir, importable, config) do
    with {:ok, graphs, missing} <- load_graphs(targets, processed_dir) do
      {iodata, species_count, row_count} =
        Enum.reduce(targets, {[@csv_header], 0, 0}, fn target, {acc, sc, rc} ->
          case Map.fetch(graphs, target.wikidata_id) do
            {:ok, graph} ->
              rows = export_species(target, graph, importable, config)
              {[acc, rows], sc + 1, rc + length(rows)}

            :error ->
              {acc, sc, rc}
          end
        end)

      {:ok, iodata,
       %{
         species_count: species_count,
         row_count: row_count,
         missing_processed: MapSet.size(missing)
       }}
    end
  end

  # Each entity is read once, no matter how many targets it serves.
  defp load_graphs(targets, processed_dir) do
    targets
    |> Enum.map(& &1.wikidata_id)
    |> Enum.uniq()
    |> Enum.reduce_while({:ok, %{}, MapSet.new()}, fn wikidata_id, {:ok, graphs, missing} ->
      path = Path.join(processed_dir, "#{wikidata_id}.ttl")

      case RDF.Turtle.read_file(path) do
        {:ok, graph} ->
          {:cont, {:ok, Map.put(graphs, wikidata_id, graph), missing}}

        {:error, :enoent} ->
          Logger.warning("No processed file for #{wikidata_id}, skipping")
          {:cont, {:ok, graphs, MapSet.put(missing, wikidata_id)}}

        {:error, reason} ->
          {:halt, read_error(path, reason)}
      end
    end)
  end

  defp read_error(path, reason) do
    details = if is_exception(reason), do: Exception.message(reason), else: inspect(reason)

    {:error,
     %ImportInputError{
       source: :processed_ttl,
       path: path,
       reason: :invalid_turtle,
       details: details
     }}
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

        # The values are sorted because the export is versioned: their natural
        # order comes from the RDF description and may reshuffle when a single
        # value is added upstream, which would bury the real change in noise.
        description
        |> extract_values(property_id, entry, graph)
        |> Enum.sort()
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
