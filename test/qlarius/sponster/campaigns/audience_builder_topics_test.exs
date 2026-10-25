defmodule Qlarius.Sponster.Campaigns.AudienceBuilderTopicsTest do
  use Qlarius.DataCase, async: true

  import Qlarius.TargetingFixtures

  alias Qlarius.Repo
  alias Qlarius.Sponster.Campaigns.{AudienceBuilder, TraitGroup}

  setup do
    marketer = marketer_fixture()
    diet = parent_trait_fixture("Diet")
    vegan = trait_fixture(diet, "Vegan")
    keto = trait_fixture(diet, "Keto")
    pets = parent_trait_fixture("Pets")
    dog = trait_fixture(pets, "Dog")

    group =
      %TraitGroup{}
      |> TraitGroup.changeset(%{
        marketer_id: marketer.id,
        title: "Diet",
        parent_trait_id: diet.id
      })
      |> Repo.insert!()
      |> AudienceBuilder.replace_traits!([vegan.id])

    %{
      marketer: marketer,
      diet: diet,
      vegan: vegan,
      keto: keto,
      pets: pets,
      dog: dog,
      group: group
    }
  end

  test "topics/1 groups traits by parent", ctx do
    group = Repo.preload(ctx.group, traits: :parent_trait)
    assert [%{parent: parent, traits: [trait]}] = AudienceBuilder.topics(group)
    assert parent.id == ctx.diet.id
    assert trait.id == ctx.vegan.id
  end

  test "set_topic/4 adds a second topic and clears the parent", ctx do
    {:ok, group} = AudienceBuilder.set_topic(ctx.group, ctx.pets.id, [ctx.dog.id])

    assert is_nil(group.parent_trait_id)
    assert Enum.map(group.traits, & &1.id) |> Enum.sort() == Enum.sort([ctx.vegan.id, ctx.dog.id])
    assert length(AudienceBuilder.topics(group)) == 2
  end

  test "set_topic/4 replaces answers under one topic only", ctx do
    {:ok, group} = AudienceBuilder.set_topic(ctx.group, ctx.pets.id, [ctx.dog.id])
    {:ok, group} = AudienceBuilder.set_topic(group, ctx.diet.id, [ctx.keto.id], title: "Renamed")

    assert group.title == "Renamed"
    assert Enum.map(group.traits, & &1.id) |> Enum.sort() == Enum.sort([ctx.keto.id, ctx.dog.id])
  end

  test "set_topic/4 rejects answers from another topic", ctx do
    assert {:error, {:traits_not_children, [_]}} =
             AudienceBuilder.set_topic(ctx.group, ctx.pets.id, [ctx.keto.id])
  end

  test "remove_topic/2 restores a single parent and refuses the last topic", ctx do
    {:ok, group} = AudienceBuilder.set_topic(ctx.group, ctx.pets.id, [ctx.dog.id])
    {:ok, group} = AudienceBuilder.remove_topic(group, ctx.pets.id)

    assert group.parent_trait_id == ctx.diet.id
    assert Enum.map(group.traits, & &1.id) == [ctx.vegan.id]
    assert {:error, :last_topic} = AudienceBuilder.remove_topic(group, ctx.diet.id)
    assert {:error, :topic_not_in_group} = AudienceBuilder.remove_topic(group, ctx.pets.id)
  end

  test "derived_parent_id/1", ctx do
    assert AudienceBuilder.derived_parent_id([ctx.vegan.id, ctx.keto.id]) == ctx.diet.id
    assert is_nil(AudienceBuilder.derived_parent_id([ctx.vegan.id, ctx.dog.id]))
    assert is_nil(AudienceBuilder.derived_parent_id([]))
  end
end
