defmodule Xylem.Reconciliation.Normalizer do
  @moduledoc """
  String normalization functions for matching botanical tree names
  across different data sources.
  """

  @doc """
  Full normalization: lowercase, collapse whitespace, normalize quotes,
  and standardize subspecies notation (`ssp.` → `subsp.`).
  """
  @spec normalize(String.t()) :: String.t()
  def normalize(string) do
    string
    |> normalize_quotes()
    |> String.downcase()
    |> String.trim()
    |> collapse_whitespace()
    |> String.replace(" ssp. ", " subsp. ")
  end

  @doc """
  Normalizes all Unicode quote variants to ASCII apostrophe.

  Handles MODIFIER LETTER REVERSED COMMA (U+02BD), LEFT/RIGHT SINGLE
  QUOTATION MARK (U+2018/U+2019), and grave accent/backtick (U+0060).
  """
  @spec normalize_quotes(String.t()) :: String.t()
  def normalize_quotes(string) do
    string
    |> String.replace(~r/[ʽ\x{2018}\x{2019}`]/u, "'")
  end

  @doc """
  Removes hybrid markers (`×` and ` x ` between genus and epithet)
  from a normalized string, then collapses resulting double spaces.
  """
  @spec remove_hybrid(String.t()) :: String.t()
  def remove_hybrid(string) do
    string
    |> normalize()
    |> String.replace(~r/×\s*/, "")
    |> String.replace(~r/(?<=\S)\s+x\s+(?=\S)/, " ")
    |> collapse_whitespace()
    |> String.trim()
  end

  @doc """
  Strips cultivar names (in quotes/backticks), `Aggregat` suffix,
  and `f.`/`var.` infraspecific epithets from a botanical name.
  """
  @spec strip_cultivar(String.t()) :: String.t()
  def strip_cultivar(string) do
    string
    |> normalize_quotes()
    |> String.replace(~r/\s+'.*'$/u, "")
    |> String.replace(~r/\s+Aggregat$/i, "")
    |> String.replace(~r/\s+(f\.|var\.)\s+\S+/i, "")
    |> String.trim()
  end

  defp collapse_whitespace(string) do
    String.replace(string, ~r/\s+/, " ")
  end
end
