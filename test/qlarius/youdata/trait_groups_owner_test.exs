defmodule Qlarius.YouData.TraitGroupsOwnerTest do
  use Qlarius.DataCase, async: true

  import Qlarius.TargetingFixtures

  alias Qlarius.Sponster.Campaigns.Targets
  alias Qlarius.YouData.Traits

  test "creator and marketer trait groups are isolated" do
    marketer = marketer_fixture()
    creator = creator_fixture()
    parent = parent_trait_fixture("Interests")
    music = trait_fixture(parent, "Music")

    marketer_group = trait_group_fixture(%{marketer_id: marketer.id}, [music])
    creator_group = trait_group_fixture(%{creator_id: creator.id}, [music])

    creator_ids =
      Traits.list_trait_groups_for_owner({:creator, creator.id})
      |> Enum.map(& &1.id)

    marketer_ids =
      Traits.list_trait_groups_for_owner({:marketer, marketer.id})
      |> Enum.map(& &1.id)

    assert creator_ids == [creator_group.id]
    assert marketer_ids == [marketer_group.id]

    assert Traits.get_trait_group_for_owner!(creator_group.id, {:creator, creator.id}).id ==
             creator_group.id

    assert_raise Ecto.NoResultsError, fn ->
      Traits.get_trait_group_for_owner!(marketer_group.id, {:creator, creator.id})
    end

    assert_raise Ecto.NoResultsError, fn ->
      Traits.get_trait_group_for_owner!(creator_group.id, {:marketer, marketer.id})
    end
  end

  test "available groups for a creator audience exclude marketer groups" do
    marketer = marketer_fixture()
    creator = creator_fixture()
    parent = parent_trait_fixture("Interests")
    music = trait_fixture(parent, "Music")
    travel = trait_fixture(parent, "Travel")

    marketer_group = trait_group_fixture(%{marketer_id: marketer.id}, [music])
    creator_group = trait_group_fixture(%{creator_id: creator.id}, [travel])

    {:ok, target} =
      Targets.create_target(%{title: "Fans", creator_id: creator.id})

    available =
      Targets.get_available_trait_groups_for_target(target.id, {:creator, creator.id})

    available_ids = Enum.map(available, & &1.id)
    assert creator_group.id in available_ids
    refute marketer_group.id in available_ids
  end
end
