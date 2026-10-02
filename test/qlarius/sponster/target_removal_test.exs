defmodule Qlarius.Sponster.TargetRemovalTest do
  use Qlarius.DataCase, async: true

  import Qlarius.TargetingFixtures

  alias Qlarius.Sponster.Campaigns.{
    Campaign,
    Target,
    TargetBand,
    TargetBandTraitGroup,
    TargetPopulation,
    Targets,
    TraitGroup
  }

  setup do
    marketer = marketer_fixture()
    trait = trait_fixture(parent_trait_fixture())
    group = trait_group_fixture(%{marketer_id: marketer.id}, [trait])
    target = target_fixture(%{marketer_id: marketer.id}, [[group]])
    [band] = Repo.all(from tb in TargetBand, where: tb.target_id == ^target.id)
    me_file = me_file_fixture([trait])

    Repo.insert!(%TargetPopulation{
      target_band_id: band.id,
      me_file_id: me_file.id,
      matching_tags_snapshot: %{}
    })

    %{marketer: marketer, target: target, band: band, group: group}
  end

  defp campaign!(marketer, target, attrs \\ %{}) do
    %Campaign{}
    |> Campaign.changeset(
      Map.merge(
        %{
          marketer_id: marketer.id,
          target_id: target.id,
          media_sequence_id: 1,
          title: "C #{System.unique_integer([:positive])}",
          start_date: NaiveDateTime.utc_now(:second)
        },
        attrs
      )
    )
    |> Repo.insert!()
  end

  describe "delete_target/1" do
    test "removes the target, its bands, links and population but keeps trait groups", ctx do
      assert {:ok, _} = Targets.delete_target(ctx.target)

      refute Repo.get(Target, ctx.target.id)
      refute Repo.get(TargetBand, ctx.band.id)
      assert Repo.all(from p in TargetPopulation, where: p.target_band_id == ^ctx.band.id) == []

      assert Repo.all(from l in TargetBandTraitGroup, where: l.target_band_id == ^ctx.band.id) ==
               []

      assert Repo.get(TraitGroup, ctx.group.id)
    end

    test "is refused once any campaign has used the target, even a deactivated one", ctx do
      now = NaiveDateTime.utc_now(:second)
      campaign!(ctx.marketer, ctx.target, %{launched_at: now, deactivated_at: now})

      assert {:error, :used_in_campaign} = Targets.delete_target(ctx.target)
      assert Repo.get(Target, ctx.target.id)
    end
  end

  describe "archive_target/1" do
    test "moves a target to the archived list and back", ctx do
      campaign!(ctx.marketer, ctx.target)

      assert {:ok, _} = Targets.archive_target(ctx.target)
      assert Targets.list_targets_for_marketer(ctx.marketer.id) == []

      assert [%{id: id}] = Targets.list_archived_targets_for_marketer(ctx.marketer.id)
      assert id == ctx.target.id

      assert {:ok, archived} = Targets.archive_target(ctx.target)
      assert {:ok, _} = Targets.unarchive_target(archived)
      assert [%{id: ^id}] = Targets.list_targets_for_marketer(ctx.marketer.id)
    end

    test "is refused while a live campaign uses the target", ctx do
      campaign!(ctx.marketer, ctx.target, %{launched_at: NaiveDateTime.utc_now(:second)})

      assert {:error, :in_live_campaign} = Targets.archive_target(ctx.target)
    end
  end

  test "list stats flag whether a campaign has used the target", ctx do
    assert [%{used_in_campaign: false}] = Targets.list_targets_for_marketer(ctx.marketer.id)

    campaign!(ctx.marketer, ctx.target)

    assert [%{used_in_campaign: true}] = Targets.list_targets_for_marketer(ctx.marketer.id)
  end
end
