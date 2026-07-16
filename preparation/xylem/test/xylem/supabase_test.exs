defmodule Xylem.SupabaseTest do
  use ExUnit.Case, async: false

  alias Xylem.Supabase, as: SupabaseClient
  alias Xylem.SupabaseConfigurationError

  setup do
    previous_config = Application.get_env(:xylem, :supabase)

    on_exit(fn ->
      if previous_config do
        Application.put_env(:xylem, :supabase, previous_config)
      else
        Application.delete_env(:xylem, :supabase)
      end
    end)

    :ok
  end

  test "builds a one-off client from shared configuration" do
    Application.put_env(:xylem, :supabase,
      base_url: "http://localhost:54321",
      api_key: "test-key",
      db: [schema: "public"]
    )

    assert {:ok,
            %Supabase.Client{
              base_url: "http://localhost:54321",
              api_key: "test-key",
              db: %Supabase.Client.Db{schema: "public"}
            }} = SupabaseClient.client()
  end

  test "allows callers to override shared client options" do
    Application.put_env(:xylem, :supabase,
      base_url: "http://localhost:54321",
      api_key: "configured-key",
      db: [schema: "public"]
    )

    assert {:ok,
            %Supabase.Client{
              base_url: "https://example.supabase.co",
              api_key: "override-key",
              db: %Supabase.Client.Db{schema: "private"}
            }} =
             SupabaseClient.client(
               base_url: "https://example.supabase.co",
               api_key: "override-key",
               db: [schema: "private"]
             )
  end

  test "returns only missing field names for incomplete configuration" do
    Application.put_env(:xylem, :supabase, db: [schema: "public"])

    assert SupabaseClient.client() ==
             {:error,
              %SupabaseConfigurationError{
                reason: :missing,
                fields: [:base_url, :api_key]
              }}
  end

  test "rejects malformed connection values without returning them" do
    Application.put_env(:xylem, :supabase,
      base_url: "not-a-url",
      api_key: 123,
      db: [schema: "public"]
    )

    assert SupabaseClient.client() ==
             {:error,
              %SupabaseConfigurationError{
                reason: :invalid,
                fields: [:base_url, :api_key]
              }}
  end
end
