defmodule Qlarius.Jobs.PopulationReuseTest do
  use Qlarius.DataCase, async: true

  import Qlarius.TargetingFixtures

  alias Qlarius.Jobs.PopulateTargetWorker
  alias Qlarius.Sponster.Campaigns.{BandDefinition, TargetBand, TargetPopulation}

  setup do
    marketer = marketer_fixture()
    %{marketer: marketer, owner: %{marketer_id: marketer.id}}
  end

  defp populate!(target) do
    assert {:ok, _} = PopulateTargetWorker.perform(%Oban.Job{args: %{"target_id" => target.id}})
  end

  defp populations(target) do
    from(tp in TargetPopulation,
      join: tb in TargetBand,
      on: tb.id == tp.target_band_id,
      where: tb.target_id == ^target.id,
      select: {tp.me_file_id, tb.tier, tp.matching_tags_snapshot},
      order_by: [asc: tp.me_file_id]
    )
    |> Repo.all()
  end

  describe "BandDefinition.hash/1" do
    test "is order-independent within and between groups" do
      assert BandDefinition.hash([[3, 1, 2], [9, 8]]) ==
               BandDefinition.hash([[8, 9], [2, 3, 1]])
    end

    test "distinguishes different trait sets" do
      refute BandDefinition.hash([[1, 2]]) == BandDefinition.hash([[1, 3]])
      refute BandDefinition.hash([[1], [2]]) == BandDefinition.hash([[1, 2]])
    end

    test "ignores duplicate trait ids" do
      assert BandDefinition.hash([[1, 1, 2]]) == BandDefinition.hash([[1, 2]])
    end

    test "returns nil for bands that can match nobody" do
      assert BandDefinition.hash([]) == nil
      assert BandDefinition.hash([[]]) == nil
      assert BandDefinition.hash([[1], []]) == nil
    end
  end

  describe "BandDefinition.reusable?/1" do
    test "requires every hash present and all distinct" do
      assert BandDefinition.reusable?(["a", "b"])
      refute BandDefinition.reusable?([])
      refute BandDefinition.reusable?(["a", nil])
      refute BandDefinition.reusable?(["a", "a"])
    end
  end

  describe "populating a target" do
    setup %{owner: owner} do
      parent = parent_trait_fixture("Interests")
      music = trait_fixture(parent, "Music", 1)
      travel = trait_fixture(parent, "Travel", 2)
      coffee = trait_fixture(parent, "Coffee", 3)

      g_music = trait_group_fixture(owner, [music])
      g_travel = trait_group_fixture(owner, [travel])

      # Two rings: outer requires Music, inner requires Music AND Travel.
      target = target_fixture(owner, [[g_music], [g_music, g_travel]])

      outer_only = me_file_fixture([music, coffee])
      both = me_file_fixture([music, travel])
      neither = me_file_fixture([coffee])

      %{
        target: target,
        groups: %{music: g_music, travel: g_travel},
        traits: %{music: music, travel: travel, coffee: coffee},
        me_files: %{outer_only: outer_only, both: both, neither: neither}
      }
    end

    test "assigns each me_file to its innermost matching band", ctx do
      populate!(ctx.target)

      rows = populations(ctx.target)
      by_me_file = Map.new(rows, fn {mf, tier, _snap} -> {mf, tier} end)

      # tier 0 is the most restrictive band, tier 1 the outer ring.
      assert by_me_file[ctx.me_files.both.id] == 0
      assert by_me_file[ctx.me_files.outer_only.id] == 1
      refute Map.has_key?(by_me_file, ctx.me_files.neither.id)
    end

    test "writes definition_hash and population_count onto every band", ctx do
      populate!(ctx.target)

      bands =
        from(tb in TargetBand, where: tb.target_id == ^ctx.target.id, order_by: tb.tier)
        |> Repo.all()

      assert Enum.all?(bands, &is_binary(&1.definition_hash))
      assert Enum.map(bands, & &1.population_count) == [1, 1]
    end

    test "population_count counts innermost assignment, not everyone qualifying", ctx do
      # `both` satisfies the outer ring's criteria too, but is recorded only
      # against the inner band, so the outer count must not include them.
      populate!(ctx.target)

      counts =
        from(tb in TargetBand,
          where: tb.target_id == ^ctx.target.id,
          select: {tb.tier, tb.population_count}
        )
        |> Repo.all()
        |> Map.new()

      assert counts[0] == 1
      assert counts[1] == 1
    end
  end

  describe "population reuse" do
    setup %{owner: owner} do
      parent = parent_trait_fixture("Interests")
      music = trait_fixture(parent, "Music", 1)
      travel = trait_fixture(parent, "Travel", 2)
      coffee = trait_fixture(parent, "Coffee", 3)

      g_music = trait_group_fixture(owner, [music])
      g_travel = trait_group_fixture(owner, [travel])

      _outer_only = me_file_fixture([music, coffee])
      _both = me_file_fixture([music, travel])
      _neither = me_file_fixture([coffee])

      %{
        traits: %{music: music, travel: travel, coffee: coffee},
        groups: %{music: g_music, travel: g_travel}
      }
    end

    test "a structural clone produces rows identical to a from-scratch scan", ctx do
      %{owner: owner, groups: groups} = ctx

      source = target_fixture(owner, [[groups.music], [groups.music, groups.travel]])
      populate!(source)

      # Same shape, but its own trait_group rows holding the same traits — so
      # nothing is shared by id, only by content.
      clone_music = trait_group_fixture(owner, [ctx.traits.music])
      clone_travel = trait_group_fixture(owner, [ctx.traits.travel])
      clone = target_fixture(owner, [[clone_music], [clone_music, clone_travel]])

      populate!(clone)

      assert populations(source) == populations(clone)
      assert populations(clone) != []
    end

    test "the copy is taken rather than scanned", ctx do
      %{owner: owner, groups: groups} = ctx

      source = target_fixture(owner, [[groups.music], [groups.music, groups.travel]])
      populate!(source)

      clone = target_fixture(owner, [[groups.music], [groups.music, groups.travel]])

      assert {:ok, :copied} =
               PopulateTargetWorker.perform(%Oban.Job{args: %{"target_id" => clone.id}})
    end

    test "reuse is skipped when only some bands have twins", ctx do
      %{owner: owner, groups: groups} = ctx

      source = target_fixture(owner, [[groups.music], [groups.music, groups.travel]])
      populate!(source)

      # Shares the outer band's definition but not the inner one.
      g_coffee = trait_group_fixture(owner, [ctx.traits.coffee])
      partial = target_fixture(owner, [[groups.music], [groups.music, g_coffee]])

      assert {:ok, :scanned} =
               PopulateTargetWorker.perform(%Oban.Job{args: %{"target_id" => partial.id}})
    end

    test "an unpopulated target is not used as a source", ctx do
      %{owner: owner, groups: groups} = ctx

      _never_populated =
        target_fixture(owner, [[groups.music], [groups.music, groups.travel]])

      clone = target_fixture(owner, [[groups.music], [groups.music, groups.travel]])

      assert {:ok, :scanned} =
               PopulateTargetWorker.perform(%Oban.Job{args: %{"target_id" => clone.id}})
    end

    test "a copy carries the same snapshots as a scan", ctx do
      %{owner: owner, groups: groups} = ctx

      source = target_fixture(owner, [[groups.music], [groups.music, groups.travel]])
      populate!(source)

      clone = target_fixture(owner, [[groups.music], [groups.music, groups.travel]])
      populate!(clone)

      source_snaps = populations(source) |> Enum.map(fn {_mf, _t, snap} -> snap end)
      clone_snaps = populations(clone) |> Enum.map(fn {_mf, _t, snap} -> snap end)

      assert source_snaps == clone_snaps
      refute Enum.any?(source_snaps, &is_nil/1)
    end

    test "a source whose stored hash is stale is not trusted", ctx do
      %{owner: owner, groups: groups} = ctx

      source = target_fixture(owner, [[groups.music], [groups.music, groups.travel]])
      populate!(source)

      # Simulate drift: the stored fingerprints claim to match the clone, but
      # the source's actual trait groups no longer do.
      clone_music = trait_group_fixture(owner, [ctx.traits.music])
      clone_coffee = trait_group_fixture(owner, [ctx.traits.coffee])
      clone = target_fixture(owner, [[clone_music], [clone_music, clone_coffee]])

      clone_hashes =
        from(tb in TargetBand, where: tb.target_id == ^clone.id, select: tb.id)
        |> Repo.all()

      # Give the source the clone's fingerprints without changing its traits.
      source_band_ids =
        from(tb in TargetBand, where: tb.target_id == ^source.id, order_by: tb.id, select: tb.id)
        |> Repo.all()

      fake_hashes = Enum.map(clone_hashes, fn id -> "fake-#{id}" end)

      Enum.zip(source_band_ids, fake_hashes)
      |> Enum.each(fn {band_id, hash} ->
        from(tb in TargetBand, where: tb.id == ^band_id)
        |> Repo.update_all(set: [definition_hash: hash])
      end)

      from(tb in TargetBand, where: tb.target_id == ^clone.id)
      |> Repo.all()
      |> Enum.zip(fake_hashes)
      |> Enum.each(fn {band, hash} ->
        from(tb in TargetBand, where: tb.id == ^band.id)
        |> Repo.update_all(set: [definition_hash: hash])
      end)

      # Verification recomputes from real trait groups, so the bogus match is
      # rejected and the clone is scanned on its own terms.
      assert {:ok, :scanned} =
               PopulateTargetWorker.perform(%Oban.Job{args: %{"target_id" => clone.id}})

      # Both targets reach the same two people, but assign them to opposite
      # rings — Music+Travel puts `both` in the bullseye, Music+Coffee puts
      # `outer_only` there. Comparing me_file ids alone would miss a bad copy,
      # so compare the assignment.
      assignment = fn target ->
        target |> populations() |> Map.new(fn {mf, tier, _snap} -> {mf, tier} end)
      end

      refute assignment.(clone) == assignment.(source)
    end
  end
end
