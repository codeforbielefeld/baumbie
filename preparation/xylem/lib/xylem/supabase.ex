defmodule Xylem.Supabase do
  @moduledoc """
  Builds one-off Supabase clients for Xylem consumers.

  `client/0` uses the shared runtime configuration. `client/1` overlays
  caller-specific options, allowing another schema or Supabase instance to be
  selected without introducing a globally supervised client process.
  """

  alias Xylem.SupabaseConfigurationError

  @config_key :supabase
  @required_fields [:base_url, :api_key]

  @doc """
  Builds a Supabase client from runtime configuration and optional overrides.

  Supported overrides are the options accepted by `Supabase.init_client/3`,
  plus `:base_url` and `:api_key`.
  """
  @spec client(keyword()) ::
          {:ok, Supabase.Client.t()} | {:error, SupabaseConfigurationError.t()}
  def client(overrides \\ []) when is_list(overrides) do
    config =
      :xylem
      |> Application.get_env(@config_key, [])
      |> Keyword.merge(overrides)

    with :ok <- validate_config(config) do
      base_url = Keyword.fetch!(config, :base_url)
      api_key = Keyword.fetch!(config, :api_key)
      options = Keyword.drop(config, @required_fields)

      case Elixir.Supabase.init_client(base_url, api_key, options) do
        {:ok, %Supabase.Client{}} = result ->
          result

        {:error, changeset} ->
          configuration_error(:invalid, invalid_fields(changeset))
      end
    end
  end

  defp validate_config(config) do
    missing_fields = Enum.filter(@required_fields, &missing?(Keyword.get(config, &1)))

    invalid_fields =
      @required_fields
      |> Enum.reject(&(&1 in missing_fields))
      |> Enum.reject(&valid?(&1, Keyword.get(config, &1)))

    cond do
      missing_fields != [] -> configuration_error(:missing, missing_fields)
      invalid_fields != [] -> configuration_error(:invalid, invalid_fields)
      true -> :ok
    end
  end

  defp missing?(nil), do: true
  defp missing?(value) when is_binary(value), do: String.trim(value) == ""
  defp missing?(_value), do: false

  defp valid?(:api_key, value), do: is_binary(value)

  defp valid?(:base_url, value) when is_binary(value) do
    match?(
      %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and is_binary(host),
      URI.parse(value)
    )
  end

  defp valid?(_field, _value), do: false

  defp invalid_fields(changeset) do
    changeset
    |> Map.get(:errors, [])
    |> Keyword.keys()
    |> Enum.uniq()
    |> Enum.sort()
    |> case do
      [] -> [:options]
      fields -> fields
    end
  end

  defp configuration_error(reason, fields) do
    {:error, %SupabaseConfigurationError{reason: reason, fields: fields}}
  end
end
