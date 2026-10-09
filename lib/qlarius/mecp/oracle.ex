defmodule Qlarius.MeCP.Oracle do
  @moduledoc """
  Narrow question answering against grants, with disclosure budgets.

  v1 accepts **structured question forms only** (free-text NL questions come
  post-Phase-1 and will need an LLM pass). Questions target *effective* traits
  (a child trait id is resolved to its parent):

    * `{:has_trait, trait_id}` — boolean: does the MeFile hold any value for
      this trait?
    * `{:trait_values, trait_id}` — the trait's values, each with its
      confirmation month/year.
    * `{:value_in, trait_id, values}` — boolean: is any of the MeFile's values
      for this trait in `values`? (case-insensitive)
    * `{:bucket, trait_id, buckets}` — the label of the first bucket
      (`{label, values}`) containing one of the MeFile's values, or `nil`.
      Discloses the bucket label only, never the value.

  Split like `Capsules`: `answer/2` is a **pure function over a built capsule**
  (so scope containment is inherited from the capsule build), while `ask/3`
  is the stateful gateway that checks the grant (tier, expiry, revocation),
  enforces the per-period disclosure budget, resolves scope, and writes exactly
  one access-log row per answered question.
  """

  import Ecto.Query

  alias Qlarius.MeCP.AccessLog
  alias Qlarius.MeCP.Capsules
  alias Qlarius.MeCP.Capsules.{Capsule, Scope}
  alias Qlarius.MeCP.Grants
  alias Qlarius.MeCP.Grants.Grant
  alias Qlarius.MeCP.Suggestions
  alias Qlarius.MeCP.TaxonomyGaps
  alias Qlarius.Repo
  alias Qlarius.YouData.MeFiles.MeFileTag
  alias Qlarius.YouData.TraitSearch
  alias Qlarius.YouData.Traits.Trait

  # Questions may target a trait by id or by (case-insensitive exact) name.
  @type trait_ref :: integer() | String.t()

  @type question ::
          {:has_trait, trait_ref()}
          | {:trait_values, trait_ref()}
          | {:value_in, trait_ref(), [String.t()]}
          | {:bucket, trait_ref(), [{String.t(), [String.t()]}]}

  @search_result_limit 10

  # --- stateful gateway -----------------------------------------------------

  @doc """
  Answers a structured question under a grant.

  Checks tier (oracle requires tier >= 2), revocation, expiry, scope, and the
  per-period disclosure budget; on success writes one `oracle` access event and
  returns `{:ok, answer}`.

  Errors: `:revoked | :expired | :insufficient_tier | :budget_exhausted |
  :unsupported_question | :unknown_trait | :out_of_scope`.

  Options: `:now` (DateTime, for tests), `:terms_agreement_id`.
  """
  @spec ask(Grant.t(), question(), keyword()) :: {:ok, term()} | {:error, atom()}
  def ask(%Grant{} = grant, question, opts \\ []) do
    now = Keyword.get(opts, :now, DateTime.utc_now())
    scope = Grants.scope(grant)

    with :ok <- Grants.check(grant, :oracle, now),
         :ok <- Grants.check_budget(grant, now),
         {:ok, trait_id} <- question_trait_id(question),
         {:ok, trait_ref} <-
           trait_id |> effective_trait_ref() |> note_unknown(grant, trait_id, now),
         :ok <- check_scope(scope, trait_ref) do
      me_file_id = Qlarius.MeCP.effective_me_file_id(grant)

      with {:ok, answer} <-
             answer(build_capsule(me_file_id, scope), retarget(question, trait_ref)) do
        AccessLog.record!(
          grant,
          "oracle",
          AccessLog.digest(question),
          question |> response_shape(answer) |> Map.put("me_file_id", me_file_id),
          occurred_at: now,
          terms_agreement_id: Keyword.get(opts, :terms_agreement_id)
        )

        # An empty answer is a confirmed gap the assistant explicitly needed:
        # queue an observed suggestion (best-effort, never fails the read).
        if answer in [false, [], nil] do
          Suggestions.observe_gap(grant, trait_ref.trait_id, now: now)
        end

        {:ok, answer}
      end
    end
  end

  @doc """
  Searches the trait taxonomy by keywords, within the grant's scope.

  Trait and category names are shared vocabulary (the questionnaire, not
  anyone's answers), but each result carries a `has_data` flag for this
  grant's MeFile, and that flag is a disclosure. The call is therefore
  tier-gated (oracle), draws one unit of disclosure budget, and writes one
  access-log row like any other oracle read.

  Matching is `Qlarius.YouData.TraitSearch` (names, search terms and category
  names). Child trait names match and resolve to their effective parent, so a query
  like "dog" finds "Pet Ownership" when "Dog" is one of its child traits.
  Results without data are the gaps a MeFile owner can fill; the MCP layer
  turns them into gentle add-your-tags nudges.

  Returns `{:ok, [%{trait_id: id, trait: name, category: name, has_data: bool}]}`.
  """
  @spec search_traits(Grant.t(), String.t(), keyword()) ::
          {:ok, [map()]} | {:error, atom()}
  def search_traits(%Grant{} = grant, query, opts \\ []) when is_binary(query) do
    now = Keyword.get(opts, :now, DateTime.utc_now())
    scope = Grants.scope(grant)

    with :ok <- Grants.check(grant, :oracle, now),
         :ok <- Grants.check_budget(grant, now),
         {:ok, tokens} <- TraitSearch.tokenize(query) do
      me_file_id = Qlarius.MeCP.effective_me_file_id(grant)
      ranked = TraitSearch.rank(tokens)

      # Coverage is judged on the whole taxonomy, not the grant's scope: a
      # subject outside this grant's categories is still covered.
      note_search_gap(grant, query, ranked, now)

      scoped =
        ranked
        |> Enum.filter(
          &Scope.allows?(scope, %{trait_id: &1.trait_id, category_key: &1.category_id})
        )
        |> Enum.take(@search_result_limit)

      matches = mark_has_data(scoped, me_file_id)

      AccessLog.record!(
        grant,
        "oracle",
        AccessLog.digest({:search_traits, query}),
        %{
          "form" => "search_traits",
          "answer_type" => "trait_list",
          "answer_size" => length(matches),
          "me_file_id" => me_file_id
        },
        occurred_at: now,
        terms_agreement_id: Keyword.get(opts, :terms_agreement_id)
      )

      # The assistant searched for something the MeFile lacks: queue the top
      # gap matches as observed suggestions (score-ordered; best-effort, never
      # fails the read). Each becomes its own Builder row, so category-only
      # hits (score below 2) don't qualify.
      scoped
      |> Enum.zip(matches)
      |> Enum.filter(fn {ranked, match} -> ranked.score >= 2 and match.has_data == false end)
      |> Enum.take(3)
      |> Enum.each(fn {_ranked, match} ->
        Suggestions.observe_gap(grant, match.trait_id, now: now)
      end)

      {:ok, matches}
    end
  end

  # --- pure answer core -----------------------------------------------------

  @doc """
  Answers a question against a built (already scoped) capsule. Pure.

  Never returns an out-of-scope disclosure: the capsule was built under the
  grant's scope, so out-of-scope traits simply aren't present here (the `ask/3`
  wrapper distinguishes out-of-scope from no-data before calling this).
  """
  @spec answer(Capsule.t(), question()) :: {:ok, term()} | {:error, :unsupported_question}
  def answer(%Capsule{} = capsule, {:has_trait, trait_id}) do
    {:ok, find_values(capsule, trait_id) != []}
  end

  def answer(%Capsule{} = capsule, {:trait_values, trait_id}) do
    values =
      for v <- find_values(capsule, trait_id) do
        %{value: v.text, confirmed: format_date(v.added_date)}
      end

    {:ok, values}
  end

  def answer(%Capsule{} = capsule, {:value_in, trait_id, candidates}) when is_list(candidates) do
    candidate_set = MapSet.new(candidates, &normalize/1)
    held = find_values(capsule, trait_id)
    {:ok, Enum.any?(held, fn v -> MapSet.member?(candidate_set, normalize(v.text)) end)}
  end

  def answer(%Capsule{} = capsule, {:bucket, trait_id, buckets}) when is_list(buckets) do
    held = MapSet.new(find_values(capsule, trait_id), &normalize(&1.text))

    label =
      Enum.find_value(buckets, fn {label, values} ->
        if Enum.any?(values, &MapSet.member?(held, normalize(&1))), do: label
      end)

    {:ok, label}
  end

  def answer(%Capsule{}, _question), do: {:error, :unsupported_question}

  # --- helpers --------------------------------------------------------------

  # Taxonomy-gap signals for admins (de-identified; see TaxonomyGaps). A
  # search with no hits is a subject we don't cover; one whose best hit came
  # only from a category name (no trait-name token) is a weak match.
  defp note_search_gap(grant, query, [], now),
    do: TaxonomyGaps.record(grant, "search", "no_match", query, now: now)

  defp note_search_gap(grant, query, [%{score: score} = top | _], now) when score < 2,
    do:
      TaxonomyGaps.record(grant, "search", "weak_match", query,
        nearest_trait_id: top.trait_id,
        now: now
      )

  defp note_search_gap(_grant, _query, _ranked, _now), do: :ok

  # `ask_me` by a trait name the taxonomy doesn't have
  defp note_unknown({:error, :unknown_trait} = error, grant, name, now) when is_binary(name) do
    TaxonomyGaps.record(grant, "ask", "unknown_trait", name, now: now)
    error
  end

  defp note_unknown(result, _grant, _ref, _now), do: result

  defp question_trait_id({:has_trait, ref}) when is_integer(ref) or is_binary(ref),
    do: {:ok, ref}

  defp question_trait_id({:trait_values, ref}) when is_integer(ref) or is_binary(ref),
    do: {:ok, ref}

  defp question_trait_id({:value_in, ref, values})
       when (is_integer(ref) or is_binary(ref)) and is_list(values),
       do: {:ok, ref}

  defp question_trait_id({:bucket, ref, buckets})
       when (is_integer(ref) or is_binary(ref)) and is_list(buckets),
       do: {:ok, ref}

  defp question_trait_id(_), do: {:error, :unsupported_question}

  # Resolves a question's trait reference (id or case-insensitive exact name)
  # to its effective trait (parent if it names a child) so scope checks and
  # capsule lookups agree with how capsules group data.
  defp effective_trait_ref(trait_id) when is_integer(trait_id) do
    Trait |> Repo.get(trait_id) |> to_effective_ref()
  end

  defp effective_trait_ref(name) when is_binary(name) do
    Repo.one(
      from t in Trait,
        where: t.is_active == true and ilike(t.trait_name, ^String.trim(name)),
        # Prefer effective (parent) traits over child traits on name ties.
        order_by: [asc: fragment("? IS NOT NULL", t.parent_trait_id), asc: t.id],
        limit: 1
    )
    |> to_effective_ref()
  end

  defp to_effective_ref(nil), do: {:error, :unknown_trait}

  defp to_effective_ref(%Trait{parent_trait_id: nil} = trait),
    do:
      {:ok, %{trait_id: trait.id, category_key: trait.trait_category_id, name: trait.trait_name}}

  defp to_effective_ref(%Trait{parent_trait_id: parent_id}),
    do: Trait |> Repo.get!(parent_id) |> to_effective_ref()

  # --- taxonomy search helpers -------------------------------------------------

  defp mark_has_data(matches, me_file_id) do
    effective_ids = Enum.map(matches, & &1.trait_id)

    with_data =
      Repo.all(
        from mt in MeFileTag,
          join: t in Trait,
          on: mt.trait_id == t.id,
          where:
            mt.me_file_id == ^me_file_id and
              coalesce(t.parent_trait_id, t.id) in ^effective_ids,
          select: coalesce(t.parent_trait_id, t.id),
          distinct: true
      )
      |> MapSet.new()

    for match <- matches do
      match
      |> Map.put(:has_data, MapSet.member?(with_data, match.trait_id))
      |> Map.drop([:score, :category_id, :matched_values, :matches, :tag_count])
    end
  end

  defp check_scope(%Scope{} = scope, trait_ref) do
    if Scope.allows?(scope, trait_ref), do: :ok, else: {:error, :out_of_scope}
  end

  defp build_capsule(me_file_id, %Scope{} = scope) when is_integer(me_file_id) do
    me_file_id
    |> Qlarius.MeCP.load_me_file()
    |> Capsules.build(scope)
  end

  # Rewrites the question to target the effective trait id.
  defp retarget({:has_trait, _}, %{trait_id: id}), do: {:has_trait, id}
  defp retarget({:trait_values, _}, %{trait_id: id}), do: {:trait_values, id}
  defp retarget({:value_in, _, values}, %{trait_id: id}), do: {:value_in, id, values}
  defp retarget({:bucket, _, buckets}, %{trait_id: id}), do: {:bucket, id, buckets}

  defp find_values(%Capsule{categories: categories}, trait_id) do
    Enum.find_value(categories, [], fn category ->
      Enum.find_value(category.traits, nil, fn trait ->
        if trait.id == trait_id, do: trait.values
      end)
    end)
  end

  defp normalize(text), do: text |> String.trim() |> String.downcase()

  defp format_date(nil), do: nil
  defp format_date(date), do: Calendar.strftime(date, "%b %Y")

  # The audit row records what was asked and the *shape* of the answer,
  # never values, booleans, or bucket labels.
  defp response_shape({form, trait_id}, answer), do: base_shape(form, trait_id, answer)
  defp response_shape({form, trait_id, _arg}, answer), do: base_shape(form, trait_id, answer)

  defp base_shape(form, trait_id, answer) do
    %{
      "form" => Atom.to_string(form),
      "trait_id" => trait_id,
      "answer_type" => answer_type(answer),
      "answer_size" => answer_size(answer)
    }
  end

  defp answer_type(answer) when is_boolean(answer), do: "boolean"
  defp answer_type(answer) when is_list(answer), do: "value_list"
  defp answer_type(nil), do: "no_bucket"
  defp answer_type(answer) when is_binary(answer), do: "bucket"

  defp answer_size(answer) when is_list(answer), do: length(answer)
  defp answer_size(_), do: 1
end
