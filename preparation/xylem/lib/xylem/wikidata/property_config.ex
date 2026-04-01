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

  The `import` field uses JSON and controls Supabase import:
  - (empty) or `"skip"` - property is not imported
  - `group` (required) - name of the `tree_attribute_group`
  - `attribute_name` (optional) - overrides the attribute name (default: label from description)
  """

  NimbleCSV.define(__MODULE__.Parser, separator: ";", escape: "\"")

  alias __MODULE__.Parser

  @default_path "priv/config/wikidata_properties.csv"
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
          group: String.t(),
          attribute_name: String.t() | nil
        }
  @type entry :: %{
          type: String.t(),
          action: action(),
          config: inline_config() | nil,
          description: String.t(),
          import: import_config() | nil
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

    with {:ok, content} <- File.read(path) do
      content |> String.trim_leading(@bom) |> parse()
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

  defp parse(content) do
    case Parser.parse_string(content, skip_headers: false) do
      [["property_id", "type", "action", "config", "description", "import"] | rows] ->
        entries =
          rows
          |> Enum.map(&parse_row/1)
          |> Enum.reject(&is_nil/1)
          |> Map.new()

        {:ok, %__MODULE__{entries: entries}}

      [] ->
        {:ok, %__MODULE__{entries: %{}}}

      _other ->
        {:error, :invalid_csv_format}
    end
  end

  defp parse_row([property_id, type, action_str, config_str, description, import_str]) do
    property_id = String.trim(property_id)

    if property_id != "" do
      action = parse_action(action_str)

      {property_id,
       %{
         type: String.trim(type),
         action: action,
         config: parse_config(action, config_str),
         description: String.trim(description),
         import: parse_import(import_str)
       }}
    end
  end

  defp parse_row(_), do: nil

  defp parse_action(str) do
    case String.trim(str) do
      "ignore" -> :ignore
      "inline" -> :inline
      _ -> :keep
    end
  end

  defp parse_config(:inline, config_str) do
    config_str = String.trim(config_str)

    if config_str == "" do
      raise ArgumentError, "inline action requires a config with at least a \"target\" key"
    end

    case Jason.decode(config_str) do
      {:ok, map} when is_map(map) ->
        unless Map.has_key?(map, "target") do
          raise ArgumentError, "inline config must have a \"target\" key, got: #{config_str}"
        end

        %{
          target: Map.fetch!(map, "target"),
          source: Map.get(map, "source", "rdfs:label"),
          keep_source: Map.get(map, "keep_source", false)
        }

      _ ->
        raise ArgumentError,
              "inline config must be valid JSON with a \"target\" key, got: #{config_str}"
    end
  end

  defp parse_config(_action, _config_str), do: nil

  defp parse_import(str) do
    case String.trim(str) do
      "" ->
        nil

      "skip" ->
        nil

      json ->
        case Jason.decode(json) do
          {:ok, %{"group" => group} = map} when is_binary(group) ->
            %{
              group: group,
              attribute_name: Map.get(map, "attribute_name")
            }

          _ ->
            raise ArgumentError,
                  "import config must be valid JSON with a \"group\" key, got: #{json}"
        end
    end
  end
end
