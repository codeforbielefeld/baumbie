defmodule Xylem.Wikidata.PropertyConfig do
  @moduledoc """
  CSV-based configuration for Wikidata property handling.

  Reads a semicolon-separated CSV file that controls how each property
  is processed: kept as-is, ignored, or inlined from a secondary resource.

  ## CSV Format

      property_id;type;action;config;description;import
      P18;CommonsMedia;ignore;;Bild;
      P105;WikibaseItem;inline;"{""target"": ""taxonomischer_rang""}";taxonomischer Rang;
      P141;WikibaseItem;;;;"{""group"": ""Gefährdung""}"

  Actions:
  - (empty) - property is kept unchanged
  - `ignore` - property is removed
  - `inline` - secondary resource is resolved and mapped to a new property

  The `config` field uses JSON and supports:
  - `target` (required for inline) - name of the new property in the BaumBie namespace
  - `source` (optional, default: `"rdfs:label"`) - property of the secondary resource to inline
  - `keep_source` (optional, default: `false`) - whether to keep the original link triple

  The `import` field controls Supabase import:
  - (empty) - import with defaults
  - `skip` - do not import
  - JSON object with optional `group` and/or `attribute_name` overrides
  """

  NimbleCSV.define(__MODULE__.Parser, separator: ";", escape: "\"")

  alias __MODULE__.Parser
  alias Xylem.ImportInputError

  @default_path "priv/config/wikidata_properties.csv"
  def default_path, do: @default_path

  @csv_header "property_id;type;action;config;description;import\n"
  @bom "\uFEFF"

  defstruct entries: %{}

  @type action :: :ignore | :inline | :keep
  @type inline_config :: %{
          target: String.t(),
          source: String.t(),
          keep_source: boolean()
        }
  @type import_config :: %{
          group: String.t() | nil,
          attribute_name: String.t() | nil
        }
  @type entry :: %{
          type: String.t(),
          action: action(),
          config: inline_config() | nil,
          description: String.t(),
          import: import_config() | :skip | nil
        }
  @type t :: %__MODULE__{entries: %{String.t() => entry()}}

  @doc """
  Loads property configuration from a CSV file.

  ## Options

  - `:path` - path to the CSV file (default: `#{@default_path}`)
  """
  @spec load(keyword()) :: {:ok, t()} | {:error, term()}
  def load(opts \\ []) do
    path = Keyword.get(opts, :path, @default_path)

    case File.read(path) do
      {:ok, content} -> content |> String.trim_leading(@bom) |> parse(path)
      {:error, reason} -> input_error(path, :file_read, reason)
    end
  end

  @doc "Returns whether the given property should be ignored."
  @spec ignored?(t(), String.t()) :: boolean()
  def ignored?(%__MODULE__{entries: entries}, property_id) do
    case Map.get(entries, property_id) do
      %{action: :ignore} -> true
      _ -> false
    end
  end

  @doc "Returns the inline configuration for a property, or `nil` if not an inline property."
  @spec inline_config(t(), String.t()) :: inline_config() | nil
  def inline_config(%__MODULE__{entries: entries}, property_id) do
    case Map.get(entries, property_id) do
      %{action: :inline, config: config} -> config
      _ -> nil
    end
  end

  @doc "Returns the import configuration for a property, or `nil` if not configured for import."
  @spec import_config(t(), String.t()) :: import_config() | nil
  def import_config(%__MODULE__{entries: entries}, property_id) do
    case Map.get(entries, property_id) do
      %{import: %{} = config} -> config
      _ -> nil
    end
  end

  @doc "Returns whether the property is importable (not skipped, not ignored, and known)."
  @spec importable?(t(), String.t()) :: boolean()
  def importable?(%__MODULE__{entries: entries}, property_id) do
    entries |> Map.get(property_id) |> importable_entry?()
  end

  defp importable_entry?(%{import: :skip}), do: false
  defp importable_entry?(%{action: :ignore}), do: false
  defp importable_entry?(%{}), do: true
  defp importable_entry?(_), do: false

  @doc "Returns all importable property entries as a sorted list of `{property_id, entry}` tuples."
  @spec importable_entries(t()) :: [{String.t(), entry()}]
  def importable_entries(%__MODULE__{entries: entries}) do
    entries
    |> Enum.filter(fn {_id, entry} -> importable_entry?(entry) end)
    |> Enum.sort_by(fn {id, _} -> id end)
  end

  @doc "Returns the attribute name for a property."
  @spec attribute_name(t(), String.t()) :: String.t() | nil
  def attribute_name(%__MODULE__{entries: entries}, property_id) do
    case Map.get(entries, property_id) do
      %{import: %{attribute_name: name}} when is_binary(name) -> name
      %{action: :inline, config: %{target: target}} -> target
      # TODO: Das Label ist nur temporär in der Metadata-Map während append_unknown verfügbar
      # und wird dort in die Description eingebaut ("label – beschreibung"), aber nicht separat
      # gespeichert. Daher parsen wir es hier zurück. Sauberer wäre eine eigene label-Spalte
      # in der CSV, damit das Label direkt als Feld in der Entry zur Verfügung steht.
      %{description: desc} when desc != "" -> normalize_target(description_label(desc))
      _ -> nil
    end
  end

  defp description_label(description) do
    description |> String.split(" – ", parts: 2) |> hd() |> String.trim()
  end

  @doc "Returns the import group for a property, or empty string if not configured."
  @spec import_group(t(), String.t()) :: String.t()
  def import_group(%__MODULE__{entries: entries}, property_id) do
    case Map.get(entries, property_id) do
      %{import: %{group: group}} when is_binary(group) -> group
      _ -> ""
    end
  end

  @doc "Returns whether the given property has an entry in the configuration."
  @spec known?(t(), String.t()) :: boolean()
  def known?(%__MODULE__{entries: entries}, property_id) do
    Map.has_key?(entries, property_id)
  end

  @doc "Returns all configured property IDs."
  @spec all_property_ids(t()) :: [String.t()]
  def all_property_ids(%__MODULE__{entries: entries}) do
    Map.keys(entries)
  end

  @doc """
  Appends unknown property IDs to the CSV file.

  Compares the given property IDs with the loaded config and appends rows
  for any properties not yet in the configuration. Uses metadata from the
  vocabulary file to populate type and description.

  ## Options

  - `:metadata` - map from property ID to `%{type: String.t(), description: String.t()}`
    (default: `%{}`)
  """
  @spec append_unknown(t(), Path.t(), [String.t()], keyword()) :: :ok | {:error, term()}
  def append_unknown(%__MODULE__{} = config, csv_path, property_ids, opts \\ []) do
    metadata = Keyword.get(opts, :metadata, %{})

    unknown_ids =
      property_ids
      |> Enum.uniq()
      |> Enum.reject(&known?(config, &1))
      |> Enum.sort()

    if unknown_ids == [] do
      :ok
    else
      ensure_csv_file(csv_path)
      existing = File.read!(csv_path)
      prefix = if String.ends_with?(existing, "\n"), do: "", else: "\n"

      content =
        prefix <>
          Enum.map_join(unknown_ids, "\n", &build_line(&1, Map.get(metadata, &1, %{}))) <>
          "\n"

      File.write(csv_path, content, [:append])
    end
  end

  defp build_line(id, %{type: "WikibaseItem"} = meta) do
    label = Map.get(meta, :label)
    target = if label, do: normalize_target(label), else: String.downcase(id)
    config = ~s({"target": "#{target}", "keep_source": true}) |> quote_csv_field()
    description = meta |> Map.get(:description, "") |> quote_csv_field()
    "#{id};WikibaseItem;inline;#{config};#{description};"
  end

  defp build_line(id, %{type: "ExternalId"} = meta) do
    description = meta |> Map.get(:description, "") |> quote_csv_field()
    "#{id};ExternalId;;;#{description};skip"
  end

  defp build_line(id, meta) do
    type = Map.get(meta, :type, "")
    description = meta |> Map.get(:description, "") |> quote_csv_field()
    "#{id};#{type};;;#{description};"
  end

  @doc false
  def normalize_target(label) do
    label
    |> String.downcase()
    |> String.replace("ä", "ae")
    |> String.replace("ö", "oe")
    |> String.replace("ü", "ue")
    |> String.replace("ß", "ss")
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/[\s-]+/, "_")
    |> String.replace(~r/_+/, "_")
    |> String.trim("_")
  end

  defp ensure_csv_file(csv_path) do
    unless File.exists?(csv_path) do
      File.mkdir_p!(Path.dirname(csv_path))
      File.write!(csv_path, @bom <> @csv_header)
    end
  end

  defp quote_csv_field(""), do: ""

  defp quote_csv_field(value) do
    if String.contains?(value, ["\"", ";"]) do
      "\"" <> String.replace(value, "\"", "\"\"") <> "\""
    else
      value
    end
  end

  defp parse(content, path) do
    case Parser.parse_string(content, skip_headers: false) do
      [["property_id", "type", "action", "config", "description", "import"] | rows] ->
        parse_rows(rows, path)

      [] ->
        {:ok, %__MODULE__{entries: %{}}}

      _other ->
        input_error(path, :invalid_csv_format, nil, 1)
    end
  rescue
    error in NimbleCSV.ParseError ->
      input_error(path, :invalid_csv_format, Exception.message(error))
  end

  defp parse_rows(rows, path) do
    rows
    |> Enum.with_index(2)
    |> Enum.reduce_while({:ok, %{}}, fn {row, line}, {:ok, entries} ->
      case parse_row(row, path, line) do
        {:ok, nil} -> {:cont, {:ok, entries}}
        {:ok, {property_id, entry}} -> {:cont, {:ok, Map.put(entries, property_id, entry)}}
        {:error, _error} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, entries} -> {:ok, %__MODULE__{entries: entries}}
      {:error, _error} = error -> error
    end
  end

  defp parse_row([property_id, type, action_str, config_str, description, import_str], path, line) do
    property_id = String.trim(property_id)

    if property_id == "" do
      {:ok, nil}
    else
      action = parse_action(action_str)

      with {:ok, config} <- parse_config(action, config_str, path, line),
           {:ok, import} <- parse_import(import_str, path, line) do
        {:ok,
         {property_id,
          %{
            type: String.trim(type),
            action: action,
            config: config,
            description: String.trim(description),
            import: import
          }}}
      end
    end
  end

  defp parse_row(_row, path, line), do: input_error(path, :invalid_row_format, nil, line)

  defp parse_action(str) do
    case String.trim(str) do
      "ignore" -> :ignore
      "inline" -> :inline
      _ -> :keep
    end
  end

  defp parse_config(:inline, config_str, path, line) do
    config_str = String.trim(config_str)

    if config_str == "" do
      input_error(path, :invalid_inline_config, config_str, line)
    else
      case Jason.decode(config_str) do
        {:ok, %{"target" => target} = map} when is_binary(target) ->
          {:ok,
           %{
             target: target,
             source: Map.get(map, "source", "rdfs:label"),
             keep_source: Map.get(map, "keep_source", false)
           }}

        _ ->
          input_error(path, :invalid_inline_config, config_str, line)
      end
    end
  end

  defp parse_config(_action, _config_str, _path, _line), do: {:ok, nil}

  defp parse_import(str, path, line) do
    case String.trim(str) do
      "" ->
        {:ok, nil}

      "skip" ->
        {:ok, :skip}

      json ->
        case Jason.decode(json) do
          {:ok, map} when is_map(map) ->
            group = Map.get(map, "group")
            attribute_name = Map.get(map, "attribute_name")

            if optional_string?(group) and optional_string?(attribute_name) do
              {:ok, %{group: group, attribute_name: attribute_name}}
            else
              input_error(path, :invalid_import_config, json, line)
            end

          _ ->
            input_error(path, :invalid_import_config, json, line)
        end
    end
  end

  defp optional_string?(value), do: is_nil(value) or is_binary(value)

  defp input_error(path, reason, details, line \\ nil) do
    {:error,
     %ImportInputError{
       source: :property_config,
       path: path,
       reason: reason,
       details: details,
       line: line
     }}
  end
end
