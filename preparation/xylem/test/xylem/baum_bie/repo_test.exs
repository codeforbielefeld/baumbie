defmodule Xylem.BaumBie.RepoTest do
  use ExUnit.Case, async: true

  alias Xylem.BaumBie.Repo
  alias Xylem.SupabaseRequestTooLargeError

  describe "delete_values_for/3" do
    test "does nothing when either delete scope is empty" do
      assert Repo.delete_values_for(:client_not_needed, [], ["attribute-uuid"]) == :ok
      assert Repo.delete_values_for(:client_not_needed, ["tree-type-uuid"], []) == :ok
    end

    test "rejects an oversized request before contacting Supabase" do
      client =
        Supabase.init_client!("http://localhost:54321", "dummy", %{db: %{schema: "public"}})

      tree_type_uuids = uuids("1", 100)
      attribute_uuids = uuids("2", 100)

      assert {:error,
              %SupabaseRequestTooLargeError{
                operation: :delete,
                table: "tree_type_attribute_values",
                request_target_bytes: request_target_bytes,
                max_request_target_bytes: 7_500
              }} = Repo.delete_values_for(client, tree_type_uuids, attribute_uuids)

      assert request_target_bytes > 7_500
    end
  end

  describe "delete_tree_type_chunks/1" do
    test "keeps up to one hundred tree types in one chunk" do
      uuids = uuids("1", 100)

      assert Repo.delete_tree_type_chunks([]) == []
      assert Repo.delete_tree_type_chunks(uuids) == [uuids]
    end

    test "starts a second chunk at the one-hundred-and-first tree type" do
      uuids = uuids("1", 101)

      assert Repo.delete_tree_type_chunks(uuids) == [
               Enum.slice(uuids, 0, 100),
               Enum.slice(uuids, 100, 1)
             ]
    end

    test "splits the full cadastre scope into five complete chunks" do
      uuids = uuids("1", 401)

      assert Repo.delete_tree_type_chunks(uuids) == [
               Enum.slice(uuids, 0, 100),
               Enum.slice(uuids, 100, 100),
               Enum.slice(uuids, 200, 100),
               Enum.slice(uuids, 300, 100),
               Enum.slice(uuids, 400, 1)
             ]
    end
  end

  defp uuids(marker, count) do
    Enum.map(1..count, fn index ->
      suffix = marker <> (index |> Integer.to_string() |> String.pad_leading(11, "0"))
      "00000000-0000-4000-8000-#{suffix}"
    end)
  end
end
