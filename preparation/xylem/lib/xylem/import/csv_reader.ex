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
    with {:ok, content} <- File.read(path),
         {:ok, species} <- parse(content) do
      {:ok, species}
    end
  end

  defp parse(content) do
    case Parser.parse_string(content, skip_headers: false) do
      [[header_bo, header_de, header_id] | rows] when is_binary(header_bo) ->
        case validate_headers(header_bo, header_de, header_id) do
          :ok -> {:ok, Enum.map(rows, &row_to_species/1)}
          error -> error
        end

      [] ->
        {:error, :empty_file}

      _other ->
        {:error, :invalid_csv_format}
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
    %{
      baumart_bo: String.trim(baumart_bo),
      baumart_de: String.trim(baumart_de),
      wikidata_id: String.trim(wikidata_id)
    }
  end

  defp row_to_species(_), do: raise("Invalid row format")
end
