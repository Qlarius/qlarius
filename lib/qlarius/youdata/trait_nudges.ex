defmodule Qlarius.YouData.TraitNudges do
  @moduledoc """
  A skip that has ripened can be shown again once, with the parent's nudge.

  Recording happens only when `record: true`, so a dead render can preview
  the line without using up the one showing.
  """

  import Ecto.Query

  alias Qlarius.Repo
  alias Qlarius.YouData.MeFiles.MeFileTag
  alias Qlarius.YouData.MeFiles.MeFileTraitNudge
  alias Qlarius.YouData.Traits.Trait

  def due(me_file_id, now \\ DateTime.utc_now(), opts \\ []) do
    today = DateTime.to_date(now)
    shown = shown_at_by_parent(me_file_id)

    due =
      Enum.filter(skip_parents(me_file_id), fn row ->
        ripe?(row, today) and not already_shown?(shown[row.parent_id], row.added_date)
      end)

    if Keyword.get(opts, :record, false) do
      Enum.each(due, &record(me_file_id, &1.parent_id, now))
    end

    Map.new(due, &{&1.parent_id, &1.nudge_text})
  end

  defp skip_parents(me_file_id) do
    Repo.all(
      from mt in MeFileTag,
        join: t in Trait,
        on: mt.trait_id == t.id,
        join: p in Trait,
        on: p.id == t.parent_trait_id,
        where: mt.me_file_id == ^me_file_id and not is_nil(p.nudge_text),
        group_by: [p.id, p.nudge_text, p.ripen_days],
        having: fragment("bool_and(?)", t.is_skipped_tag),
        select: %{
          parent_id: p.id,
          nudge_text: p.nudge_text,
          ripen_days: p.ripen_days,
          added_date: max(mt.added_date)
        }
    )
  end

  defp shown_at_by_parent(me_file_id) do
    Repo.all(
      from n in MeFileTraitNudge,
        where: n.me_file_id == ^me_file_id,
        select: {n.trait_id, n.shown_at}
    )
    |> Map.new()
  end

  defp ripe?(%{ripen_days: days, added_date: %NaiveDateTime{} = added}, today)
       when is_integer(days) do
    Date.diff(today, NaiveDateTime.to_date(added)) > days
  end

  defp ripe?(_, _), do: false

  defp already_shown?(nil, _), do: false
  defp already_shown?(_shown, nil), do: false

  defp already_shown?(%DateTime{} = shown_at, %NaiveDateTime{} = added) do
    DateTime.compare(shown_at, DateTime.from_naive!(added, "Etc/UTC")) != :lt
  end

  defp record(me_file_id, parent_id, now) do
    shown_at = DateTime.truncate(now, :second)

    Repo.insert!(
      %MeFileTraitNudge{me_file_id: me_file_id, trait_id: parent_id, shown_at: shown_at},
      on_conflict: [set: [shown_at: shown_at]],
      conflict_target: [:me_file_id, :trait_id]
    )
  end
end
