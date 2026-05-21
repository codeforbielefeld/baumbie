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

  @doc """
  Strips taxonomic author citations from a botanical name, keeping only
  the genus, species epithet, and infraspecific markers (subsp./var./f./×/x).

  Handles patterns like:
  - `Acer buergerianum Miq.` → `Acer buergerianum`
  - `Acer campestre L. subsp. campestre` → `Acer campestre subsp. campestre`
  - `Acer cappadocicum Gleditsch subsp. lobelii (Ten.) de Jong` → `Acer cappadocicum subsp. lobelii`
  - `Acer velutinum Boiss. var. velutinum` → `Acer velutinum var. velutinum`
  """
  @spec strip_authors(String.t()) :: String.t()
  def strip_authors(string) do
    # Pre-normalize: insert space before '(' if directly after a word character
    # (handles edge case like "Chamaecyparis lawsoniana(A.Murray) Parl.")
    string = String.replace(string, ~r/(\w)\(/, "\\1 (")

    case String.split(string, ~r/\s+/, trim: true) do
      [genus, hybrid, species | rest] when hybrid in ["×", "x"] ->
        [genus, hybrid, species | walk_keep_infraspecific(rest, [])] |> Enum.join(" ")

      [genus, species | rest] ->
        [genus, species | walk_keep_infraspecific(rest, [])] |> Enum.join(" ")

      _ ->
        string
    end
  end

  @infraspecific_markers ~w(subsp. ssp. var. f. × x)

  defp walk_keep_infraspecific([], acc), do: Enum.reverse(acc)

  defp walk_keep_infraspecific([token | rest], acc) when token in @infraspecific_markers do
    case rest do
      [epithet | tail] -> walk_keep_infraspecific(tail, [epithet, token | acc])
      [] -> Enum.reverse(acc)
    end
  end

  defp walk_keep_infraspecific([_author_token | rest], acc) do
    walk_keep_infraspecific(rest, acc)
  end

  @doc """
  Extracts contents of all top-level (depth 1) parenthetical groups in `string`,
  preserving nested parentheses inside the extracted contents.

  Returns a list of strings, in order of appearance.

  ## Examples

      iex> Normalizer.extract_top_level_parens("Foo (bar) baz (qux (nested))")
      ["bar", "qux (nested)"]
  """
  @spec extract_top_level_parens(String.t()) :: [String.t()]
  def extract_top_level_parens(string) do
    do_extract(String.to_charlist(string), 0, [], [])
  end

  defp do_extract([], _depth, _current, acc), do: Enum.reverse(acc)

  defp do_extract([?( | rest], 0, _current, acc) do
    do_extract(rest, 1, [], acc)
  end

  defp do_extract([?( | rest], depth, current, acc) do
    do_extract(rest, depth + 1, [?( | current], acc)
  end

  defp do_extract([?) | rest], 1, current, acc) do
    extracted = current |> Enum.reverse() |> List.to_string()
    do_extract(rest, 0, [], [extracted | acc])
  end

  defp do_extract([?) | rest], depth, current, acc) when depth > 1 do
    do_extract(rest, depth - 1, [?) | current], acc)
  end

  defp do_extract([_c | rest], 0, current, acc) do
    do_extract(rest, 0, current, acc)
  end

  defp do_extract([c | rest], depth, current, acc) when depth > 0 do
    do_extract(rest, depth, [c | current], acc)
  end

  defp collapse_whitespace(string) do
    String.replace(string, ~r/\s+/, " ")
  end
end
