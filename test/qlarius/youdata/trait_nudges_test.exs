defmodule Qlarius.YouData.TraitNudgesTest do
  use Qlarius.DataCase, async: true

  import Qlarius.MeCPFixtures

  alias Qlarius.Repo
  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.YouData.TraitNudges

  @now ~U[2026-06-15 12:00:00Z]
  @nudge "This helps you see more relevant offers"

  setup do
    category = insert_category!("Nudge")

    parent =
      category
      |> insert_trait!("Income")
      |> Ecto.Changeset.change(%{input_type: "multi_select", ripen_days: 7, nudge_text: @nudge})
      |> Repo.update!()

    skip =
      nil
      |> insert_trait!("Prefer not to say", parent_trait_id: parent.id)
      |> Ecto.Changeset.change(%{is_skipped_tag: true})
      |> Repo.update!()

    %{parent: parent, skip: skip}
  end

  test "a ripened skip is nudged once, and not before it ripens", %{parent: parent, skip: skip} do
    me_file = file_with(skip, 8)

    assert TraitNudges.due(me_file.id, @now) == %{parent.id => @nudge}
    assert TraitNudges.due(me_file.id, @now, record: true) == %{parent.id => @nudge}
    assert TraitNudges.due(me_file.id, @now, record: true) == %{}

    fresh = file_with(skip, 7)
    assert TraitNudges.due(fresh.id, @now) == %{}
  end

  test "a skip saved again after the nudge can ripen once more", %{parent: parent, skip: skip} do
    me_file = file_with(skip, 40)
    earlier = DateTime.add(@now, -30, :day)
    assert TraitNudges.due(me_file.id, earlier, record: true) == %{parent.id => @nudge}

    tag =
      Repo.get_by!(Qlarius.YouData.MeFiles.MeFileTag, me_file_id: me_file.id, trait_id: skip.id)

    added = NaiveDateTime.new!(Date.add(DateTime.to_date(@now), -8), ~T[08:00:00])
    tag |> Ecto.Changeset.change(added_date: added) |> Repo.update!()

    assert TraitNudges.due(me_file.id, @now) == %{parent.id => @nudge}
  end

  defp file_with(skip, days_ago) do
    me_file = Repo.insert!(%MeFile{})
    tag = insert_tag!(me_file, skip, skip.trait_name)

    added =
      @now
      |> DateTime.to_date()
      |> Date.add(-days_ago)
      |> NaiveDateTime.new!(~T[08:00:00])

    tag |> Ecto.Changeset.change(added_date: added) |> Repo.update!()
    me_file
  end
end
