defmodule Qlarius.Nudges do
  @moduledoc """
  Suggested next steps for a MeFile.

  `Qlarius.Nudges.Catalog` decides which nudges apply from the MeFile's data.
  This module hides the ones the person finished or dismissed, orders the
  rest, and records shows, taps, and dismissals in `me_file_nudges`.
  """

  import Ecto.Query

  alias Qlarius.Notifications.Preference
  alias Qlarius.Notifications.PushSubscription
  alias Qlarius.Nudges.Catalog
  alias Qlarius.Nudges.MeFileNudge
  alias Qlarius.Nudges.Nudge
  alias Qlarius.Repo
  alias Qlarius.System
  alias Qlarius.YouData.MeFiles.MeFileTag
  alias Qlarius.YouData.Surveys
  alias Qlarius.YouData.Traits.Trait

  @home_limit 6

  @doc "Nudges to show on Home, most important first."
  def for_home(me_file, trait_count, now \\ DateTime.utc_now()) do
    states = states(me_file.id)

    me_file
    |> context(trait_count)
    |> Catalog.nudges()
    |> Enum.filter(&visible?(Map.get(states, &1.key), now))
    |> Enum.sort_by(& &1.priority)
    |> Enum.take(@home_limit)
  end

  @doc "Counts one showing of each nudge."
  def record_shown(me_file_id, nudges, now \\ DateTime.utc_now())

  def record_shown(_me_file_id, [], _now), do: :ok

  def record_shown(me_file_id, nudges, now) do
    now = DateTime.truncate(now, :second)

    rows =
      Enum.map(nudges, fn %Nudge{key: key} ->
        %{
          me_file_id: me_file_id,
          nudge_key: key,
          shown_count: 1,
          first_shown_at: now,
          last_shown_at: now,
          inserted_at: now,
          updated_at: now
        }
      end)

    Repo.insert_all(MeFileNudge, rows,
      on_conflict: [inc: [shown_count: 1], set: [last_shown_at: now, updated_at: now]],
      conflict_target: [:me_file_id, :nudge_key]
    )

    :ok
  end

  @doc "Counts a tap, and finishes the nudge when opening it is the whole step."
  def tap(me_file_id, %Nudge{} = nudge, now \\ DateTime.utc_now()) do
    now = DateTime.truncate(now, :second)
    completed_at = if nudge.complete_on_tap, do: now

    on_conflict =
      from(n in MeFileNudge,
        update: [
          inc: [tapped_count: 1],
          set: [
            last_tapped_at: ^now,
            updated_at: ^now,
            completed_at: coalesce(n.completed_at, type(^completed_at, :utc_datetime))
          ]
        ]
      )

    %MeFileNudge{
      me_file_id: me_file_id,
      nudge_key: nudge.key,
      tapped_count: 1,
      last_tapped_at: now,
      completed_at: completed_at
    }
    |> Repo.insert(on_conflict: on_conflict, conflict_target: [:me_file_id, :nudge_key])
  end

  @doc "Hides a nudge until its `return_after_days` pass, or for good when that is nil."
  def dismiss(me_file_id, %Nudge{} = nudge, now \\ DateTime.utc_now()) do
    now = DateTime.truncate(now, :second)

    dismissed_until =
      if nudge.return_after_days, do: DateTime.add(now, nudge.return_after_days, :day)

    %MeFileNudge{
      me_file_id: me_file_id,
      nudge_key: nudge.key,
      dismissed_at: now,
      dismissed_until: dismissed_until,
      dismissed_count: 1
    }
    |> Repo.insert(
      on_conflict: [
        inc: [dismissed_count: 1],
        set: [dismissed_at: now, dismissed_until: dismissed_until, updated_at: now]
      ],
      conflict_target: [:me_file_id, :nudge_key]
    )
  end

  defp states(me_file_id) do
    from(n in MeFileNudge, where: n.me_file_id == ^me_file_id)
    |> Repo.all()
    |> Map.new(&{&1.nudge_key, &1})
  end

  defp visible?(nil, _now), do: true
  defp visible?(%MeFileNudge{completed_at: %DateTime{}}, _now), do: false
  defp visible?(%MeFileNudge{dismissed_at: nil}, _now), do: true
  defp visible?(%MeFileNudge{dismissed_until: nil}, _now), do: false
  defp visible?(%MeFileNudge{dismissed_until: until}, now), do: DateTime.compare(now, until) != :lt

  defp context(me_file, trait_count) do
    %{
      me_file: me_file,
      trait_count: trait_count || 0,
      tag_goal: System.get_global_variable_int("STRONG_START_TAG_GOAL", 25),
      essentials: essentials_progress(me_file.id),
      notifications_on?: notifications_on?(me_file.user_id)
    }
  end

  defp essentials_progress(me_file_id) do
    case System.get_global_variable_int("STRONG_START_SURVEY_ID", nil) do
      nil ->
        nil

      survey_id ->
        parent_ids =
          survey_id
          |> Surveys.parent_traits_for_survey_ordered()
          |> Enum.map(fn {id, _name, _order} -> id end)

        answered =
          from(t in Trait,
            join: mft in MeFileTag,
            on: mft.trait_id == t.id,
            where: mft.me_file_id == ^me_file_id and t.parent_trait_id in ^parent_ids,
            select: count(t.parent_trait_id, :distinct)
          )
          |> Repo.one()

        %{survey_id: survey_id, answered: answered, total: length(parent_ids)}
    end
  end

  defp notifications_on?(nil), do: false

  defp notifications_on?(user_id) do
    Repo.exists?(
      from s in PushSubscription, where: s.user_id == ^user_id and s.active == true
    ) or
      Repo.exists?(from p in Preference, where: p.user_id == ^user_id and p.enabled == true)
  end
end
