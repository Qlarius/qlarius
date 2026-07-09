defmodule Qlarius.MeCP.CapsulesTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Qlarius.MeCP.Capsules
  alias Qlarius.MeCP.Capsules.{Capsule, Scope}
  alias Qlarius.YouData.MeFiles.{MeFile, MeFileTag}
  alias Qlarius.YouData.Traits.{Trait, TraitCategory}

  # A fixed universe of categories and effective traits the generators draw from.
  @categories %{1 => "Demographics", 2 => "Lifestyle", 3 => "Finance"}

  # effective trait id => {category_id, kind}. A :leaf tag stores its value in
  # tag_value; a :parent tag's value is the child trait's name (the effective
  # trait is the parent). Both paths must resolve to the same effective trait id.
  @effective_traits %{
    10 => {1, :leaf},
    11 => {1, :parent},
    12 => {2, :leaf},
    13 => {2, :parent},
    14 => {3, :leaf},
    15 => {3, :parent}
  }

  @category_ids Map.keys(@categories)
  @trait_ids Map.keys(@effective_traits)

  # --- concrete rendering examples -----------------------------------------

  describe "compile/3 rendering" do
    test "renders categories, traits, and month/year dated values" do
      me_file =
        me_file([
          leaf_tag(10, "Renter", ~N[2026-07-01 12:00:00]),
          parent_tag(11, "Dog owner", ~N[2025-11-20 09:30:00])
        ])

      capsule = Capsules.compile(me_file)

      assert capsule == """
             # MeFile Context

             _Self-declared by the MeFile owner. Dates show when each value was last confirmed._

             ## Demographics

             ### Trait 10
             - Renter (Jul 2026)

             ### Trait 11
             - Dog owner (Nov 2025)
             """
    end

    test "a parent trait's value is the child trait name, not tag_value" do
      me_file = me_file([parent_tag(13, "Frequent traveler", ~N[2026-01-15 00:00:00])])

      assert Capsules.compile(me_file) =~ "- Frequent traveler (Jan 2026)"
    end

    test "drops blank and whitespace-only values" do
      me_file =
        me_file([
          leaf_tag(10, "   ", ~N[2026-07-01 00:00:00]),
          leaf_tag(12, "Keep me", ~N[2026-07-01 00:00:00])
        ])

      capsule = Capsules.compile(me_file)
      assert capsule =~ "Keep me"
      refute capsule =~ "Trait 10"
    end

    test "renders a placeholder when nothing is in scope" do
      assert Capsules.compile(me_file([])) =~ "No data in scope."
    end
  end

  describe "scope" do
    test "restricting to a category excludes other categories" do
      me_file =
        me_file([
          leaf_tag(10, "Demo value", ~N[2026-07-01 00:00:00]),
          leaf_tag(12, "Lifestyle value", ~N[2026-07-01 00:00:00])
        ])

      capsule = Capsules.compile(me_file, Scope.new(category_ids: [1]))

      assert capsule =~ "Demo value"
      refute capsule =~ "Lifestyle value"
      refute capsule =~ "## Lifestyle"
    end

    test "from_grant reads string-keyed jsonb scope" do
      scope = Scope.from_grant(%{"category_ids" => [1], "trait_ids" => ["10"]})
      assert scope == %Scope{category_ids: [1], trait_ids: [10]}
    end
  end

  # --- properties -----------------------------------------------------------

  property "rendering is deterministic and independent of tag order" do
    check all(
            tags <- list_of(tag_gen(), max_length: 25),
            seed <- integer(0..1_000_000)
          ) do
      me_file = me_file(tags)
      reference = Capsules.compile(me_file)

      # Same input renders identically every time.
      assert Capsules.compile(me_file) == reference

      # Any permutation of the same tags renders identically.
      reordered = me_file(reorder(tags, seed))
      assert Capsules.compile(reordered) == reference
    end
  end

  property "a capsule never contains a trait outside its scope" do
    check all(
            tags <- list_of(tag_gen(), max_length: 25),
            category_axis <- axis_gen(@category_ids),
            trait_axis <- axis_gen(@trait_ids)
          ) do
      scope = %Scope{category_ids: category_axis, trait_ids: trait_axis}
      %Capsule{categories: categories} = Capsules.build(me_file(tags), scope)

      for category <- categories do
        if category_axis != :all, do: assert(category.id in category_axis)

        for trait <- category.traits do
          if trait_axis != :all, do: assert(trait.id in trait_axis)
        end
      end
    end
  end

  property "a restricted capsule is a subset of the full capsule" do
    check all(
            tags <- list_of(tag_gen(), max_length: 25),
            category_axis <- axis_gen(@category_ids),
            trait_axis <- axis_gen(@trait_ids)
          ) do
      me_file = me_file(tags)
      full = trait_id_set(Capsules.build(me_file, Scope.all()))

      restricted =
        trait_id_set(
          Capsules.build(me_file, %Scope{category_ids: category_axis, trait_ids: trait_axis})
        )

      assert MapSet.subset?(restricted, full)
    end
  end

  property "an empty scope discloses nothing" do
    check all(tags <- list_of(tag_gen(), min_length: 1, max_length: 25)) do
      capsule = Capsules.build(me_file(tags), %Scope{category_ids: [], trait_ids: :all})
      assert capsule.categories == []
    end
  end

  # --- generators -----------------------------------------------------------

  defp tag_gen do
    gen all(
          id <- member_of(@trait_ids),
          value <- string(:alphanumeric, min_length: 1, max_length: 10),
          days <- integer(0..3000)
        ) do
      date = NaiveDateTime.add(~N[2018-01-01 00:00:00], days * 86_400)
      build_tag(id, value, date)
    end
  end

  # An axis of a scope: unrestricted, or a (possibly empty) subset of the ids.
  defp axis_gen(ids) do
    one_of([
      constant(:all),
      gen all(flags <- list_of(boolean(), min_length: length(ids), max_length: length(ids))) do
        ids |> Enum.zip(flags) |> Enum.filter(&elem(&1, 1)) |> Enum.map(&elem(&1, 0))
      end
    ])
  end

  # A content-derived, seed-parameterized permutation (no global rand state).
  defp reorder(tags, seed), do: Enum.sort_by(tags, &:erlang.phash2({&1, seed}))

  defp trait_id_set(%Capsule{categories: categories}) do
    for c <- categories, t <- c.traits, into: MapSet.new(), do: t.id
  end

  # --- struct builders ------------------------------------------------------

  defp me_file(tags), do: %MeFile{id: 1, me_file_tags: tags}

  defp build_tag(id, value, date) do
    case Map.fetch!(@effective_traits, id) do
      {_cat_id, :leaf} -> leaf_tag(id, value, date)
      {_cat_id, :parent} -> parent_tag(id, value, date)
    end
  end

  defp leaf_tag(id, value, date) do
    %MeFileTag{id: nil, trait: effective_trait(id), tag_value: value, added_date: date}
  end

  defp parent_tag(id, value, date) do
    parent = effective_trait(id)

    child = %Trait{
      id: id * 1000,
      trait_name: value,
      parent_trait_id: parent.id,
      parent_trait: parent,
      trait_category_id: nil,
      trait_category: nil
    }

    %MeFileTag{id: nil, trait: child, tag_value: nil, added_date: date}
  end

  defp effective_trait(id) do
    {cat_id, _kind} = Map.fetch!(@effective_traits, id)

    %Trait{
      id: id,
      trait_name: "Trait #{id}",
      display_order: id,
      parent_trait_id: nil,
      parent_trait: nil,
      trait_category_id: cat_id,
      trait_category: category(cat_id)
    }
  end

  defp category(id) do
    %TraitCategory{id: id, name: Map.fetch!(@categories, id), display_order: id}
  end
end
