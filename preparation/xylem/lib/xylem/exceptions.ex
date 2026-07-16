defmodule Xylem.ImportPreflightError do
  @moduledoc "Structured failure for inputs that cannot produce a safe import plan."

  defexception issues: []

  @impl Exception
  def message(%__MODULE__{issues: issues}) do
    "Wikidata import preflight failed:\n" <>
      Enum.map_join(issues, "\n", fn %{code: code} = issue ->
        "  - #{code}: #{inspect(Map.delete(issue, :code))}"
      end)
  end
end

defmodule Xylem.ImportInputError do
  @moduledoc "Structured failure while reading an import input."

  defexception source: nil, path: nil, reason: nil, details: nil, line: nil

  @impl Exception
  def message(%__MODULE__{} = error) do
    location = if error.line, do: "#{error.path}:#{error.line}", else: error.path
    message = "#{error.source} input error in #{location}: #{error.reason}"

    case error.details do
      nil -> message
      details when is_binary(details) -> "#{message} (#{details})"
      details -> "#{message} (#{inspect(details)})"
    end
  end
end

defmodule Xylem.UnexpectedSupabaseResponseError do
  @moduledoc "Structured failure for a successful Supabase call with an unusable body."

  defexception operation: nil, table: nil, reason: nil, response: nil

  @impl Exception
  def message(%__MODULE__{} = error) do
    "Unexpected Supabase response for #{error.operation} on #{error.table}: #{error.reason}; " <>
      "response=#{inspect(error.response)}"
  end
end

defmodule Xylem.SupabaseConfigurationError do
  @moduledoc "Structured failure for missing or invalid Supabase client configuration."

  defexception reason: nil, fields: []

  @type t :: %__MODULE__{reason: :missing | :invalid, fields: [atom()]}

  @impl Exception
  def message(%__MODULE__{} = error) do
    "Supabase configuration is #{error.reason}: #{Enum.join(error.fields, ", ")}"
  end
end

defmodule Xylem.SupabaseRequestTooLargeError do
  @moduledoc "Structured failure for a PostgREST request that exceeds the safe URI budget."

  defexception operation: nil,
               table: nil,
               request_target_bytes: nil,
               max_request_target_bytes: nil

  @impl Exception
  def message(%__MODULE__{} = error) do
    "Supabase #{error.operation} request for #{error.table} is too large: " <>
      "#{error.request_target_bytes} bytes exceeds the " <>
      "#{error.max_request_target_bytes}-byte request-target budget"
  end
end
