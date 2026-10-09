defmodule Qlarius.MeCP.Suggestions do
  @moduledoc """
  The confirm-to-add suggestion queue (build plan Phase 1.5).

  Suggestions arrive two ways: MeCP observes a read hitting a gap
  (`observe_gap/3`, the frictionless default) or an assistant explicitly calls
  `suggest_tag` (`create_suggestion/4`). Each pending suggestion surfaces as
  its own trait in the Builder's "Suggested by Qai" panel
  (`suggested_traits_for_me_file/1`), which opens that trait's tag editor with
  the values mentioned in chat pre-ticked. Nothing touches the MeFile until
  the user saves there; the write resolves the suggestion via
  `accept_pending_for_trait/2`.

  Queue rules: suggestions target effective traits whose survey question sits
  in an active survey (`Surveys.surveyed_trait_ids_query/0`; a trait in no
  active survey is orphaned and treated as inactive), must be inside the
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
  alias Qlarius.MeCP.TaxonomyGaps
  alias Qlarius.Repo
  alias Qlarius.YouData.Surveys
  alias Qlarius.YouData.Surveys.SurveyQuestion
  alias Qlarius.YouData.TraitSearch
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
         {:ok, trait} <-
           trait_ref |> resolve_effective_trait() |> note_unknown(grant, trait_ref, attrs, now),
         :ok <- check_scope(grant, trait),
         :ok <- trait |> check_askable() |> note_orphaned(grant, trait, attrs, now),
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

  @doc """
  Pending suggestions for a MeFile, oldest first, with trait and client
  preloaded. Only surveyed traits: a suggestion whose trait has since left
  every active survey (orphaned) stays pending in the table but isn't shown.
  """
  def list_pending_for_me_file(me_file_id) do
    Repo.all(pending_query(me_file_id))
  end

  defp pending_query(me_file_id) do
    active_children =
      from c in Trait,
        where: c.is_active == true,
        order_by: [asc: c.display_order, asc: c.trait_name]

    from s in TagSuggestion,
      where:
        s.me_file_id == ^me_file_id and s.status == "pending" and
          s.trait_id in subquery(Surveys.surveyed_trait_ids_query()),
      order_by: [asc: s.inserted_at, asc: s.id],
      preload: [
        trait: [:survey_question, :trait_category, child_traits: ^active_children],
        grant: [:mecp_client]
      ]
  end

  def pending_count_for_me_file(me_file_id) do
    Repo.one(
      from s in TagSuggestion,
        where: s.me_file_id == ^me_file_id and s.status == "pending",
        select: count(s.id)
    )
  end

  @doc """
  Pending suggestions as Builder entries, one per trait, newest first.

  The Builder opens each entry's own tag editor, so the entry names the trait
  and the values from chat sorted into what's new and what's already there:

    * `new_values`: child traits named in chat (by name or search term) not yet
      on the MeFile; the editor pre-ticks these
    * `unmatched_values`: words from chat that name no child trait
    * `update?`: the trait already carries tags, so the assistant is proposing
      a revision (only it sees the conversation), not a fill for a gap
    * `survey`: the trait's first active survey, shown as context

  Returns entries of `%{suggestion: %TagSuggestion{}, trait: %Trait{}, survey:
  %Survey{}, new_values: [%Trait{}], unmatched_values: [String.t()], update?:
  boolean}`. Suggestions on orphaned traits (in no active survey) are left out.
  """
  def suggested_traits_for_me_file(me_file_id) do
    me_file_id
    |> list_pending_for_me_file()
    |> build_entries(me_file_id)
    |> Enum.sort_by(&{&1.suggestion.inserted_at, &1.suggestion.id}, :desc)
  end

  @doc "One pending suggestion of this MeFile as a Builder entry, or `nil`."
  def suggested_trait_for_me_file(me_file_id, suggestion_id) when is_integer(suggestion_id) do
    me_file_id
    |> pending_query()
    |> where([s], s.id == ^suggestion_id)
    |> Repo.all()
    |> build_entries(me_file_id)
    |> List.first()
  end

  def suggested_trait_for_me_file(_me_file_id, _suggestion_id), do: nil

  defp build_entries([], _me_file_id), do: []

  defp build_entries(suggestions, me_file_id) do
    trait_ids = Enum.map(suggestions, & &1.trait_id)
    tagged = tagged_children_by_anchor(me_file_id, trait_ids)
    surveys = first_active_survey_by_trait(trait_ids)

    for suggestion <- suggestions, survey = surveys[suggestion.trait_id], survey != nil do
      tagged_ids = Map.get(tagged, suggestion.trait_id, MapSet.new())

      {matched, unmatched} =
        TraitSearch.match_values(suggestion.trait.child_traits, suggestion.proposed_values)

      %{
        suggestion: suggestion,
        trait: suggestion.trait,
        survey: survey,
        new_values: Enum.reject(matched, &MapSet.member?(tagged_ids, &1.id)),
        unmatched_values: unmatched,
        update?: MapSet.size(tagged_ids) > 0
      }
    end
  end

  # Tagged child trait ids per anchor (effective) trait for this MeFile. Tags
  # live on child traits and resolve to their parent the way the oracle counts
  # data.
  defp tagged_children_by_anchor(me_file_id, trait_ids) do
    Repo.all(
      from tag in Qlarius.YouData.MeFiles.MeFileTag,
        join: t in Trait,
        on: t.id == tag.trait_id,
        where:
          tag.me_file_id == ^me_file_id and
            coalesce(t.parent_trait_id, t.id) in ^trait_ids,
        select: {coalesce(t.parent_trait_id, t.id), t.id}
    )
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Map.new(fn {anchor_id, child_ids} -> {anchor_id, MapSet.new(child_ids)} end)
  end

  defp first_active_survey_by_trait(trait_ids) do
    Repo.all(
      from sq in SurveyQuestion,
        join: sqs in "survey_question_surveys",
        on: sqs.survey_question_id == sq.id,
        join: s in Qlarius.YouData.Surveys.Survey,
        on: s.id == sqs.survey_id,
        where: sq.trait_id in ^trait_ids and s.active == true,
        select: {sq.trait_id, s},
        order_by: [asc: sq.trait_id, asc: s.id]
    )
    |> Enum.reduce(%{}, fn {trait_id, survey}, acc -> Map.put_new(acc, trait_id, survey) end)
  end

  @doc "Whether a pending suggestion exists for this effective trait."
  def pending_for_trait?(me_file_id, trait_id) do
    Repo.exists?(
      from s in TagSuggestion,
        where: s.me_file_id == ^me_file_id and s.trait_id == ^trait_id and s.status == "pending"
    )
  end

  @doc "Dismisses several pending suggestions at once."
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

  # Taxonomy-gap signals for admins (de-identified; see TaxonomyGaps): an
  # assistant wanted a trait we don't have, or one that's orphaned. The
  # proposed values are kept (scrubbed); the assistant's reason is not.
  defp note_unknown({:error, :unknown_trait} = error, grant, name, attrs, now)
       when is_binary(name) do
    TaxonomyGaps.record(grant, gap_source(attrs), "unknown_trait", name,
      proposed_values: attrs[:proposed_values] || [],
      now: now
    )

    error
  end

  defp note_unknown(result, _grant, _ref, _attrs, _now), do: result

  defp note_orphaned({:error, :not_askable} = error, grant, trait, attrs, now) do
    TaxonomyGaps.record(grant, gap_source(attrs), "not_askable", trait.trait_name,
      nearest_trait_id: trait.id,
      proposed_values: attrs[:proposed_values] || [],
      now: now
    )

    error
  end

  defp note_orphaned(result, _grant, _trait, _attrs, _now), do: result

  defp gap_source(%{source: "observed"}), do: "observed"
  defp gap_source(_attrs), do: "suggest"

  # Renderability guarantee: the Builder presents suggestions as surveys, so
  # the trait's question must sit in an active survey. Orphaned traits (a
  # question in no active survey, or none at all) are inactive.
  defp check_askable(trait) do
    if Surveys.surveyed_trait?(trait.id), do: :ok, else: {:error, :not_askable}
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

  # Leftover pending rows on orphaned traits aren't shown, so they don't
  # count against the grant's cap either.
  defp check_pending_cap(grant_id) do
    count =
      Repo.one(
        from s in TagSuggestion,
          where:
            s.mecp_grant_id == ^grant_id and s.status == "pending" and
              s.trait_id in subquery(Surveys.surveyed_trait_ids_query()),
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
