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

  Returns `{:ok, %{successful: [...], failed: [...]}}`.

  ## Options

  - `:fetch` - fetch mode (default: `:auto`)
    - `:auto` - skip if raw directory already has `.ttl` files, fetch otherwise
    - `:skip` - skip fetching entirely
    - `:force` - always fetch, even if data exists
    - `:clear` - delete existing `.ttl` files and re-fetch
  - `:raw_dir` - directory for raw .ttl files (default: `#{@default_raw_dir}`)
  - `:max_concurrent` - max concurrent HTTP requests (default: #{@default_max_concurrent})
  - `:delay_ms` - delay after each request in ms (default: #{@default_delay_ms})
  - `:plug` - Req plug for testing (optional)
  """
  @spec run([species()], keyword()) ::
          {:ok, %{successful: [species_with_graph()], failed: [fetch_error()]}}
  def run(species_list, opts \\ []) do
    raw_dir = Keyword.get(opts, :raw_dir, @default_raw_dir)
    fetch_mode = Keyword.get(opts, :fetch, :auto)

    case resolve_fetch_mode(fetch_mode, raw_dir) do
      :skip ->
        Logger.info("Skipping Wikidata fetch, loading existing data from #{raw_dir}")
        load_existing(species_list, raw_dir)

      :fetch ->
        do_fetch(species_list, raw_dir, opts)
    end
  end

  defp resolve_fetch_mode(:skip, _raw_dir), do: :skip
  defp resolve_fetch_mode(:force, _raw_dir), do: :fetch

  defp resolve_fetch_mode(:clear, raw_dir) do
    clear_raw_dir!(raw_dir)
    :fetch
  end

  defp resolve_fetch_mode(:auto, raw_dir) do
    if raw_dir_has_data?(raw_dir), do: :skip, else: :fetch
  end

  defp raw_dir_has_data?(raw_dir) do
    raw_dir
    |> raw_dir_data()
    |> Enum.any?()
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

  defp load_existing(species_list, raw_dir) do
    results =
      Enum.reduce(species_list, %{successful: [], failed: []}, fn species, acc ->
        raw_path = Path.join(raw_dir, "#{species.wikidata_id}.ttl")

        case RDF.read_file(raw_path) do
          {:ok, graph} ->
            species_with_graph = Map.merge(species, %{graph: graph, raw_path: raw_path})
            %{acc | successful: [species_with_graph | acc.successful]}

          {:error, reason} ->
            Logger.warning("Failed to load #{species.wikidata_id}: #{inspect(reason)}")
            %{acc | failed: [Map.put(species, :error, reason) | acc.failed]}
        end
      end)

    {:ok, results}
  end

  defp do_fetch(species_list, raw_dir, opts) do
    max_concurrent = Keyword.get(opts, :max_concurrent, @default_max_concurrent)
    delay_ms = Keyword.get(opts, :delay_ms, @default_delay_ms)

    File.mkdir_p!(raw_dir)

    results =
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

    {:ok, results}
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

    with :ok <- validate_wikidata_id(wikidata_id),
         {:ok, ttl_content} <- fetch_ttl(wikidata_id, opts),
         raw_path = Path.join(raw_dir, "#{wikidata_id}.ttl"),
         :ok <- File.write(raw_path, ttl_content),
         {:ok, graph} <- RDF.Turtle.read_string(ttl_content) do
      {:ok, Map.merge(species, %{graph: graph, raw_path: raw_path})}
    else
      {:error, reason} ->
        Logger.warning("Failed to fetch #{wikidata_id}: #{inspect(reason)}")
        {:error, species, reason}
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
