defmodule Xylem.Import.Mapping do
  @moduledoc """
  Validated identity for the species mapping.

  The pipeline has to keep two identities apart:

  - the **entity** (`wikidata_id`) drives fetch, processing and the raw and
    processed file names
  - the **target** (`baumart_bo` → `tree_type`) drives export and import

  Conflating them is what multiplied the export: iterating raw mapping rows
  re-emits a QID's full value set once per row. One QID may legitimately serve
  several targets (cultivars falling back to their parent species), but it must
  be fetched and processed only once, and contribute to each target only once.

  Names are compared through `canonical_name/1` so that pure spelling
  differences — double spaces, cultivar quote variants — neither create a second
  identity nor break a join.
  """

  require Logger

  alias Xylem.Import.CSVReader
  alias Xylem.ImportPreflightError
  alias Xylem.MappingValidationError
  alias Xylem.Reconciliation.Normalizer
  alias Xylem.Wikidata

  @type target :: %{
          baumart_bo: String.t(),
          baumart_de: String.t(),
          wikidata_id: String.t(),
          line: pos_integer()
        }

  @typedoc """
  One entry per distinct `wikidata_id`.

  `baumart_bo` and `baumart_de` are the first-seen representative of that QID
  and serve logging only — the processed output depends solely on the QID, the
  raw graph and the property config.
  """
  @type entity :: %{baumart_bo: String.t(), baumart_de: String.t(), wikidata_id: String.t()}

  @enforce_keys [:targets, :entities, :warnings]
  defstruct [:path | @enforce_keys]

  @type t :: %__MODULE__{
          path: Path.t() | nil,
          targets: [target()],
          entities: [entity()],
          warnings: [ImportPreflightError.issue()]
        }

  @doc "Reads the mapping CSV at `path` and validates it."
  @spec load(Path.t()) :: {:ok, t()} | {:error, term()}
  def load(path) do
    with {:ok, rows} <- CSVReader.run(path) do
      build(rows, path: path)
    end
  end

  @doc """
  Validates already parsed mapping rows.

  ## Options

  - `:path` - source path, used for error reporting only
  """
  @spec build([CSVReader.species()], keyword()) ::
          {:ok, t()} | {:error, MappingValidationError.t()}
  def build(rows, opts \\ []) do
    path = Keyword.get(opts, :path)

    case validate(rows) do
      {targets, warnings, []} ->
        {:ok,
         %__MODULE__{
           path: path,
           targets: targets,
           entities: entities_of(targets),
           warnings: warnings
         }}

      {_targets, _warnings, issues} ->
        {:error, %MappingValidationError{path: path, issues: issues}}
    end
  end

  @doc """
  Validates mapping rows into `{targets, warnings, issues}`.

  Exposed so the import preflight can merge mapping issues with its own instead
  of failing on the mapping alone.
  """
  @spec validate([CSVReader.species()]) ::
          {[target()], [ImportPreflightError.issue()], [ImportPreflightError.issue()]}
  def validate(rows) do
    {targets, _seen, warnings, issues} =
      rows
      |> Enum.with_index(2)
      |> Enum.reduce({[], %{}, [], []}, &validate_row/2)

    {Enum.reverse(targets), Enum.reverse(warnings), Enum.reverse(issues)}
  end

  defp validate_row({row, line}, {targets, seen, warnings, issues}) do
    target = Map.put(row, :line, line)
    previous = Map.get(seen, canonical_name(row.baumart_bo))

    cond do
      row.wikidata_id == "" ->
        warning = %{code: :blank_mapping_qid, baumart_bo: row.baumart_bo, line: line}
        {targets, seen, [warning | warnings], issues}

      not Wikidata.valid_id?(row.wikidata_id) ->
        issue = %{
          code: :invalid_qid,
          source: {:mapping, line},
          baumart_bo: row.baumart_bo,
          qid: row.wikidata_id
        }

        {targets, seen, warnings, [issue | issues]}

      previous ->
        {targets, seen, warnings, [duplicate_issue(previous, target) | issues]}

      true ->
        {[target | targets], Map.put(seen, canonical_name(row.baumart_bo), target), warnings,
         issues}
    end
  end

  # A repeated (baumart_bo, QID) is a hard error even when the German names
  # differ: the differing copy is a corrupted duplicate, not a second target.
  defp duplicate_issue(%{wikidata_id: qid} = previous, %{wikidata_id: qid} = target) do
    %{
      code: :duplicate_mapping,
      baumart_bo: previous.baumart_bo,
      wikidata_id: qid,
      lines: [previous.line, target.line]
    }
  end

  defp duplicate_issue(previous, target) do
    %{
      code: :conflicting_mapping_qids,
      baumart_bo: previous.baumart_bo,
      qids: [previous.wikidata_id, target.wikidata_id],
      lines: [previous.line, target.line]
    }
  end

  defp entities_of(targets) do
    targets
    |> Enum.uniq_by(& &1.wikidata_id)
    |> Enum.map(&Map.take(&1, [:baumart_bo, :baumart_de, :wikidata_id]))
  end

  @doc "Unique, validated target assignments — one per `(baumart_bo, QID)`."
  @spec targets(t()) :: [target()]
  def targets(%__MODULE__{targets: targets}), do: targets

  @doc "Unique entities to fetch and process — one per `wikidata_id`."
  @spec entities(t()) :: [entity()]
  def entities(%__MODULE__{entities: entities}), do: entities

  @doc "Non-blocking findings collected during validation."
  @spec warnings(t()) :: [ImportPreflightError.issue()]
  def warnings(%__MODULE__{warnings: warnings}), do: warnings

  @doc """
  The canonical key used to join cadastre, mapping and review CSV.

  Delegates to `Xylem.Reconciliation.Normalizer.normalize/1`; defined here
  because the key is an identity concern, not a string-processing one.
  """
  @spec canonical_name(String.t()) :: String.t()
  def canonical_name(name), do: Normalizer.normalize(name)

  @doc "Logs validation warnings grouped by code."
  @spec log_warnings(t() | [ImportPreflightError.issue()]) :: :ok
  def log_warnings(%__MODULE__{warnings: warnings}), do: log_warnings(warnings)

  def log_warnings(warnings) do
    warnings
    |> Enum.group_by(& &1.code)
    |> Enum.each(fn {code, group} ->
      details = Enum.map_join(group, ", ", &"#{&1.baumart_bo} (line #{&1.line})")
      Logger.warning("Mapping #{code} (#{length(group)}): #{details}")
    end)
  end
end
