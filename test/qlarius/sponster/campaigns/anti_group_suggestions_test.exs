defmodule Qlarius.Sponster.Campaigns.AntiGroupSuggestionsTest do
  use Qlarius.DataCase, async: true

  import Qlarius.TargetingFixtures

  alias Qlarius.Repo
  alias Qlarius.Sponster.Campaigns.{AntiGroupSuggestions, Campaign, Targets, TraitGroup}
  alias Qlarius.YouData.TraitRelationships

  setup do
    marketer = marketer_fixture()
    food = parent_trait_fixture("Fast Food Preferences")
    burgers = trait_fixture(food, "Hamburgers")
    pizza = trait_fixture(food, "Pizza")
    diet = parent_trait_fixture("Typical Daily Diet")
    vegan = trait_fixture(diet, "Vegan")
    vegetarian = trait_fixture(diet, "Vegetarian")
    disliked = parent_trait_fixture("Meats Disliked")
    steak = trait_fixture(disliked, "Steak")

    excludes(burgers, vegan, "hard")
    excludes(burgers, vegetarian, "hard")
    excludes(pizza, vegan, "soft")
    excludes(burgers, steak, "soft", "Burger fans who avoid steak are rare")

    burger_group = trait_group_fixture(%{marketer_id: marketer.id}, [burgers, pizza])
    target = target_fixture(%{marketer_id: marketer.id}, [[burger_group]])

    %{
      marketer: marketer,
      target: target,
      burger_group: burger_group,
      vegan: vegan,
      vegetarian: vegetarian,
      steak: steak,
      diet: diet,
      disliked: disliked
    }
  end

  defp freeze_target(target) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    %Campaign{}
    |> Campaign.changeset(%{
      marketer_id: target.marketer_id,
      target_id: target.id,
      media_sequence_id: 1,
      title: "Live #{System.unique_integer([:positive])}",
      start_date: now,
      launched_at: now
    })
    |> Repo.insert!()
  end

  defp excludes(from, to, severity, note \\ nil) do
    {:ok, _} =
      TraitRelationships.create(%{
        "trait_id" => from.id,
        "related_trait_id" => to.id,
        "kind" => "excludes",
        "severity" => severity,
        "note" => note
      })
  end

  test "groups suggestions by the excluded answers' topic, hard first", ctx do
    %{topics: topics, dismissed: [], frozen?: false} =
      AntiGroupSuggestions.for_target(ctx.target.id)

    assert [%{parent: %{id: disliked_id}}, %{parent: %{id: diet_id}}] =
             Enum.sort_by(topics, & &1.parent.trait_name)

    assert disliked_id == ctx.disliked.id
    assert diet_id == ctx.diet.id

    diet_topic = Enum.find(topics, &(&1.parent.id == ctx.diet.id))
    assert [vegan, vegetarian] = diet_topic.traits
    assert vegan.trait.id == ctx.vegan.id
    assert vegan.severity == "hard"
    assert Enum.sort(vegan.because) == ["Hamburgers", "Pizza"]
    assert vegetarian.severity == "hard"

    steak_topic = Enum.find(topics, &(&1.parent.id == ctx.disliked.id))

    assert [%{severity: "soft", note: "Burger fans who avoid steak are rare"}] =
             steak_topic.traits

    assert AntiGroupSuggestions.count(%{topics: topics}) == 3
  end

  test "answers already kept out or already included stop being suggested", ctx do
    anti = anti_trait_group_fixture(%{marketer_id: ctx.marketer.id}, [ctx.vegan])
    [bullseye] = Targets.get_bands_for_target(ctx.target.id)
    {:ok, _} = Targets.add_trait_group_to_band(bullseye.id, anti.id)

    %{topics: topics} = AntiGroupSuggestions.for_target(ctx.target.id)
    suggested = for t <- topics, %{trait: trait} <- t.traits, do: trait.id
    refute ctx.vegan.id in suggested
    assert ctx.vegetarian.id in suggested

    steak_group = trait_group_fixture(%{marketer_id: ctx.marketer.id}, [ctx.steak])
    {:ok, _} = Targets.add_trait_group_to_band(bullseye.id, steak_group.id)

    %{topics: topics} = AntiGroupSuggestions.for_target(ctx.target.id)
    suggested = for t <- topics, %{trait: trait} <- t.traits, do: trait.id
    refute ctx.steak.id in suggested
  end

  test "dismiss hides a topic for this target only and reopen brings it back", ctx do
    other = target_fixture(%{marketer_id: ctx.marketer.id}, [[ctx.burger_group]])

    {:ok, _} = AntiGroupSuggestions.dismiss(ctx.target.id, ctx.diet.id)
    {:ok, _} = AntiGroupSuggestions.dismiss(ctx.target.id, ctx.diet.id)

    %{topics: topics, dismissed: [dismissed]} = AntiGroupSuggestions.for_target(ctx.target.id)
    assert Enum.map(topics, & &1.parent.id) == [ctx.disliked.id]
    assert dismissed.parent.id == ctx.diet.id

    assert %{dismissed: []} = AntiGroupSuggestions.for_target(other.id)

    :ok = AntiGroupSuggestions.reopen(ctx.target.id, ctx.diet.id)
    assert %{dismissed: []} = AntiGroupSuggestions.for_target(ctx.target.id)
  end

  test "confirm per topic creates one anti-group per selection on every band", ctx do
    [bullseye] = Targets.get_bands_for_target(ctx.target.id)
    {:ok, _ring} = Targets.create_outer_band(ctx.target.id, nil)

    selections = [
      %{parent_trait_id: ctx.diet.id, trait_ids: [ctx.vegan.id, ctx.vegetarian.id], title: nil},
      %{parent_trait_id: ctx.disliked.id, trait_ids: [ctx.steak.id], title: "No steak haters"}
    ]

    assert {:ok, groups} = AntiGroupSuggestions.confirm(ctx.target, selections, :per_topic)
    assert length(groups) == 2
    assert Enum.all?(groups, &TraitGroup.anti?/1)
    assert Enum.all?(groups, &(&1.marketer_id == ctx.marketer.id))

    titles = groups |> Enum.map(& &1.title) |> Enum.sort()
    assert titles == ["Keep out · Typical Daily Diet", "No steak haters"]

    diet_group = Enum.find(groups, &(&1.parent_trait_id == ctx.diet.id))

    assert Enum.map(diet_group.traits, & &1.id) |> Enum.sort() ==
             Enum.sort([ctx.vegan.id, ctx.vegetarian.id])

    for band <- Targets.get_bands_for_target(ctx.target.id) do
      ids = Enum.map(band.trait_groups, & &1.id)
      assert Enum.all?(groups, &(&1.id in ids)), "band #{band.id} (bullseye #{bullseye.id})"
    end

    assert %{topics: []} = AntiGroupSuggestions.for_target(ctx.target.id)
  end

  test "confirm combined creates one multi-topic anti-group on chosen bands", ctx do
    [bullseye] = Targets.get_bands_for_target(ctx.target.id)
    {:ok, ring} = Targets.create_outer_band(ctx.target.id, nil)

    selections = [
      %{parent_trait_id: ctx.diet.id, trait_ids: [ctx.vegan.id], title: nil},
      %{parent_trait_id: ctx.disliked.id, trait_ids: [ctx.steak.id], title: nil}
    ]

    assert {:ok, [group]} =
             AntiGroupSuggestions.confirm(ctx.target, selections, :combined,
               band_ids: [bullseye.id]
             )

    assert group.role == "anti"
    assert group.parent_trait_id == nil
    assert group.title == "Keep out · Typical Daily Diet, Meats Disliked"

    assert Enum.map(group.traits, & &1.id) |> Enum.sort() ==
             Enum.sort([ctx.vegan.id, ctx.steak.id])

    bands = Targets.get_bands_for_target(ctx.target.id)
    bullseye = Enum.find(bands, &(&1.id == bullseye.id))
    ring = Enum.find(bands, &(&1.id == ring.id))
    assert group.id in Enum.map(bullseye.trait_groups, & &1.id)
    refute group.id in Enum.map(ring.trait_groups, & &1.id)
  end

  test "confirm with a blank title falls back to the default", ctx do
    selections = [%{parent_trait_id: ctx.diet.id, trait_ids: [ctx.vegan.id], title: "   "}]
    assert {:ok, [group]} = AntiGroupSuggestions.confirm(ctx.target, selections, :per_topic)
    assert group.title == "Keep out · Typical Daily Diet"
  end

  test "confirm refuses empty selections and frozen targets", ctx do
    assert {:error, :traits_required} =
             AntiGroupSuggestions.confirm(
               ctx.target,
               [%{parent_trait_id: 1, trait_ids: [], title: nil}],
               :per_topic
             )

    freeze_target(ctx.target)
    selections = [%{parent_trait_id: ctx.diet.id, trait_ids: [ctx.vegan.id], title: nil}]

    assert {:error, :frozen_target} =
             AntiGroupSuggestions.confirm(ctx.target, selections, :per_topic)

    assert %{frozen?: true} = AntiGroupSuggestions.for_target(ctx.target.id)
  end
end
