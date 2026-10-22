defmodule Qlarius.NudgesTest do
  use Qlarius.DataCase, async: true

  import Ecto.Query
  import Qlarius.MeCPFixtures

  alias Qlarius.Nudges
  alias Qlarius.Nudges.MeFileNudge
  alias Qlarius.Repo
  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.YouData.Surveys.SurveyQuestionSurvey

  @now ~U[2026-10-22 12:00:00Z]

  setup do
    Qlarius.System.set_global_variable("STRONG_START_TAG_GOAL", "25")
    %{me_file: Repo.insert!(%MeFile{})}
  end

  defp keys(nudges), do: Enum.map(nudges, & &1.key)

  defp nudge(me_file, key, now \\ @now) do
    me_file |> Nudges.for_home(0, now) |> Enum.find(&(&1.key == key))
  end

  defp state(me_file, key) do
    Repo.one(
      from n in MeFileNudge, where: n.me_file_id == ^me_file.id and n.nudge_key == ^key
    )
  end

  test "a new MeFile sees the open setup steps in priority order", %{me_file: me_file} do
    nudges = Nudges.for_home(me_file, 3, @now)

    assert keys(nudges) == ["tag_goal", "notifications", "invite"]

    tag_goal = hd(nudges)
    assert tag_goal.meta =~ "3 of 25"
    assert tag_goal.progress == {3, 25}
    assert tag_goal.graphic == "/images/nudges/tag_goal.svg"
  end

  test "the tag goal leaves once it is reached", %{me_file: me_file} do
    refute "tag_goal" in keys(Nudges.for_home(me_file, 25, @now))
  end

  test "essentials shows until every survey question is tagged", %{me_file: me_file} do
    category = insert_category!("Essentials")
    parent = category |> insert_trait!("Pets") |> survey_trait!()
    child = insert_trait!(category, "Dog", parent_trait_id: parent.id)

    survey_id =
      Repo.one(
        from sqs in SurveyQuestionSurvey,
          join: sq in assoc(sqs, :survey_question),
          where: sq.trait_id == ^parent.id,
          select: sqs.survey_id
      )

    Qlarius.System.set_global_variable("STRONG_START_SURVEY_ID", to_string(survey_id))

    essentials = nudge(me_file, "essentials")
    assert essentials.meta == "0 of 1 tagged"
    assert essentials.href == "/me_file_builder?survey_id=#{survey_id}"

    insert_tag!(me_file, child, "Dog")

    refute nudge(me_file, "essentials")
  end

  test "a dismissed nudge returns after its days pass", %{me_file: me_file} do
    {:ok, _} = Nudges.dismiss(me_file.id, nudge(me_file, "tag_goal"), @now)

    refute nudge(me_file, "tag_goal", DateTime.add(@now, 6, :day))
    assert nudge(me_file, "tag_goal", DateTime.add(@now, 7, :day))
    assert state(me_file, "tag_goal").dismissed_count == 1
  end

  test "a nudge with no return date stays dismissed", %{me_file: me_file} do
    {:ok, _} = Nudges.dismiss(me_file.id, nudge(me_file, "notifications"), @now)

    refute nudge(me_file, "notifications", DateTime.add(@now, 365, :day))
  end

  test "tapping counts, and finishes only nudges that complete on tap", %{me_file: me_file} do
    {:ok, _} = Nudges.tap(me_file.id, nudge(me_file, "tag_goal"), @now)
    {:ok, _} = Nudges.tap(me_file.id, nudge(me_file, "tag_goal"), @now)
    {:ok, _} = Nudges.tap(me_file.id, nudge(me_file, "invite"), @now)

    assert %{tapped_count: 2, completed_at: nil} = state(me_file, "tag_goal")
    assert %{tapped_count: 1, completed_at: %DateTime{}} = state(me_file, "invite")

    assert nudge(me_file, "tag_goal")
    refute nudge(me_file, "invite")
  end

  test "each showing is counted", %{me_file: me_file} do
    nudges = Nudges.for_home(me_file, 0, @now)

    :ok = Nudges.record_shown(me_file.id, nudges, @now)
    :ok = Nudges.record_shown(me_file.id, nudges, DateTime.add(@now, 1, :hour))

    assert %{shown_count: 2, first_shown_at: @now} = state(me_file, "invite")
  end
end
