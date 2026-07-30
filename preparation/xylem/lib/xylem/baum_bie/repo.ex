defmodule Xylem.BaumBie.Repo do
  @moduledoc """
  Thin PostgREST access layer over the Supabase client.

  Wraps the `Supabase.PostgREST` fluent builders for the operations the
  Wikidata import needs: single-row upserts, bulk inserts, lookups and the
  delete step of the values delete+insert strategy.
  """

  alias Supabase.PostgREST
  alias Supabase.Fetcher.JSONDecoder
  alias Supabase.Fetcher.Request
  alias Supabase.Fetcher.Response
  alias Xylem.SupabaseRequestTooLargeError
  alias Xylem.UnexpectedSupabaseResponseError

  # PostgREST 1.2 guards insert/upsert on a single map, so bulk inserts are sent
  # as a manually-built request with a JSON array body, chunked to bound payload size.
  @insert_chunk_size 500

  # PostgREST encodes `in` filters into the request URL. Keep each DELETE below
  # Kong/nginx's common 8 KiB request-line limit and retain headroom for the path.
  # Both filters need chunking. A percent-encoded UUID inside an `in` list costs
  # 39 bytes, so one tree-type chunk of 100 leaves room for only ~90 attributes.
  # The Wikidata provider owns ~70 today and the property config grows by
  # auto-append, so the attribute filter is chunked rather than left to drift
  # into the limit.
  @delete_tree_type_chunk_size 100
  @delete_attribute_chunk_size 40
  @max_delete_request_target_bytes 7_500
  @attribute_values_table "tree_type_attribute_values"

  @doc """
  Upserts a single row and returns the resulting row (including its `uuid`).
  """
  @spec upsert(Supabase.Client.t(), String.t(), map(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def upsert(client, table, row, on_conflict) do
    client
    |> PostgREST.from(table)
    |> PostgREST.upsert(row, on_conflict: on_conflict, returning: :representation)
    |> PostgREST.execute()
    |> case do
      {:ok, %{body: [row | _]}} when is_map(row) -> {:ok, row}
      {:ok, %{body: body}} -> unexpected_response(:upsert, table, body)
      {:error, _} = error -> error
    end
  end

  @doc """
  Inserts many rows in chunks. Returns `:ok` or the first error encountered.
  """
  @spec insert_batch(Supabase.Client.t(), String.t(), [map()]) :: :ok | {:error, term()}
  def insert_batch(_client, _table, []), do: :ok

  def insert_batch(client, table, rows) do
    rows
    |> Enum.chunk_every(@insert_chunk_size)
    |> Enum.reduce_while(:ok, fn chunk, :ok ->
      case insert_chunk(client, table, chunk) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp insert_chunk(client, table, chunk) do
    body = Supabase.json_library().encode_to_iodata!(chunk)

    with {:ok, _resp} <-
           client
           |> PostgREST.from(table)
           |> Request.with_method(:post)
           |> Request.with_headers(%{"prefer" => "return=minimal,count=exact"})
           |> Request.with_body(body)
           |> execute_minimal() do
      :ok
    end
  end

  @doc """
  Returns all attribute UUIDs owned by the given provider.
  """
  @spec attribute_uuids_for_provider(Supabase.Client.t(), String.t()) ::
          {:ok, [String.t()]} | {:error, term()}
  def attribute_uuids_for_provider(client, provider_uuid) do
    client
    |> PostgREST.from("tree_type_attributes")
    |> PostgREST.select(["uuid"], returning: true)
    |> PostgREST.eq("provider_uuid", provider_uuid)
    |> PostgREST.execute()
    |> case do
      {:ok, %{body: rows}} when is_list(rows) ->
        if Enum.all?(rows, &match?(%{"uuid" => uuid} when is_binary(uuid), &1)) do
          {:ok, Enum.map(rows, & &1["uuid"])}
        else
          unexpected_response(:select, "tree_type_attributes", rows)
        end

      {:ok, %{body: body}} ->
        unexpected_response(:select, "tree_type_attributes", body)

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Deletes `tree_type_attribute_values` for the given tree types, restricted to
  the given attributes (so only Wikidata-provider values are removed).

  Both filters are split into bounded chunks because PostgREST represents them
  in the request URL; the deletion is therefore issued as one request per
  combination of a tree-type chunk and an attribute chunk.
  """
  @spec delete_values_for(Supabase.Client.t(), [String.t()], [String.t()]) ::
          :ok | {:error, term()}
  def delete_values_for(_client, [], _attribute_uuids), do: :ok
  def delete_values_for(_client, _tree_type_uuids, []), do: :ok

  def delete_values_for(client, tree_type_uuids, attribute_uuids) do
    tree_type_uuids
    |> delete_chunk_pairs(attribute_uuids)
    |> Enum.reduce_while(:ok, fn {tree_type_chunk, attribute_chunk}, :ok ->
      case delete_values_chunk(client, tree_type_chunk, attribute_chunk) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  @doc false
  @spec delete_chunk_pairs([String.t()], [String.t()]) :: [{[String.t()], [String.t()]}]
  def delete_chunk_pairs(tree_type_uuids, attribute_uuids) do
    for tree_type_chunk <- Enum.chunk_every(tree_type_uuids, @delete_tree_type_chunk_size),
        attribute_chunk <- Enum.chunk_every(attribute_uuids, @delete_attribute_chunk_size),
        do: {tree_type_chunk, attribute_chunk}
  end

  @doc false
  @spec delete_request_target_bytes(Supabase.Client.t(), [String.t()], [String.t()]) ::
          non_neg_integer()
  def delete_request_target_bytes(client, tree_type_uuids, attribute_uuids) do
    client
    |> delete_request(tree_type_uuids, attribute_uuids)
    |> request_target_bytes()
  end

  defp delete_request(client, tree_type_uuids, attribute_uuids) do
    client
    |> PostgREST.from(@attribute_values_table)
    |> PostgREST.within("tree_type_uuid", tree_type_uuids)
    |> PostgREST.within("tree_type_attribute_uuid", attribute_uuids)
    |> PostgREST.delete(returning: :minimal)
  end

  defp delete_values_chunk(client, tree_type_uuids, attribute_uuids) do
    request = delete_request(client, tree_type_uuids, attribute_uuids)

    with :ok <- validate_delete_request_size(request),
         {:ok, _response} <- execute_minimal(request) do
      :ok
    end
  end

  # Backstop: the chunk sizes above already keep every request within budget, so
  # this only fires if the encoding or an identifier format changes.
  defp validate_delete_request_size(%Request{} = request) do
    request_target_bytes = request_target_bytes(request)

    if request_target_bytes <= @max_delete_request_target_bytes do
      :ok
    else
      {:error,
       %SupabaseRequestTooLargeError{
         operation: :delete,
         table: @attribute_values_table,
         request_target_bytes: request_target_bytes,
         max_request_target_bytes: @max_delete_request_target_bytes
       }}
    end
  end

  defp request_target_bytes(%Request{url: %URI{path: path}, query: query}) do
    query_string = URI.encode_query(query)

    byte_size(path || "") +
      if query_string == "", do: 0, else: byte_size(query_string) + 1
  end

  # PostgREST intentionally returns an empty body for `return=minimal`; the
  # default JSON decoder would turn the successful mutation into a decode error.
  defp execute_minimal(request) do
    request
    |> Request.with_body_decoder(&decode_minimal_body/2)
    |> PostgREST.execute()
  end

  defp decode_minimal_body(%Response{body: body}, _opts) when body in [nil, ""],
    do: {:ok, body}

  defp decode_minimal_body(response, _opts), do: JSONDecoder.decode(response)

  defp unexpected_response(operation, table, response) do
    {:error,
     %UnexpectedSupabaseResponseError{
       operation: operation,
       table: table,
       reason: :unexpected_body,
       response: response
     }}
  end
end
