defmodule Qlarius.YouData.TraitSearch do
  @moduledoc """
  Keyword search over the trait taxonomy, shared by the MeCP oracle
  (`search_traits`) and the MeFile Builder.

  Tokens match trait names, trait `search_terms` (parents and children) and
  category names. A hit on a child trait counts toward its effective parent,
  so "pottery" finds "Arts and Crafts" and reports "Pottery" as the matched
  value. A trait name or search-term hit scores 2 per token, a category-name
  hit 1, so a best score below 2 means only a category matched.

  Names and terms are shared vocabulary, not anyone's answers; callers decide
  what else (such as whether a MeFile has data) a result may carry.
  """

  import Ecto.Query

  alias Qlarius.Repo
  alias Qlarius.YouData.Surveys
  alias Qlarius.YouData.Traits.{Trait, TraitCategory}

  @min_token_length 3

  @doc """
  Splits a query into lowercase tokens of at least #{@min_token_length}
  characters, with a naive singular so "dogs" still matches "Dog".
  """
  def tokenize(query) when is_binary(query) do
    tokens =
      query
      |> String.downcase()
      |> String.split(~r/[^a-z0-9]+/, trim: true)
      |> Enum.filter(&(String.length(&1) >= @min_token_length))
      |> Enum.flat_map(fn token ->
        if String.ends_with?(token, "s"),
          do: [token, String.trim_trailing(token, "s")],
          else: [token]
      end)
      |> Enum.uniq()

    if tokens == [], do: {:error, :empty_query}, else: {:ok, tokens}
  end

  def tokenize(_query), do: {:error, :empty_query}

  @doc """
  Effective traits matching `tokens`, best first.

  Returns `[%{trait_id, trait, category, category_id, score, matched_values}]`
  where `matched_values` are the names of matching child traits (skip answers
  left out). With `surveyed_only: true`, only traits whose question sits in an
  active survey are returned, so every result can be answered.
  """
  def rank(tokens, opts \\ []) when is_list(tokens) do
    categories = Repo.all(from c in TraitCategory, select: {c.id, c.name}) |> Map.new()
    traits = active_traits(Keyword.get(opts, :surveyed_only, false))
    parents = Map.new(traits, &{&1.id, &1})

    traits
    |> Enum.reduce(%{}, fn trait, acc ->
      effective = if trait.parent_id, do: parents[trait.parent_id], else: trait

      {score, named?} =
        if effective,
          do: score(tokens, trait, categories[effective.category_id]),
          else: {0, false}

      if score > 0 do
        matched = if named? && trait.parent_id && not trait.skip?, do: [trait.name], else: []

        Map.update(acc, effective.id, {score, effective, matched}, fn {best, eff, values} ->
          {max(best, score), eff, values ++ matched}
        end)
      else
        acc
      end
    end)
    |> Enum.map(fn {_id, {score, eff, matched}} ->
      %{
        trait_id: eff.id,
        trait: eff.name,
        category: categories[eff.category_id],
        category_id: eff.category_id,
        score: score,
        matched_values: matched
      }
    end)
    |> Enum.sort_by(&{-&1.score, &1.trait, &1.trait_id})
  end

  @doc """
  The children (of one parent) named by `values`: case-insensitive exact name
  or search term, with the same naive singular as `tokenize/1`. Returns
  `{matched_children, unmatched_values}`, children in their display order.
  """
  def match_values(children, values) when is_list(children) and is_list(values) do
    candidates = Enum.reject(children, & &1.is_skipped_tag)

    {matched, unmatched} =
      Enum.reduce(values, {[], []}, fn value, {matched, unmatched} ->
        case Enum.find(candidates, &names_value?(&1, value)) do
          nil -> {matched, unmatched ++ [value]}
          child -> {Enum.uniq_by(matched ++ [child], & &1.id), unmatched}
        end
      end)

    {Enum.sort_by(matched, &{&1.display_order, &1.trait_name}), unmatched}
  end

  defp names_value?(child, value) do
    wanted = value |> to_string() |> String.trim() |> String.downcase()
    forms = Enum.uniq([wanted, String.trim_trailing(wanted, "s")])
    names = [String.downcase(child.trait_name) | child.search_terms || []]

    wanted != "" and Enum.any?(names, &(&1 in forms or String.trim_trailing(&1, "s") in forms))
  end

  defp active_traits(surveyed_only?) do
    query =
      from t in Trait,
        where: t.is_active == true,
        select: %{
          id: t.id,
          name: t.trait_name,
          parent_id: t.parent_trait_id,
          category_id: t.trait_category_id,
          terms: t.search_terms,
          skip?: t.is_skipped_tag
        }

    query =
      if surveyed_only? do
        surveyed = Surveys.surveyed_trait_ids_query()

        from t in query,
          where: coalesce(t.parent_trait_id, t.id) in subquery(surveyed)
      else
        query
      end

    Repo.all(query)
  end

  # {score, whether the trait's own name or terms matched}
  defp score(tokens, trait, category_name) do
    words = [String.downcase(trait.name) | trait.terms || []]
    category = String.downcase(category_name || "")

    Enum.reduce(tokens, {0, false}, fn token, {acc, named?} ->
      cond do
        Enum.any?(words, &String.contains?(&1, token)) -> {acc + 2, true}
        String.contains?(category, token) -> {acc + 1, named?}
        true -> {acc, named?}
      end
    end)
  end
end
