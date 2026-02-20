defmodule Xylem.Wikidata.PropertyConfig do
  @moduledoc """
  CSV-based configuration for Wikidata property handling.

  Reads a semicolon-separated CSV file that controls how each property
  is processed: kept as-is, ignored, or inlined from a secondary resource.

  ## CSV Format

      property_id;action;config;description
      P18;ignore;;Bild
      P105;inline;{"target": "taxonomischer_rang"};taxonomischer Rang

  Actions:
  - (empty) - property is kept unchanged
  - `ignore` - property is removed
  - `inline` - secondary resource is resolved and mapped to a new property

  The `config` field uses JSON and supports:
  - `target` (required for inline) - name of the new property in the BaumBie namespace
  - `source` (optional, default: `"rdfs:label"`) - property of the secondary resource to inline
  - `keep_source` (optional, default: `false`) - whether to keep the original link triple
  """

  NimbleCSV.define(__MODULE__.Parser, separator: ";", escape: "\0")

  alias __MODULE__.Parser

  @default_path "priv/config/wikidata_properties.csv"

  defstruct entries: %{}

  @type action :: :ignore | :inline | :keep
  @type inline_config :: %{
          target: String.t(),
          source: String.t(),
          keep_source: boolean()
        }
  @type entry :: %{
          action: action(),
          config: inline_config() | nil,
          description: String.t()
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
      parse(content)
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
  for any properties not yet in the configuration. New entries have no action
  or config, and use the provided labels map for descriptions.

  ## Options

  - `:labels` - map from property ID to label string (default: `%{}`)
  """
  @spec append_unknown(t(), Path.t(), [String.t()], keyword()) :: :ok | {:error, term()}
  def append_unknown(%__MODULE__{} = config, csv_path, property_ids, opts \\ []) do
    labels = Keyword.get(opts, :labels, %{})

    unknown_ids =
      property_ids
      |> Enum.uniq()
      |> Enum.reject(&known?(config, &1))
      |> Enum.sort()

    if unknown_ids == [] do
      :ok
    else
      lines = Enum.map(unknown_ids, fn id -> "#{id};;;#{labels[id]}" end)
      content = "\n" <> Enum.join(lines, "\n") <> "\n"
      File.write(csv_path, content, [:append])
    end
  end

  defp parse(content) do
    case Parser.parse_string(content, skip_headers: false) do
      [["property_id", "action", "config", "description"] | rows] ->
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

  defp parse_row([property_id, action_str, config_str, description]) do
    property_id = String.trim(property_id)

    if property_id != "" do
      action = parse_action(action_str)

      {property_id,
       %{
         action: action,
         config: parse_config(action, config_str),
         description: String.trim(description)
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
end
