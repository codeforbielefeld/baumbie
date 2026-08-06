defmodule Xylem.Import.CSVReader do
  @moduledoc """
  Reads tree species data from a CSV file.

  Expects columns:
  - `baumart_bo` (botanical name)
  - `baumart_de` (German name)
  - `wikidata_id` (Wikidata Q-ID)
  """

  NimbleCSV.define(__MODULE__.Parser, separator: ",", escape: "\"")

  alias __MODULE__.Parser
  alias Xylem.ImportInputError

  @type species :: %{
          baumart_bo: String.t(),
          baumart_de: String.t(),
          wikidata_id: String.t()
        }

  @doc """
  Reads and parses the CSV file at `path`.

  Returns `{:ok, species_list}` on success or `{:error, reason}` on failure.
  """
  @spec run(Path.t(), keyword()) :: {:ok, [species()]} | {:error, term()}
  def run(path, _opts \\ []) do
    case File.read(path) do
      {:ok, content} -> parse(content, path)
      {:error, reason} -> input_error(path, :file_read, reason)
    end
  end

  defp parse(content, path) do
    case Parser.parse_string(content, skip_headers: false) do
      [[header_bo, header_de, header_id] | rows] when is_binary(header_bo) ->
        case validate_headers(header_bo, header_de, header_id) do
          :ok -> parse_rows(rows, path)
          {:error, {:missing_column, column}} -> input_error(path, :missing_column, column, 1)
        end

      [] ->
        input_error(path, :empty_file)

      _other ->
        input_error(path, :invalid_csv_format)
    end
  rescue
    error in NimbleCSV.ParseError ->
      input_error(path, :invalid_csv_format, Exception.message(error))
  end

  defp parse_rows(rows, path) do
    rows
    |> Enum.with_index(2)
    |> Enum.reduce_while({:ok, []}, fn {row, line}, {:ok, species} ->
      case row_to_species(row) do
        {:ok, item} -> {:cont, {:ok, [item | species]}}
        :error -> {:halt, input_error(path, :invalid_row_format, nil, line)}
      end
    end)
    |> case do
      {:ok, species} -> {:ok, Enum.reverse(species)}
      {:error, _error} = error -> error
    end
  end

  defp validate_headers(bo, de, id) do
    cond do
      bo != "baumart_bo" -> {:error, {:missing_column, "baumart_bo"}}
      de != "baumart_de" -> {:error, {:missing_column, "baumart_de"}}
      id != "wikidata_id" -> {:error, {:missing_column, "wikidata_id"}}
      true -> :ok
    end
  end

  defp row_to_species([baumart_bo, baumart_de, wikidata_id | _rest]) do
    {:ok,
     %{
       baumart_bo: String.trim(baumart_bo),
       baumart_de: String.trim(baumart_de),
       wikidata_id: String.trim(wikidata_id)
     }}
  end

  defp row_to_species(_), do: :error

  defp input_error(path, reason, details \\ nil, line \\ nil) do
    {:error,
     %ImportInputError{
       source: :mapping_csv,
       path: path,
       reason: reason,
       details: details,
       line: line
     }}
  end
end
