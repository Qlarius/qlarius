defmodule Qlarius.Sponster.Campaigns.AntiTraitGroupRulesTest do
  use Qlarius.DataCase, async: true

  import Qlarius.TargetingFixtures

  alias Qlarius.Repo
  alias Qlarius.Sponster.Campaigns.{BandDefinition, Targets, TraitGroup}

  setup do
    marketer = marketer_fixture()
    owner = %{marketer_id: marketer.id}
    diet = parent_trait_fixture("Diet")
    vegan = trait_fixture(diet, "Vegan")
    keto = trait_fixture(diet, "Keto")
    food = parent_trait_fixture("Favorite food")
    burgers = trait_fixture(food, "Burgers")

    %{
      owner: owner,
      burgers_group: trait_group_fixture(owner, [burgers]),
      keto_group: trait_group_fixture(owner, [keto]),
      anti_vegan: anti_trait_group_fixture(owner, [vegan]),
      anti_keto: anti_trait_group_fixture(owner, [keto]),
      vegan: vegan,
      keto: keto,
      burgers: burgers
    }
  end

  describe "TraitGroup.changeset/2" do
    test "defaults role to include and rejects unknown roles", ctx do
      group = Repo.reload!(ctx.burgers_group)
      assert group.role == "include"

      changeset =
        TraitGroup.changeset(%TraitGroup{}, %{title: "x", marketer_id: 1, role: "maybe"})

      assert %{role: ["is invalid"]} = errors_on(changeset)
    end

    test "role is immutable after insert", ctx do
      changeset = TraitGroup.changeset(ctx.burgers_group, %{role: "anti"})
      assert {"cannot change after creation", [reason: :role_immutable]} = changeset.errors[:role]
    end
  end

  describe "band rules" do
    test "an anti-group cannot be the only group on a band", ctx do
      target = target_fixture(ctx.owner, [])
      {:ok, band} = Targets.create_bullseye_band(target.id)

      assert {:error, :include_group_required} =
               Targets.add_trait_group_to_band(band.id, ctx.anti_vegan.id)

      assert {:ok, _} = Targets.add_trait_group_to_band(band.id, ctx.burgers_group.id)
      assert {:ok, _} = Targets.add_trait_group_to_band(band.id, ctx.anti_vegan.id)

      assert {:error, :include_group_required} =
               Targets.remove_trait_group_from_band(band.id, ctx.burgers_group.id)
    end

    test "a trait cannot sit in both roles on one band", ctx do
      target = target_fixture(ctx.owner, [[ctx.keto_group]])
      [band] = Targets.get_bands_for_target(target.id)

      assert {:error, {:trait_in_both_roles, [trait_id]}} =
               Targets.add_trait_group_to_band(band.id, ctx.anti_keto.id)

      assert trait_id == ctx.keto.id
    end

    test "expansion may drop an anti-group and keeps the include group", ctx do
      target = target_fixture(ctx.owner, [[ctx.burgers_group, ctx.anti_vegan]])

      assert {:ok, ring} = Targets.create_outer_band(target.id, ctx.anti_vegan.id)
      ring = Repo.preload(ring, :trait_groups)
      assert Enum.map(ring.trait_groups, & &1.id) == [ctx.burgers_group.id]

      bands = Targets.get_bands_for_target(target.id)
      assert Targets.outermost_band(bands).id == ring.id
    end

    test "expansion refuses to leave only anti-groups", ctx do
      target = target_fixture(ctx.owner, [[ctx.burgers_group, ctx.anti_vegan]])

      assert {:error, :include_group_required} =
               Targets.create_outer_band(target.id, ctx.burgers_group.id)
    end
  end

  describe "BandDefinition.hash/2" do
    test "matches the legacy hash when no anti-groups are present" do
      assert BandDefinition.hash([[1, 2]]) == BandDefinition.hash([[2, 1]], [])
      assert BandDefinition.hash([[1, 2]]) == BandDefinition.hash([[1, 2]], [[]])
    end

    test "polarity changes the fingerprint" do
      include_only = BandDefinition.hash([[1, 2]])
      with_anti = BandDefinition.hash([[1, 2]], [[3]])
      refute include_only == with_anti
      refute BandDefinition.hash([[1, 2], [3]]) == with_anti
      assert with_anti == BandDefinition.hash([[2, 1]], [[3]])
    end

    test "hash_for_band splits by role", ctx do
      target = target_fixture(ctx.owner, [[ctx.burgers_group, ctx.anti_vegan]])
      [band] = Targets.get_bands_for_target(target.id)

      assert BandDefinition.hash_for_band(band) ==
               BandDefinition.hash([[ctx.burgers.id]], [[ctx.vegan.id]])
    end
  end
end
