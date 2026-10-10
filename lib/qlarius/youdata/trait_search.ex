defmodule Qlarius.YouData.TraitSearch do
  @moduledoc """
  Keyword search over the trait taxonomy, shared by the MeCP oracle
  (`search_traits`, top 10 active traits) and the MeFile Builder (top 15
  traits in an active survey).

  Each query word scores a trait by the best hit on its name or `search_terms`
  (a parent or a child; a child counts toward its parent):

    * exact match on the full name or a search term
    * a whole word in a name or search term
    * a prefix of a word, so "vet" finds "veterinary" but not "corvette"
    * a substring, only when the query word is 5 or more characters

  A search term scores the same as a name at the same tier. Results are
  listed with a topic-name hit first, then a child-name hit, then a search
  term or category. A category-name hit is weaker than all of those, and a
  best score below 2 means only a category matched. Within a group, ties
  break toward the parent with more MeFile tags, then by name.

  Names and terms are shared vocabulary, not anyone's answers; callers decide
  what else (such as whether a MeFile has data) a result may carry.
  """

  import Ecto.Query

  alias Qlarius.Repo
  alias Qlarius.YouData.MeFiles.MeFileTag
  alias Qlarius.YouData.Surveys
  alias Qlarius.YouData.Traits.{Trait, TraitCategory}

  @min_token_length 3
  @substring_min_length 5

  # Name and term tiers stay at 2 or above so a category-only hit (1) is still
  # the weak match the oracle records.
  @tier_scores %{exact: 8, word: 6, prefix: 4, substring: 2}

  @doc """
  Splits a query into lowercase tokens.

  Words under #{@min_token_length} characters are dropped, except a token that
  is all digits ("420"). A trailing "s" is stripped, and "ies" is also tried
  as "y", so "dogs" matches "dog" and "dispensaries" matches "dispensary".
  """
  def tokenize(query) when is_binary(query) do
    tokens =
      query
      |> String.downcase()
      |> String.split(~r/[^a-z0-9]+/, trim: true)
      |> Enum.filter(&keep_token?/1)
      |> Enum.flat_map(&forms/1)
      |> Enum.uniq()

    if tokens == [], do: {:error, :empty_query}, else: {:ok, tokens}
  end

  def tokenize(_query), do: {:error, :empty_query}

  @doc """
  True when `token` already reads in `text` the way a search hit would:
  the whole string, a word, the start of a word, or a longer substring.
  """
  def obvious?(token, text) when is_binary(token) do
    match_tier(token, text) != nil
  end

  @doc """
  Effective traits matching `tokens`, best first.

  Returns `[%{trait_id, trait, category, category_id, score, tag_count,
  matched_values, matches}]`. `matched_values` are the names of matching child
  traits (skip answers left out). `matches` says which field each query word
  hit. When the topic name ties a child value, `matches` names the topic.
  With `surveyed_only: true`, a parent is included when its question
  sits in an active survey, even if that parent's catalog `is_active` flag
  is false. Children still have to be active, so a retired answer stays out.
  Without that option, every trait has to be active.
  """
  def rank(tokens, opts \\ []) when is_list(tokens) do
    categories = Repo.all(from c in TraitCategory, select: {c.id, c.name}) |> Map.new()
    traits = active_traits(Keyword.get(opts, :surveyed_only, false))
    parents = Map.new(traits, &{&1.id, &1})

    ranked =
      traits
      |> Enum.reduce(%{}, fn trait, acc ->
        effective = if trait.parent_id, do: parents[trait.parent_id], else: trait

        {score, named?, matches} =
          if effective,
            do: score(tokens, trait, categories[effective.category_id]),
            else: {0, false, []}

        if score > 0 do
          matched = if named? && trait.parent_id && not trait.skip?, do: [trait.name], else: []

          Map.update(
            acc,
            effective.id,
            {score, effective, matched, matches},
            fn {best, eff, values, prev} ->
              kept =
                cond do
                  score > best -> matches
                  score == best -> matches ++ prev
                  true -> prev
                end

              {max(best, score), eff, values ++ matched, kept}
            end
          )
        else
          acc
        end
      end)
      |> Enum.map(fn {_id, {score, eff, matched, matches}} ->
        %{
          trait_id: eff.id,
          trait: eff.name,
          category: categories[eff.category_id],
          category_id: eff.category_id,
          score: score,
          matched_values: Enum.uniq(matched),
          matches: best_matches(matches, eff.name)
        }
      end)

    counts = tag_counts(Enum.map(ranked, & &1.trait_id))

    ranked
    |> Enum.map(&Map.put(&1, :tag_count, Map.get(counts, &1.trait_id, 0)))
    |> Enum.sort_by(&{-name_band(&1, tokens), -&1.score, -&1.tag_count, &1.trait, &1.trait_id})
  end

  # A hit already written in the topic name leads, then one written in a
  # child name. A search term that is not on either name follows those.
  defp name_band(result, tokens) do
    cond do
      Enum.any?(tokens, &obvious?(&1, result.trait)) -> 2
      Enum.any?(result.matched_values, fn name -> Enum.any?(tokens, &obvious?(&1, name)) end) -> 1
      true -> 0
    end
  end

  @doc """
  The children (of one parent) named by `values`: case-insensitive exact name
  or search term, with the same singular forms as `tokenize/1`. Returns
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

    if wanted == "" do
      false
    else
      wanted_forms = forms(wanted)
      names = [String.downcase(child.trait_name) | child.search_terms || []]
      Enum.any?(names, &overlaps?(wanted_forms, forms(&1)))
    end
  end

  # Builder search follows the survey screen: a parent whose question is on
  # an active survey is askable even when its catalog `is_active` flag is
  # false. Children still have to be active. Catalog search keeps requiring
  # `is_active` on every row.
  defp active_traits(true) do
    surveyed = Surveys.surveyed_trait_ids_query()

    Repo.all(
      from t in Trait,
        where:
          (is_nil(t.parent_trait_id) and t.id in subquery(surveyed)) or
            (not is_nil(t.parent_trait_id) and t.is_active == true and
               t.parent_trait_id in subquery(surveyed)),
        select: %{
          id: t.id,
          name: t.trait_name,
          parent_id: t.parent_trait_id,
          category_id: t.trait_category_id,
          terms: t.search_terms,
          skip?: t.is_skipped_tag
        }
    )
  end

  defp active_traits(false) do
    Repo.all(
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
    )
  end

  defp tag_counts([]), do: %{}

  defp tag_counts(parent_ids) do
    from(tag in MeFileTag,
      join: t in Trait,
      on: tag.trait_id == t.id,
      where: coalesce(t.parent_trait_id, t.id) in ^parent_ids,
      group_by: fragment("COALESCE(?, ?)", t.parent_trait_id, t.id),
      select: {fragment("COALESCE(?, ?)", t.parent_trait_id, t.id), count(tag.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  # {score, whether the trait's own name or terms matched, match descriptions}
  defp score(tokens, trait, category_name) do
    Enum.reduce(tokens, {0, false, []}, fn token, {acc, named?, matches} ->
      case best_name_match(token, trait.name, trait.terms || []) do
        {tier, field, text} ->
          match = %{token: token, field: field, text: text, tier: Atom.to_string(tier)}
          {acc + @tier_scores[tier], true, [match | matches]}

        nil ->
          if category_name && match_tier(token, category_name) do
            match = %{
              token: token,
              field: "category",
              text: category_name,
              tier: "category"
            }

            {acc + 1, named?, [match | matches]}
          else
            {acc, named?, matches}
          end
      end
    end)
  end

  # Highest tier wins. A search term wins a tie with the name, so a curated
  # synonym is what the result reports.
  defp best_name_match(token, name, terms) do
    candidates = [{name, "name"} | Enum.map(terms, &{&1, "search_term"})]

    candidates
    |> Enum.flat_map(fn {text, field} ->
      case match_tier(token, text) do
        nil -> []
        tier -> [{@tier_scores[tier], field == "search_term", field, text, tier}]
      end
    end)
    |> Enum.sort_by(fn {score, term?, _, _, _} -> {-score, not term?} end)
    |> List.first()
    |> case do
      nil -> nil
      {_score, _term?, field, text, tier} -> {tier, field, text}
    end
  end

  # One row per query word: the hit that earned the score. A tie between the
  # topic name and a tag value reports the topic name, so the result does not
  # claim a value matched when the title itself did.
  defp best_matches(matches, parent_name) do
    matches
    |> Enum.uniq()
    |> Enum.group_by(& &1.token)
    |> Enum.map(fn {_token, group} ->
      Enum.max_by(group, fn match ->
        {tier_rank(match.tier), match.field == "name" and match.text == parent_name}
      end)
    end)
  end

  defp tier_rank("exact"), do: 5
  defp tier_rank("word"), do: 4
  defp tier_rank("prefix"), do: 3
  defp tier_rank("substring"), do: 2
  defp tier_rank("category"), do: 1
  defp tier_rank(_), do: 0

  defp match_tier(token, text) when is_binary(text) do
    down = String.downcase(text)
    token_forms = forms(token)
    words = String.split(down, ~r/[^a-z0-9]+/, trim: true)

    cond do
      overlaps?(token_forms, forms(down)) ->
        :exact

      Enum.any?(words, &overlaps?(token_forms, forms(&1))) ->
        :word

      Enum.any?(words, &prefix?(token_forms, &1)) ->
        :prefix

      String.length(token) >= @substring_min_length and
          Enum.any?(
            token_forms,
            &(String.length(&1) >= @substring_min_length and String.contains?(down, &1))
          ) ->
        :substring

      true ->
        nil
    end
  end

  defp match_tier(_, _), do: nil

  defp prefix?(token_forms, word) do
    word_forms = forms(word)

    Enum.any?(token_forms, fn token ->
      token != "" and
        Enum.any?(word_forms, fn form ->
          String.starts_with?(form, token) and form != token
        end)
    end)
  end

  defp overlaps?(left, right), do: Enum.any?(left, &(&1 in right))

  defp keep_token?(token) do
    String.length(token) >= @min_token_length or String.match?(token, ~r/^\d+$/)
  end

  defp forms(token) do
    extra =
      cond do
        String.ends_with?(token, "ies") ->
          [String.replace_suffix(token, "ies", "y"), String.trim_trailing(token, "s")]

        String.ends_with?(token, "s") ->
          [String.trim_trailing(token, "s")]

        true ->
          []
      end

    Enum.uniq([token | extra])
  end
end
