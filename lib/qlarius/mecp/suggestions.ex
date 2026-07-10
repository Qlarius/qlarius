defmodule Qlarius.MeCP.Suggestions do
  @moduledoc """
  The confirm-to-add suggestion queue (build plan Phase 1.5).

  Suggestions arrive two ways: MeCP observes a read hitting a gap
  (`observe_gap/3`, the frictionless default) or an assistant explicitly calls
  `suggest_tag` (`create_suggestion/4`). Pending anchors group by their
  survey (`suggested_surveys_for_me_file/1`) and surface in the Builder's
  "From Recent Chats" panel, which opens the real survey. Nothing touches the
  MeFile until the user answers there; the write resolves the suggestion via
  `accept_pending_for_trait/2`.

  Queue rules: suggestions target effective traits that carry a survey
  question (guaranteeing the Builder can render them), must be inside the
  grant's scope, dedupe per (me_file, trait) against pending and recently
  dismissed rows, and each grant holds at most #{10} pending. Suggesting costs
  no disclosure budget (it discloses nothing) but requires an unrevoked,
  unexpired grant and writes one `suggestion` access event.
  """

  import Ecto.Query

  alias Qlarius.MeCP
  alias Qlarius.MeCP.AccessLog
  alias Qlarius.MeCP.Capsules.Scope
  alias Qlarius.MeCP.Grants
  alias Qlarius.MeCP.Grants.Grant
  alias Qlarius.MeCP.Suggestions.TagSuggestion
  alias Qlarius.Repo
  alias Qlarius.YouData.Surveys.SurveyQuestion
  alias Qlarius.YouData.Traits.Trait

  @max_pending_per_grant 10
  @dismissed_cooldown_days 30

  @doc false
  def max_pending_per_grant, do: @max_pending_per_grant

  # --- assistant-facing (via MCP) ----------------------------------------------

  @doc """
  Queues a tag suggestion under a grant.

  `trait_ref` is a trait id or case-insensitive exact name; child traits
  resolve to their effective parent. `attrs` may carry `:proposed_values`
  (list of strings) and `:reason` (assistant's words, length-capped).

  Returns `{:ok, suggestion}`, `{:ok, :already_suggested}`,
  `{:error, :suggestion_limit_reached}`, or grant/trait errors
  (`:revoked | :expired | :unknown_trait | :not_askable | :out_of_scope`).
  """
  def create_suggestion(%Grant{} = grant, trait_ref, attrs \\ %{}, opts \\ []) do
    now = Keyword.get(opts, :now, DateTime.utc_now())

    with :ok <- check_grant_active(grant, now),
         {:ok, trait} <- resolve_effective_trait(trait_ref),
         :ok <- check_scope(grant, trait),
         :ok <- check_askable(trait),
         me_file_id = MeCP.effective_me_file_id(grant),
         :ok <- check_not_duplicate(me_file_id, trait.id, now),
         :ok <- check_pending_cap(grant.id) do
      insert_suggestion(grant, me_file_id, trait, attrs, now, opts)
    else
      {:duplicate, :already_suggested} -> {:ok, :already_suggested}
      other -> other
    end
  end

  @doc """
  Queues an observation-derived suggestion: MeCP itself watched a read hit a
  gap (an empty `ask_me` answer or a `search_traits` match without data), so
  no explicit `suggest_tag` call, and no in-chat confirmation, is needed.

  Same queue rules as `create_suggestion/4`, but the row is marked
  `source: "observed"` and no access event is written: the triggering read
  already logged one, and every external read has exactly one event row.
  Best-effort by design: all refusals collapse to `:skipped` so the read that
  triggered the observation can never fail because of it.
  """
  def observe_gap(%Grant{} = grant, trait_ref, opts \\ []) do
    attrs = %{source: "observed"}

    case create_suggestion(grant, trait_ref, attrs, Keyword.put(opts, :log_event, false)) do
      {:ok, %TagSuggestion{} = suggestion} -> {:ok, suggestion}
      _refused_or_duplicate -> :skipped
    end
  end

  # --- app-facing ----------------------------------------------------------------

  @doc "Pending suggestions for a MeFile, oldest first, with trait and client preloaded."
  def list_pending_for_me_file(me_file_id) do
    Repo.all(
      from s in TagSuggestion,
        where: s.me_file_id == ^me_file_id and s.status == "pending",
        order_by: [asc: s.inserted_at, asc: s.id],
        preload: [trait: [:survey_question, :trait_category], grant: [:mecp_client]]
    )
  end

  def pending_count_for_me_file(me_file_id) do
    Repo.one(
      from s in TagSuggestion,
        where: s.me_file_id == ^me_file_id and s.status == "pending",
        select: count(s.id)
    )
  end

  @doc """
  Pending suggestions grouped by the survey their anchor trait belongs to,
  newest first. The survey is the taxonomy's curated cluster of related
  traits, so a single asked-about gap ("Ideal Vacation: Destinations")
  surfaces the whole topic ("Ideal Vacation/Getaway", 6 questions) in the
  Builder, which opens the real survey through the normal flow.

  Returns entries of `%{survey: %Survey{} | nil, suggestions: [...],
  answered: n, total: n, latest: %TagSuggestion{}}`. Entries with `survey:
  nil` (anchor question attached to no survey) fall back to trait-level
  handling; their totals count the suggestions themselves.
  """
  def suggested_surveys_for_me_file(me_file_id) do
    suggestions = list_pending_for_me_file(me_file_id)
    trait_ids = suggestions |> Enum.map(& &1.trait_id) |> Enum.uniq()

    survey_by_trait =
      Repo.all(
        from sq in SurveyQuestion,
          join: sqs in "survey_question_surveys",
          on: sqs.survey_question_id == sq.id,
          join: s in Qlarius.YouData.Surveys.Survey,
          on: s.id == sqs.survey_id,
          where: sq.trait_id in ^trait_ids,
          select: {sq.trait_id, s},
          order_by: [asc: sq.trait_id, asc: s.id]
      )
      |> Enum.group_by(fn {trait_id, _survey} -> trait_id end, fn {_trait_id, survey} ->
        survey
      end)
      |> Map.new(fn {trait_id, [first_survey | _]} -> {trait_id, first_survey} end)

    suggestions
    |> Enum.group_by(&survey_by_trait[&1.trait_id])
    |> Enum.map(fn {survey, group} ->
      latest = Enum.max_by(group, & &1.inserted_at, DateTime)
      {answered, total} = survey_progress(survey, group, me_file_id)

      %{survey: survey, suggestions: group, answered: answered, total: total, latest: latest}
    end)
    |> Enum.sort_by(& &1.latest.inserted_at, {:desc, DateTime})
  end

  @doc "Whether a pending suggestion exists for this effective trait."
  def pending_for_trait?(me_file_id, trait_id) do
    Repo.exists?(
      from s in TagSuggestion,
        where: s.me_file_id == ^me_file_id and s.trait_id == ^trait_id and s.status == "pending"
    )
  end

  @doc "Dismisses several pending suggestions at once (a survey group)."
  def dismiss_many(suggestion_ids, me_file_id, now \\ DateTime.utc_now()) do
    {count, _} =
      Repo.update_all(
        from(s in TagSuggestion,
          where: s.id in ^suggestion_ids and s.me_file_id == ^me_file_id and s.status == "pending"
        ),
        set: [status: "dismissed", reason: nil, resolved_at: DateTime.truncate(now, :second)]
      )

    count
  end

  defp survey_progress(nil, group, _me_file_id), do: {0, length(group)}

  defp survey_progress(survey, _group, me_file_id) do
    parent_traits =
      Qlarius.YouData.Surveys.parent_traits_for_survey_with_tags(survey.id, me_file_id)

    answered = Enum.count(parent_traits, fn {_id, _name, _order, tags} -> tags != [] end)
    {answered, length(parent_traits)}
  end

  @doc """
  Resolves pending suggestions for a trait after the user answered it through
  the Builder. Matches on the effective trait id.
  """
  def accept_pending_for_trait(me_file_id, trait_id, now \\ DateTime.utc_now()) do
    {count, _} =
      Repo.update_all(
        from(s in TagSuggestion,
          where: s.me_file_id == ^me_file_id and s.trait_id == ^trait_id and s.status == "pending"
        ),
        set: [status: "accepted", resolved_at: DateTime.truncate(now, :second)]
      )

    count
  end

  @doc """
  Dismisses one pending suggestion. The reason text (the assistant's words) is
  cleared on dismissal; the row remains for dedupe cooldown and metrics.
  """
  def dismiss(suggestion_id, me_file_id, now \\ DateTime.utc_now()) do
    {count, _} =
      Repo.update_all(
        from(s in TagSuggestion,
          where: s.id == ^suggestion_id and s.me_file_id == ^me_file_id and s.status == "pending"
        ),
        set: [status: "dismissed", reason: nil, resolved_at: DateTime.truncate(now, :second)]
      )

    if count == 1, do: :ok, else: {:error, :not_found}
  end

  @doc "Sweeps all pending suggestions of a grant (called on revocation)."
  def dismiss_all_for_grant(grant_id, now \\ DateTime.utc_now()) do
    {count, _} =
      Repo.update_all(
        from(s in TagSuggestion, where: s.mecp_grant_id == ^grant_id and s.status == "pending"),
        set: [status: "dismissed", reason: nil, resolved_at: DateTime.truncate(now, :second)]
      )

    count
  end

  # --- internals -------------------------------------------------------------------

  defp check_grant_active(grant, now) do
    cond do
      not is_nil(grant.revoked_at) ->
        {:error, :revoked}

      not is_nil(grant.expires_at) and DateTime.after?(now, grant.expires_at) ->
        {:error, :expired}

      true ->
        :ok
    end
  end

  defp resolve_effective_trait(trait_id) when is_integer(trait_id) do
    Trait |> Repo.get(trait_id) |> to_effective_trait()
  end

  defp resolve_effective_trait(name) when is_binary(name) do
    Repo.one(
      from t in Trait,
        where: t.is_active == true and ilike(t.trait_name, ^String.trim(name)),
        order_by: [asc: fragment("? IS NOT NULL", t.parent_trait_id), asc: t.id],
        limit: 1
    )
    |> to_effective_trait()
  end

  defp resolve_effective_trait(_), do: {:error, :unknown_trait}

  defp to_effective_trait(nil), do: {:error, :unknown_trait}
  defp to_effective_trait(%Trait{parent_trait_id: nil} = trait), do: {:ok, trait}

  defp to_effective_trait(%Trait{parent_trait_id: parent_id}),
    do: Trait |> Repo.get!(parent_id) |> to_effective_trait()

  defp check_scope(grant, trait) do
    scope = Grants.scope(grant)

    if Scope.allows?(scope, %{trait_id: trait.id, category_key: trait.trait_category_id}) do
      :ok
    else
      {:error, :out_of_scope}
    end
  end

  # Renderability guarantee: the Builder presents suggestions as survey
  # questions, so the trait must carry one.
  defp check_askable(trait) do
    exists =
      Repo.exists?(from q in SurveyQuestion, where: q.trait_id == ^trait.id)

    if exists, do: :ok, else: {:error, :not_askable}
  end

  defp check_not_duplicate(me_file_id, trait_id, now) do
    cooldown_start = DateTime.add(now, -@dismissed_cooldown_days * 86_400)

    duplicate =
      Repo.exists?(
        from s in TagSuggestion,
          where:
            s.me_file_id == ^me_file_id and s.trait_id == ^trait_id and
              (s.status == "pending" or
                 (s.status == "dismissed" and s.resolved_at > ^cooldown_start))
      )

    if duplicate, do: {:duplicate, :already_suggested}, else: :ok
  end

  defp check_pending_cap(grant_id) do
    count =
      Repo.one(
        from s in TagSuggestion,
          where: s.mecp_grant_id == ^grant_id and s.status == "pending",
          select: count(s.id)
      )

    if count >= @max_pending_per_grant, do: {:error, :suggestion_limit_reached}, else: :ok
  end

  defp insert_suggestion(grant, me_file_id, trait, attrs, now, opts) do
    result =
      %TagSuggestion{}
      |> TagSuggestion.changeset(%{
        mecp_grant_id: grant.id,
        me_file_id: me_file_id,
        trait_id: trait.id,
        proposed_values: List.wrap(attrs[:proposed_values] || []),
        reason: attrs[:reason],
        status: "pending",
        source: attrs[:source] || "assistant"
      })
      |> Repo.insert()

    case result do
      {:ok, suggestion} ->
        # Observed suggestions skip this: their triggering read already logged
        # an event, and every external read has exactly one event row.
        if Keyword.get(opts, :log_event, true) do
          AccessLog.record!(
            grant,
            "suggestion",
            AccessLog.digest({:suggest_tag, trait.id}),
            %{
              "form" => "suggest_tag",
              "trait_id" => trait.id,
              "me_file_id" => me_file_id,
              "proposed_values_count" => length(suggestion.proposed_values)
            },
            occurred_at: now
          )
        end

        {:ok, suggestion}

      {:error, %Ecto.Changeset{errors: errors} = changeset} ->
        # Unique-index race: another suggestion for the same trait won.
        if Keyword.has_key?(errors, :me_file_id),
          do: {:ok, :already_suggested},
          else: {:error, changeset}
    end
  end
end
