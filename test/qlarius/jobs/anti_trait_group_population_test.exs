defmodule Qlarius.Jobs.AntiTraitGroupPopulationTest do
  use Qlarius.DataCase, async: true

  import Qlarius.TargetingFixtures

  alias Qlarius.Jobs.{PopulateTargetWorker, SyncMeFileToTargetPopulationsWorker}
  alias Qlarius.Sponster.Campaigns.{BandMatch, Campaign, TargetBand, TargetPopulation, Targets}

  setup do
    marketer = marketer_fixture()
    owner = %{marketer_id: marketer.id}

    food = parent_trait_fixture("Favorite food")
    burgers = trait_fixture(food, "Burgers", 1)
    diet = parent_trait_fixture("Diet")
    vegan = trait_fixture(diet, "Vegan", 1)
    keto = trait_fixture(diet, "Keto", 2)

    g_burgers = trait_group_fixture(owner, [burgers])
    g_keto = trait_group_fixture(owner, [keto])
    anti_vegan = anti_trait_group_fixture(owner, [vegan])

    %{
      marketer: marketer,
      owner: owner,
      burgers: burgers,
      vegan: vegan,
      keto: keto,
      g_burgers: g_burgers,
      g_keto: g_keto,
      anti_vegan: anti_vegan
    }
  end

  defp populate!(target) do
    assert {:ok, _} = PopulateTargetWorker.perform(%Oban.Job{args: %{"target_id" => target.id}})
  end

  defp populations(target) do
    from(tp in TargetPopulation,
      join: tb in TargetBand,
      on: tb.id == tp.target_band_id,
      where: tb.target_id == ^target.id,
      select: {tp.me_file_id, tb.id, tp.matching_tags_snapshot},
      order_by: [asc: tp.me_file_id]
    )
    |> Repo.all()
  end

  describe "BandMatch" do
    test "matches include-all and anti-none", ctx do
      burger_vegan = me_file_fixture([ctx.burgers, ctx.vegan])
      burger_only = me_file_fixture([ctx.burgers])
      vegan_only = me_file_fixture([ctx.vegan])

      groups = Repo.preload([ctx.g_burgers, ctx.anti_vegan], :traits)
      ids = BandMatch.me_file_ids(BandMatch.trait_id_sets(groups))

      assert burger_only.id in ids
      refute burger_vegan.id in ids
      refute vegan_only.id in ids

      assert {true, cache} = BandMatch.matches?(burger_only.id, groups)
      assert {true, ^cache} = BandMatch.matches?(burger_only.id, groups, cache)
      assert {false, _} = BandMatch.matches?(burger_vegan.id, groups)
    end

    test "an empty anti-group removes nobody and an anti-only band matches nobody", ctx do
      burger_only = me_file_fixture([ctx.burgers])
      empty_anti = anti_trait_group_fixture(ctx.owner, [])

      groups = Repo.preload([ctx.g_burgers, empty_anti], :traits)
      assert burger_only.id in BandMatch.me_file_ids(BandMatch.trait_id_sets(groups))

      anti_only = Repo.preload([ctx.anti_vegan], :traits)
      assert BandMatch.me_file_ids(BandMatch.trait_id_sets(anti_only)) == []
      assert {false, _} = BandMatch.matches?(burger_only.id, anti_only)
    end

    test "Targets.reach_for_groups reports included and removed", ctx do
      me_file_fixture([ctx.burgers, ctx.vegan])
      me_file_fixture([ctx.burgers])

      assert %{included: 2, removed: 1, reach: 1} =
               Targets.reach_for_groups([ctx.g_burgers.id, ctx.anti_vegan.id])

      assert Targets.me_file_ids_matching_groups([ctx.g_burgers.id, ctx.anti_vegan.id])
             |> length() == 1
    end
  end

  describe "PopulateTargetWorker" do
    test "a ring that drops the anti-group readmits the removed people", ctx do
      # Outer ring: Burgers. Bullseye: Burgers and not Vegan.
      target = target_fixture(ctx.owner, [[ctx.g_burgers], [ctx.g_burgers, ctx.anti_vegan]])
      [bullseye, ring] = Targets.get_bands_for_target(target.id)
      assert bullseye.is_bullseye == "1"

      burger_vegan = me_file_fixture([ctx.burgers, ctx.vegan])
      burger_only = me_file_fixture([ctx.burgers])
      _vegan_only = me_file_fixture([ctx.vegan])

      populate!(target)

      rows = populations(target)
      assert length(rows) == 2

      assert {_, band_id, snapshot} = Enum.find(rows, &(elem(&1, 0) == burger_only.id))
      assert band_id == bullseye.id
      assert [[_, "Favorite food", _, [[_, "Burgers", _]]]] = snapshot["tags"]

      assert {_, band_id, snapshot} = Enum.find(rows, &(elem(&1, 0) == burger_vegan.id))
      assert band_id == ring.id
      refute inspect(snapshot) =~ "Vegan"

      assert Repo.reload!(bullseye).tier == 0
      assert Repo.reload!(ring).tier == 1
    end

    test "hash and reuse distinguish polarity", ctx do
      with_anti = target_fixture(ctx.owner, [[ctx.g_burgers, ctx.anti_vegan]])
      without = target_fixture(ctx.owner, [[ctx.g_burgers]])
      me_file_fixture([ctx.burgers, ctx.vegan])

      populate!(without)
      populate!(with_anti)

      [with_band] = Targets.get_bands_for_target(with_anti.id)
      [without_band] = Targets.get_bands_for_target(without.id)
      refute Repo.reload!(with_band).definition_hash == Repo.reload!(without_band).definition_hash

      assert length(populations(without)) == 1
      assert populations(with_anti) == []
    end
  end

  describe "SyncMeFileToTargetPopulationsWorker" do
    test "moves a MeFile out when it gains an anti trait", ctx do
      target = target_fixture(ctx.owner, [[ctx.g_burgers, ctx.anti_vegan]])

      %Campaign{}
      |> Ecto.Changeset.change(%{title: "C", target_id: target.id, marketer_id: ctx.marketer.id})
      |> Repo.insert!()

      me_file = me_file_fixture([ctx.burgers])

      assert :ok =
               SyncMeFileToTargetPopulationsWorker.perform(%Oban.Job{
                 args: %{"me_file_id" => me_file.id}
               })

      assert length(populations(target)) == 1

      tag_me_file!(me_file, [ctx.vegan])

      assert :ok =
               SyncMeFileToTargetPopulationsWorker.perform(%Oban.Job{
                 args: %{"me_file_id" => me_file.id}
               })

      assert populations(target) == []
    end
  end

  describe "Targets.attach_anti_group/3" do
    test "attaches to every band by default or to chosen bands", ctx do
      target = target_fixture(ctx.owner, [[ctx.g_burgers], [ctx.g_burgers, ctx.g_keto]])
      [bullseye, ring] = Targets.get_bands_for_target(target.id)

      assert {:ok, ids} = Targets.attach_anti_group(target.id, ctx.anti_vegan.id)
      assert Enum.sort(ids) == Enum.sort([bullseye.id, ring.id])

      anti_two = anti_trait_group_fixture(ctx.owner, [trait_fixture(parent_trait_fixture(), "X")])

      assert {:ok, [band_id]} =
               Targets.attach_anti_group(target.id, anti_two.id, band_ids: [bullseye.id])

      assert band_id == bullseye.id

      counts =
        Targets.get_bands_for_target(target.id)
        |> Map.new(&{&1.id, length(&1.trait_groups)})

      assert counts == %{bullseye.id => 4, ring.id => 2}
    end

    test "rolls back when any band refuses", ctx do
      target = target_fixture(ctx.owner, [[ctx.g_burgers], [ctx.g_burgers, ctx.g_keto]])
      anti_keto = anti_trait_group_fixture(ctx.owner, [ctx.keto])

      assert {:error, {:trait_in_both_roles, _}} =
               Targets.attach_anti_group(target.id, anti_keto.id)

      for band <- Targets.get_bands_for_target(target.id) do
        refute anti_keto.id in Enum.map(band.trait_groups, & &1.id)
      end
    end
  end
end
