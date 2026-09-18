defmodule Qlarius.Tiqit.CreatorAudienceBuilderTest do
  use Qlarius.DataCase, async: true

  import Ecto.Query
  import Qlarius.TargetingFixtures

  alias Qlarius.Accounts
  alias Qlarius.Accounts.Scope
  alias Qlarius.Creators
  alias Qlarius.Jobs.PopulateTargetWorker
  alias Qlarius.Sponster.Campaigns.Targets
  alias Qlarius.Tiqit.ContentAudiences

  defp user_fixture do
    {:ok, %{user: user}} =
      Accounts.register_new_user(%{
        alias: "user-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01]
      })

    user
  end

  setup do
    user = user_fixture()
    creator = creator_fixture()
    {:ok, _} = Creators.create_creator_membership(creator.id, user.id, :owner)

    parent = parent_trait_fixture("Interests")
    music = trait_fixture(parent, "Music", 1)
    travel = trait_fixture(parent, "Travel", 2)
    group = trait_group_fixture(%{creator_id: creator.id, parent_trait_id: parent.id}, [music])
    other = trait_group_fixture(%{creator_id: creator.id}, [travel])

    %{
      user: user,
      scope: Scope.for_user(user),
      creator: creator,
      parent: parent,
      music: music,
      travel: travel,
      group: group,
      other: other
    }
  end

  test "adding a trait group creates a bullseye", ctx do
    {:ok, target} =
      ContentAudiences.create_audience(ctx.scope, ctx.creator.id, %{title: "Fans"})

    {:ok, bullseye} = Targets.create_bullseye_band(target.id)
    assert {:ok, _} = Targets.add_trait_group_to_band(bullseye.id, ctx.group.id)

    bands = Targets.get_bands_for_target(target.id)
    assert length(bands) == 1
    assert hd(bands).is_bullseye == "1"
    assert Enum.map(hd(bands).trait_groups, & &1.id) == [ctx.group.id]
  end

  test "expand creates a second band", ctx do
    {:ok, target} =
      ContentAudiences.create_audience(ctx.scope, ctx.creator.id, %{title: "Fans"})

    {:ok, bullseye} = Targets.create_bullseye_band(target.id)
    {:ok, _} = Targets.add_trait_group_to_band(bullseye.id, ctx.group.id)
    {:ok, _} = Targets.add_trait_group_to_band(bullseye.id, ctx.other.id)

    assert {:ok, _ring} = Targets.create_outer_band(target.id, ctx.other.id)

    bands = Targets.get_bands_for_target(target.id)
    assert length(bands) == 2
  end

  test "populate enqueues PopulateTargetWorker and produces reach", ctx do
    {:ok, target} =
      ContentAudiences.create_audience(ctx.scope, ctx.creator.id, %{title: "Fans"})

    {:ok, bullseye} = Targets.create_bullseye_band(target.id)
    {:ok, _} = Targets.add_trait_group_to_band(bullseye.id, ctx.group.id)
    me_file_fixture([ctx.music])

    assert :ok = ContentAudiences.trigger_population(target)

    jobs =
      from(j in Oban.Job, where: j.worker == "Qlarius.Jobs.PopulateTargetWorker")
      |> Repo.all()

    assert Enum.map(jobs, & &1.args["target_id"]) == [target.id]

    assert {:ok, _} = PopulateTargetWorker.perform(%Oban.Job{args: %{"target_id" => target.id}})
    assert ContentAudiences.reach(target) > 0
  end

  test "create_starter_group writes a creator trait group onto the bullseye", ctx do
    {:ok, target} =
      ContentAudiences.create_audience(ctx.scope, ctx.creator.id, %{title: "New audience"})

    formats = parent_trait_fixture("Formats")
    podcast = trait_fixture(formats, "Podcast", 1)

    assert {:ok, group} =
             ContentAudiences.create_starter_group(ctx.scope, target, formats.id, [podcast.id])

    assert group.creator_id == ctx.creator.id
    assert group.parent_trait_id == formats.id

    target = ContentAudiences.get_audience!(ctx.creator.id, target.id)
    [band] = target.target_bands
    assert band.is_bullseye == "1"
    assert Enum.map(band.trait_groups, & &1.id) == [group.id]
  end
end
