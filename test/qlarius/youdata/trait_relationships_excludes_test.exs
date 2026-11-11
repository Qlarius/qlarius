defmodule Qlarius.YouData.TraitRelationshipsExcludesTest do
  use Qlarius.DataCase, async: true

  import Qlarius.TargetingFixtures

  alias Qlarius.YouData.TraitRelationships
  alias Qlarius.YouData.Traits.Trait
  alias Qlarius.YouData.Traits.TraitRelationship

  setup do
    food = parent_trait_fixture("Fast Food Preferences")
    burgers = trait_fixture(food, "Hamburgers")
    pizza = trait_fixture(food, "Pizza")
    diet = parent_trait_fixture("Typical Daily Diet")
    vegan = trait_fixture(diet, "Vegan")
    keto = trait_fixture(diet, "Keto")

    %{burgers: burgers, pizza: pizza, vegan: vegan, keto: keto, food: food}
  end

  test "excludes is directed and keeps its ids as given", ctx do
    assert {:ok, row} =
             TraitRelationships.create(%{
               "trait_id" => ctx.vegan.id,
               "related_trait_id" => ctx.burgers.id,
               "kind" => "excludes"
             })

    assert row.trait_id == ctx.vegan.id
    assert row.related_trait_id == ctx.burgers.id
    assert row.severity == "hard"
    assert TraitRelationship.directed?(row)

    # The reverse is a separate row.
    assert {:ok, _} =
             TraitRelationships.create(%{
               "trait_id" => ctx.burgers.id,
               "related_trait_id" => ctx.vegan.id,
               "kind" => "excludes",
               "severity" => "soft"
             })
  end

  test "excludes_from/1 follows only the subject side", ctx do
    {:ok, _} =
      TraitRelationships.create(%{
        "trait_id" => ctx.burgers.id,
        "related_trait_id" => ctx.vegan.id,
        "kind" => "excludes"
      })

    assert [row] = TraitRelationships.excludes_from([ctx.burgers.id])
    assert row.related_trait.id == ctx.vegan.id
    assert row.related_trait.parent_trait.trait_name == "Typical Daily Diet"

    assert TraitRelationships.excludes_from([ctx.vegan.id]) == []
    assert TraitRelationships.excludes_from([]) == []
  end

  test "warnings flag same-parent, reverse rows, and conflicts on the pair", ctx do
    {:ok, same_parent} =
      TraitRelationships.create(%{
        "trait_id" => ctx.burgers.id,
        "related_trait_id" => ctx.pizza.id,
        "kind" => "excludes"
      })

    assert "excludes an answer under its own parent" in TraitRelationships.warnings(same_parent)

    {:ok, forward} =
      TraitRelationships.create(%{
        "trait_id" => ctx.burgers.id,
        "related_trait_id" => ctx.vegan.id,
        "kind" => "excludes"
      })

    assert TraitRelationships.warnings(forward) == []

    {:ok, _reverse} =
      TraitRelationships.create(%{
        "trait_id" => ctx.vegan.id,
        "related_trait_id" => ctx.burgers.id,
        "kind" => "excludes"
      })

    {:ok, _conflict} =
      TraitRelationships.create(%{
        "trait_id" => ctx.vegan.id,
        "related_trait_id" => ctx.burgers.id,
        "kind" => "conflicts"
      })

    warnings = TraitRelationships.warnings(forward)
    assert "the reverse excludes row is also present" in warnings
    assert "this pair also conflicts" in warnings
    refute Enum.any?(warnings, &(&1 =~ "both conflicts and requires"))
  end

  test "list_for_parent/3 filters by direction", ctx do
    {:ok, _} =
      TraitRelationships.create(%{
        "trait_id" => ctx.burgers.id,
        "related_trait_id" => ctx.vegan.id,
        "kind" => "excludes"
      })

    assert [_] = TraitRelationships.list_for_parent(ctx.food.id, "excludes", "from")
    assert [] = TraitRelationships.list_for_parent(ctx.food.id, "excludes", "to")
    assert [_] = TraitRelationships.list_for_parent(ctx.food.id, "excludes")
  end

  test "children that conflict with every sibling are exclusive" do
    parent = parent_trait_fixture("Diet")
    alpha = trait_fixture(parent, "Alpha")
    beta = trait_fixture(parent, "Beta")
    gamma = trait_fixture(parent, "Gamma")

    for {left, right} <- [{alpha, beta}, {alpha, gamma}, {beta, gamma}] do
      {lo, hi} = if left.id < right.id, do: {left, right}, else: {right, left}

      assert {:ok, _} =
               TraitRelationships.create(%{
                 "trait_id" => lo.id,
                 "related_trait_id" => hi.id,
                 "kind" => "conflicts"
               })
    end

    assert Enum.sort(TraitRelationships.exclusive_child_ids(parent.id)) ==
             Enum.sort([alpha.id, beta.id, gamma.id])
  end

  test "a child that misses one sibling is not exclusive" do
    parent = parent_trait_fixture("Diet")
    alpha = trait_fixture(parent, "Alpha")
    beta = trait_fixture(parent, "Beta")
    _gamma = trait_fixture(parent, "Gamma")

    {lo, hi} = if alpha.id < beta.id, do: {alpha, beta}, else: {beta, alpha}

    assert {:ok, _} =
             TraitRelationships.create(%{
               "trait_id" => lo.id,
               "related_trait_id" => hi.id,
               "kind" => "conflicts"
             })

    assert TraitRelationships.exclusive_child_ids(parent.id) == []
  end

  test "one conflict between two siblings marks both exclusive" do
    parent = parent_trait_fixture("Diet")
    low = trait_fixture(parent, "Low")
    high = trait_fixture(parent, "High")
    assert low.id < high.id

    assert {:ok, _} =
             TraitRelationships.create(%{
               "trait_id" => high.id,
               "related_trait_id" => low.id,
               "kind" => "conflicts"
             })

    assert Enum.sort(TraitRelationships.exclusive_child_ids(parent.id)) ==
             Enum.sort([low.id, high.id])
  end

  test "a parent with thousands of children and no conflicts has no exclusive ids" do
    parent = parent_trait_fixture("Postal codes")
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    rows =
      for n <- 1..5_000 do
        %{
          trait_name: "Z#{n}",
          parent_trait_id: parent.id,
          display_order: n,
          is_active: true,
          is_skipped_tag: false,
          is_exclusive: false,
          skip_exempt: false,
          has_search_filter: false,
          input_type: "single_select_zip",
          added_by: 0,
          modified_by: 0,
          added_date: now,
          modified_date: now
        }
      end

    Repo.insert_all(Trait, rows)

    assert TraitRelationships.exclusive_ids_by_parent([parent.id]) == %{parent.id => []}
    assert TraitRelationships.exclusive_child_ids(parent.id) == []
  end
end
