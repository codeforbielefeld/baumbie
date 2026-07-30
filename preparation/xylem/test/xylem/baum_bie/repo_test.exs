defmodule Xylem.BaumBie.RepoTest do
  use ExUnit.Case, async: true

  alias Xylem.BaumBie.Repo

  describe "delete_values_for/3" do
    test "does nothing when either delete scope is empty" do
      assert Repo.delete_values_for(:client_not_needed, [], ["attribute-uuid"]) == :ok
      assert Repo.delete_values_for(:client_not_needed, ["tree-type-uuid"], []) == :ok
    end
  end

  describe "delete request size" do
    setup do
      %{
        client:
          Supabase.init_client!("http://localhost:54321", "dummy", %{db: %{schema: "public"}})
      }
    end

    test "the largest possible chunk pair stays within the budget", %{client: client} do
      assert Repo.delete_request_target_bytes(client, uuids("1", 100), uuids("2", 40)) <= 7_500
    end

    test "an unchunked attribute filter runs out of budget as attributes grow", %{client: client} do
      # Why the attribute filter is chunked too: one tree-type chunk leaves room
      # for about ninety attributes, and the property config grows by auto-append.
      assert Repo.delete_request_target_bytes(client, uuids("1", 100), uuids("2", 90)) <= 7_500
      assert Repo.delete_request_target_bytes(client, uuids("1", 100), uuids("2", 91)) > 7_500
    end
  end

  describe "delete_chunk_pairs/2" do
    test "keeps one hundred tree types and forty attributes in a single request" do
      tree_types = uuids("1", 100)
      attributes = uuids("2", 40)

      assert Repo.delete_chunk_pairs(tree_types, attributes) == [{tree_types, attributes}]
    end

    test "chunks both filters and pairs every combination" do
      tree_types = uuids("1", 101)
      attributes = uuids("2", 41)

      first_tree_types = Enum.slice(tree_types, 0, 100)
      last_tree_type = Enum.slice(tree_types, 100, 1)
      first_attributes = Enum.slice(attributes, 0, 40)
      last_attribute = Enum.slice(attributes, 40, 1)

      assert Repo.delete_chunk_pairs(tree_types, attributes) == [
               {first_tree_types, first_attributes},
               {first_tree_types, last_attribute},
               {last_tree_type, first_attributes},
               {last_tree_type, last_attribute}
             ]
    end

    test "covers the full cadastre and Wikidata attribute scope in ten requests" do
      pairs = Repo.delete_chunk_pairs(uuids("1", 401), uuids("2", 72))

      assert length(pairs) == 10
      assert Enum.map(pairs, fn {tree_types, _} -> length(tree_types) end) |> Enum.sum() == 802
      assert Enum.all?(pairs, fn {tree_types, _} -> length(tree_types) <= 100 end)
      assert Enum.all?(pairs, fn {_, attributes} -> length(attributes) <= 40 end)
    end

    test "returns no request when either scope is empty" do
      assert Repo.delete_chunk_pairs([], uuids("2", 40)) == []
      assert Repo.delete_chunk_pairs(uuids("1", 100), []) == []
    end
  end

  defp uuids(marker, count) do
    Enum.map(1..count, fn index ->
      suffix = marker <> (index |> Integer.to_string() |> String.pad_leading(11, "0"))
      "00000000-0000-4000-8000-#{suffix}"
    end)
  end
end
