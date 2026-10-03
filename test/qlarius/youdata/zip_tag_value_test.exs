defmodule Qlarius.YouData.ZipTagValueTest do
  use Qlarius.DataCase, async: true

  import Ecto.Query
  import Qlarius.TargetingFixtures

  alias Qlarius.Jobs.PopulateTargetWorker
  alias Qlarius.Repo
  alias Qlarius.Sponster.Campaigns.{TargetBand, TargetPopulation}
  alias Qlarius.YouData.MeFiles
  alias Qlarius.YouData.MeFiles.MeFileTag

  test "a zip saved without a loaded child label stores the zip code" do
    parent = zip_parent_fixture("Home Zip Code")
    zip = zip_code_fixture(parent, "85013", "Phoenix, AZ")
    me_file = me_file_fixture()

    assert :ok = MeFiles.create_replace_mefile_tags(me_file.id, parent.id, [zip.id], 0, %{})

    tag = Repo.get_by!(MeFileTag, me_file_id: me_file.id, trait_id: zip.id)
    assert tag.tag_value == "85013"
  end

  test "an explicit child label is kept" do
    parent = zip_parent_fixture("Home Zip Code")
    zip = zip_code_fixture(parent, "85013", "Phoenix, AZ")
    me_file = me_file_fixture()

    assert :ok =
             MeFiles.create_replace_mefile_tags(me_file.id, parent.id, [zip.id], 0, %{
               zip.id => "kept label"
             })

    tag = Repo.get_by!(MeFileTag, me_file_id: me_file.id, trait_id: zip.id)
    assert tag.tag_value == "kept label"
  end

  test "a population snapshot uses the zip trait name when tag_value is blank" do
    marketer = marketer_fixture()
    parent = zip_parent_fixture("Home Zip Code")
    zip = zip_code_fixture(parent, "85013", "Phoenix, AZ")
    me_file = me_file_fixture()

    %MeFileTag{}
    |> MeFileTag.changeset(%{
      me_file_id: me_file.id,
      trait_id: zip.id,
      tag_value: nil,
      added_by: 0,
      modified_by: 0
    })
    |> Repo.insert!()

    group = trait_group_fixture(%{marketer_id: marketer.id}, [zip])
    target = target_fixture(%{marketer_id: marketer.id}, [[group]])

    assert {:ok, _} =
             PopulateTargetWorker.perform(%Oban.Job{args: %{"target_id" => target.id}})

    snapshot =
      Repo.one!(
        from tp in TargetPopulation,
          join: tb in TargetBand,
          on: tb.id == tp.target_band_id,
          where: tb.target_id == ^target.id and tp.me_file_id == ^me_file.id,
          select: tp.matching_tags_snapshot
      )

    assert snapshot["tags"] == [
             [parent.id, "Home Zip Code", 1, [[zip.id, "85013", zip.display_order]]]
           ]
  end
end
