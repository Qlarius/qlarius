defmodule Qlarius.MeCP.Suggestions do
  @moduledoc """
  The confirm-to-add suggestion queue (build plan Phase 1.5).

  Connected assistants propose tags through `suggest_tag`; proposals land here
  and render as the virtual "From Recent Chats" survey in the MeFile Builder.
  Nothing touches the MeFile until the user answers that question through the
  normal survey flow, which then resolves the suggestion via
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
  Pending suggestions shaped like `Surveys.parent_traits_for_survey_with_tags/2`
  (`{trait_id, trait_name, display_order, tags}` tuples), so the Builder's
  virtual "From Recent Chats" survey renders through the same components real
  surveys use.
  """
  def parent_traits_for_suggestions(me_file_id) do
    me_file_id
    |> list_pending_for_me_file()
    |> Enum.with_index()
    |> Enum.map(fn {suggestion, index} ->
      tags =
        Qlarius.YouData.MeFiles.existing_tags_per_parent_trait(me_file_id, suggestion.trait_id)
        |> Enum.map(fn mt ->
          if mt.trait.parent_trait do
            {mt.trait.id, mt.trait.trait_name, mt.trait.display_order}
          else
            {mt.trait.id, mt.tag_value, mt.trait.display_order}
          end
        end)
        |> Enum.sort_by(fn {_id, name, display_order} -> [display_order, name] end)

      {suggestion.trait_id, suggestion.trait.trait_name, index, tags}
    end)
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
