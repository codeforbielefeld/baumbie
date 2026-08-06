defmodule Xylem.Wikidata.Fetcher do
  @moduledoc """
  Fetches Wikidata entity data as Turtle RDF.

  Downloads entities from `https://www.wikidata.org/wiki/Special:EntityData/{id}.ttl`,
  saves raw files locally, and parses them into RDF graphs.
  """

  require Logger
  import Xylem.Wikidata

  @default_raw_dir "priv/data/wikidata/raw"
  @default_max_concurrent 2
  @default_delay_ms 2000

  @fetch_modes ~w(skip force clear auto)a
  def fetch_modes, do: @fetch_modes

  @type species :: %{baumart_bo: String.t(), baumart_de: String.t(), wikidata_id: String.t()}
  @type species_with_graph :: %{
          baumart_bo: String.t(),
          baumart_de: String.t(),
          wikidata_id: String.t(),
          graph: RDF.Graph.t(),
          raw_path: Path.t()
        }
  @type fetch_error :: %{
          baumart_bo: String.t(),
          baumart_de: String.t(),
          wikidata_id: String.t(),
          error: term()
        }

  @doc """
  Fetches Wikidata entities for all species in the list.

  Entities are deduplicated by `wikidata_id` first: fetching, writing and
  parsing depend only on the entity, so one QID serving several tree types must
  still cause exactly one request.

  Returns `{:ok, %{successful: [...], failed: [...], stale: [...]}}`, where
  `stale` lists raw files that belong to no requested entity.

  ## Options

  - `:fetch` - fetch mode (default: `:auto`)
    - `:auto` - load entities that are already cached, fetch only the missing ones
    - `:skip` - skip fetching entirely, load from the raw directory
    - `:force` - always fetch, even if data exists
    - `:clear` - delete existing `.ttl` files and re-fetch
  - `:raw_dir` - directory for raw .ttl files (default: `#{@default_raw_dir}`)
  - `:stale_scope` - all legitimately known `wikidata_id`s (default: those in
    `species_list`). Pass the full mapping when `species_list` is a subset, so a
    limited run does not report the untouched remainder as stale.
  - `:max_concurrent` - max concurrent HTTP requests (default: #{@default_max_concurrent})
  - `:delay_ms` - delay after each request in ms (default: #{@default_delay_ms})
  - `:plug` - Req plug for testing (optional)
  """
  @spec run([species()], keyword()) ::
          {:ok,
           %{
             successful: [species_with_graph()],
             failed: [fetch_error()],
             stale: [Path.t()]
           }}
  def run(species_list, opts \\ []) do
    raw_dir = Keyword.get(opts, :raw_dir, @default_raw_dir)
    fetch_mode = Keyword.get(opts, :fetch, :auto)
    entities = Enum.uniq_by(species_list, & &1.wikidata_id)

    stale_scope = Keyword.get(opts, :stale_scope, Enum.map(entities, & &1.wikidata_id))

    {cached, to_fetch} = split_by_mode(fetch_mode, entities, raw_dir)
    stale = stale_files(stale_scope, raw_dir)

    log_plan(cached, to_fetch, stale, raw_dir)

    cached_results = load_existing(cached, raw_dir)
    fetched_results = do_fetch(to_fetch, raw_dir, opts)

    {:ok,
     %{
       successful: cached_results.successful ++ fetched_results.successful,
       failed: cached_results.failed ++ fetched_results.failed,
       stale: stale
     }}
  end

  defp split_by_mode(:skip, entities, _raw_dir), do: {entities, []}
  defp split_by_mode(:force, entities, _raw_dir), do: {[], entities}

  defp split_by_mode(:clear, entities, raw_dir) do
    clear_raw_dir!(raw_dir)
    {[], entities}
  end

  defp split_by_mode(:auto, entities, raw_dir) do
    Enum.split_with(entities, &File.exists?(raw_path(raw_dir, &1.wikidata_id)))
  end

  # Raw files that belong to no known entity: obsolete QIDs left behind by a
  # mapping correction, which would otherwise silently linger in the directory.
  defp stale_files(stale_scope, raw_dir) do
    known = MapSet.new(stale_scope)

    raw_dir
    |> raw_dir_data()
    |> Enum.reject(&MapSet.member?(known, Path.basename(&1, ".ttl")))
  end

  defp log_plan(cached, to_fetch, stale, raw_dir) do
    if cached != [] do
      Logger.info("Loading #{length(cached)} cached entities from #{raw_dir}")
    end

    if to_fetch != [] do
      Logger.info("Fetching #{length(to_fetch)} Wikidata entities")
    end

    if stale != [] do
      Logger.warning(
        "#{length(stale)} stale raw files in #{raw_dir}: " <>
          Enum.map_join(stale, ", ", &Path.basename(&1, ".ttl"))
      )
    end
  end

  defp clear_raw_dir!(raw_dir) do
    Logger.info("Clearing #{raw_dir}")

    raw_dir
    |> raw_dir_data()
    |> Enum.each(&File.rm!/1)
  end

  defp raw_dir_data(raw_dir) do
    raw_dir |> Path.join("*.ttl") |> Path.wildcard()
  end

  defp raw_path(raw_dir, wikidata_id), do: Path.join(raw_dir, "#{wikidata_id}.ttl")

  defp load_existing(species_list, raw_dir) do
    species_list
    |> Enum.reduce(%{successful: [], failed: []}, fn species, acc ->
      path = raw_path(raw_dir, species.wikidata_id)

      case RDF.read_file(path) do
        {:ok, graph} ->
          species_with_graph = Map.merge(species, %{graph: graph, raw_path: path})
          %{acc | successful: [species_with_graph | acc.successful]}

        {:error, reason} ->
          Logger.warning("Failed to load #{species.wikidata_id}: #{inspect(reason)}")
          %{acc | failed: [Map.put(species, :error, reason) | acc.failed]}
      end
    end)
    |> reverse_results()
  end

  defp do_fetch([], _raw_dir, _opts), do: %{successful: [], failed: []}

  defp do_fetch(species_list, raw_dir, opts) do
    max_concurrent = Keyword.get(opts, :max_concurrent, @default_max_concurrent)
    delay_ms = Keyword.get(opts, :delay_ms, @default_delay_ms)

    File.mkdir_p!(raw_dir)

    species_list
    |> Task.async_stream(
      fn species ->
        result = fetch_species(species, raw_dir, opts)
        Process.sleep(delay_ms)
        result
      end,
      max_concurrency: max_concurrent,
      timeout: 60_000,
      ordered: false
    )
    |> Enum.reduce(%{successful: [], failed: []}, fn
      {:ok, {:ok, species_with_graph}}, acc ->
        %{acc | successful: [species_with_graph | acc.successful]}

      {:ok, {:error, species, reason}}, acc ->
        %{acc | failed: [Map.put(species, :error, reason) | acc.failed]}

      {:exit, reason}, acc ->
        Logger.warning("Task exited unexpectedly: #{inspect(reason)}")
        acc
    end)
    |> reverse_results()
  end

  defp reverse_results(%{successful: successful, failed: failed}) do
    %{successful: Enum.reverse(successful), failed: Enum.reverse(failed)}
  end

  @doc """
  Fetches a single Wikidata entity.

  ## Options

  - `:plug` - Req plug for testing (optional)
  """
  @spec fetch_species(species(), Path.t(), keyword()) ::
          {:ok, species_with_graph()} | {:error, species(), term()}
  def fetch_species(species, raw_dir, opts \\ []) do
    wikidata_id = species.wikidata_id

    # Parse before publishing: a 200 response carrying truncated or malformed
    # Turtle must not replace a cached graph that is still valid, because the
    # next `:auto` run would consider that entity cached and never refetch it.
    with :ok <- validate_wikidata_id(wikidata_id),
         {:ok, ttl_content} <- fetch_ttl(wikidata_id, opts),
         {:ok, graph} <- RDF.Turtle.read_string(ttl_content),
         path = raw_path(raw_dir, wikidata_id),
         :ok <- write_atomic(path, ttl_content) do
      {:ok, Map.merge(species, %{graph: graph, raw_path: path})}
    else
      {:error, reason} ->
        Logger.warning("Failed to fetch #{wikidata_id}: #{inspect(reason)}")
        {:error, species, reason}
    end
  end

  # Write to a private temporary file and rename, so a concurrent writer or an
  # aborted run can never leave a half-written graph under the entity's name.
  # The suffix keeps `*.ttl` globs from picking the temporary file up.
  defp write_atomic(path, content) do
    tmp_path = "#{path}.#{:erlang.unique_integer([:positive])}.tmp"

    with :ok <- File.write(tmp_path, content),
         :ok <- File.rename(tmp_path, path) do
      :ok
    else
      {:error, reason} ->
        File.rm(tmp_path)
        {:error, reason}
    end
  end

  @doc "Fetches the Turtle representation of a Wikidata entity."
  def fetch_ttl(wikidata_id, opts) do
    url = entity_url(wikidata_id)

    req_opts =
      [
        max_retries: 5
      ]
      |> maybe_add_plug(opts)

    case Req.get(url, req_opts) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: 429}} -> {:error, :rate_limited}
      {:ok, %{status: status}} -> {:error, {:http_error, status}}
      {:error, exception} -> {:error, {:request_failed, exception}}
    end
  end

  defp maybe_add_plug(req_opts, opts) do
    case Keyword.get(opts, :plug) do
      nil -> req_opts
      plug -> Keyword.put(req_opts, :plug, plug)
    end
  end
end
