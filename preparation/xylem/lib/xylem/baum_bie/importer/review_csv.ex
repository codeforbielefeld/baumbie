defmodule Xylem.BaumBie.Importer.ReviewCSV do
  @moduledoc """
  Reads the flat review CSV produced by `mix xylem.export`.

  Semicolon-separated, with columns:
  `wikidata_id;baumart_bo;baumart_de;property_id;attribute_name;value;group`

  One row per property value per species. `group` is retained for the deferred
  DB-group assignment but is not written by the current importer.
  """

  NimbleCSV.define(__MODULE__.Parser, separator: ";", escape: "\"")

  alias __MODULE__.Parser
  alias Xylem.ImportInputError

  @header [
    "wikidata_id",
    "baumart_bo",
    "baumart_de",
    "property_id",
    "attribute_name",
    "value",
    "group"
  ]

  @type row :: %{
          wikidata_id: String.t(),
          baumart_bo: String.t(),
          baumart_de: String.t(),
          property_id: String.t(),
          attribute_name: String.t(),
          value: String.t(),
          group: String.t()
        }

  @doc """
  Reads and parses the review CSV at `path`.

  Returns `{:ok, rows}` on success or `{:error, reason}` on failure.
  """
  @spec run(Path.t(), keyword()) :: {:ok, [row()]} | {:error, term()}
  def run(path, _opts \\ []) do
    case File.read(path) do
      {:ok, content} -> parse(content, path)
      {:error, reason} -> input_error(path, :file_read, reason)
    end
  end

  defp parse(content, path) do
    case Parser.parse_string(content, skip_headers: false) do
      [@header | rows] -> parse_rows(rows, path)
      [] -> input_error(path, :empty_file)
      _other -> input_error(path, :invalid_csv_format)
    end
  rescue
    error in NimbleCSV.ParseError ->
      input_error(path, :invalid_csv_format, Exception.message(error))
  end

  defp parse_rows(rows, path) do
    rows
    |> Enum.with_index(2)
    |> Enum.reduce_while({:ok, []}, fn {row, line}, {:ok, parsed} ->
      case row_to_map(row) do
        {:ok, item} -> {:cont, {:ok, [item | parsed]}}
        :error -> {:halt, input_error(path, :invalid_row_format, nil, line)}
      end
    end)
    |> case do
      {:ok, rows} -> {:ok, Enum.reverse(rows)}
      {:error, _error} = error -> error
    end
  end

  defp row_to_map([
         wikidata_id,
         baumart_bo,
         baumart_de,
         property_id,
         attribute_name,
         value,
         group | _rest
       ]) do
    {:ok,
     %{
       wikidata_id: String.trim(wikidata_id),
       baumart_bo: String.trim(baumart_bo),
       baumart_de: String.trim(baumart_de),
       property_id: String.trim(property_id),
       attribute_name: String.trim(attribute_name),
       value: value,
       group: String.trim(group)
     }}
  end

  defp row_to_map(_), do: :error

  defp input_error(path, reason, details \\ nil, line \\ nil) do
    {:error,
     %ImportInputError{
       source: :review_csv,
       path: path,
       reason: reason,
       details: details,
       line: line
     }}
  end
end
