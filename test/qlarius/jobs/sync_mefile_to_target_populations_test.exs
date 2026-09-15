defmodule Qlarius.Jobs.SyncMeFileToTargetPopulationsTest do
  use Qlarius.DataCase, async: true

  import Qlarius.TargetingFixtures

  alias Qlarius.Jobs.{PopulateTargetWorker, SyncMeFileToTargetPopulationsWorker}
  alias Qlarius.Sponster.Campaigns.{Campaign, TargetBand, TargetPopulation}
  alias Qlarius.Tiqit.ContentAudienceTarget

  setup do
    marketer = marketer_fixture()
    parent = parent_trait_fixture("Interests")

    music = trait_fixture(parent, "Music", 1)
    travel = trait_fixture(parent, "Travel", 2)
    coffee = trait_fixture(parent, "Coffee", 3)

    owner = %{marketer_id: marketer.id}

    %{
      marketer: marketer,
      owner: owner,
      music: music,
      travel: travel,
      coffee: coffee,
      g_music: trait_group_fixture(owner, [music]),
      g_travel: trait_group_fixture(owner, [travel])
    }
  end

  defp campaign_for!(target, marketer) do
    %Campaign{}
    |> Ecto.Changeset.change(%{
      title: "C #{System.unique_integer([:positive])}",
      target_id: target.id,
      marketer_id: marketer.id
    })
    |> Repo.insert!()
  end

  defp sync!(me_file) do
    assert :ok =
             SyncMeFileToTargetPopulationsWorker.perform(%Oban.Job{
               args: %{"me_file_id" => me_file.id}
             })
  end

  defp bands_for(me_file) do
    from(tp in TargetPopulation,
      join: tb in TargetBand,
      on: tb.id == tp.target_band_id,
      where: tp.me_file_id == ^me_file.id,
      select: tb.target_id,
      order_by: tb.target_id
    )
    |> Repo.all()
  end

  test "syncs a target driving a live campaign", ctx do
    target = target_fixture(ctx.owner, [[ctx.g_music]])
    campaign_for!(target, ctx.marketer)

    me_file = me_file_fixture([ctx.music])
    sync!(me_file)

    assert bands_for(me_file) == [target.id]
  end

  test "syncs a target attached to creator content but driving no campaign", ctx do
    target = target_fixture(ctx.owner, [[ctx.g_music]])

    %ContentAudienceTarget{}
    |> ContentAudienceTarget.changeset(%{
      target_id: target.id,
      creator_id: creator_fixture().id,
      mode: :boost
    })
    |> Repo.insert!()

    me_file = me_file_fixture([ctx.music])
    sync!(me_file)

    # Before widening, a content-only audience had no campaign to be found
    # through, so its population silently stopped tracking user retagging.
    assert bands_for(me_file) == [target.id]
  end

  test "ignores a target with neither a campaign nor a content attachment", ctx do
    _orphan = target_fixture(ctx.owner, [[ctx.g_music]])

    me_file = me_file_fixture([ctx.music])
    sync!(me_file)

    assert bands_for(me_file) == []
  end

  test "ignores a target whose only campaign is deactivated", ctx do
    target = target_fixture(ctx.owner, [[ctx.g_music]])

    campaign_for!(target, ctx.marketer)
    |> Ecto.Changeset.change(%{
      deactivated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    })
    |> Repo.update!()

    me_file = me_file_fixture([ctx.music])
    sync!(me_file)

    assert bands_for(me_file) == []
  end

  test "places the me_file in the same band the batch worker would", ctx do
    target = target_fixture(ctx.owner, [[ctx.g_music], [ctx.g_music, ctx.g_travel]])
    campaign_for!(target, ctx.marketer)

    me_file = me_file_fixture([ctx.music, ctx.travel])

    # Batch first, so the two paths can be compared on the same data.
    assert {:ok, _} = PopulateTargetWorker.perform(%Oban.Job{args: %{"target_id" => target.id}})

    batch_band =
      from(tp in TargetPopulation,
        where: tp.me_file_id == ^me_file.id,
        select: tp.target_band_id
      )
      |> Repo.one()

    Repo.delete_all(from(tp in TargetPopulation, where: tp.me_file_id == ^me_file.id))
    sync!(me_file)

    incremental_band =
      from(tp in TargetPopulation,
        where: tp.me_file_id == ^me_file.id,
        select: tp.target_band_id
      )
      |> Repo.one()

    assert incremental_band == batch_band
  end

  test "memoizing trait groups does not leak a verdict between different groups", ctx do
    # Two targets whose bands differ only in which group they require. If the
    # cache were keyed on anything coarser than the trait id set, the second
    # target would inherit the first's answer.
    matching = target_fixture(ctx.owner, [[ctx.g_music]])
    non_matching = target_fixture(ctx.owner, [[ctx.g_travel]])

    campaign_for!(matching, ctx.marketer)
    campaign_for!(non_matching, ctx.marketer)

    me_file = me_file_fixture([ctx.music])
    sync!(me_file)

    assert bands_for(me_file) == [matching.id]
  end

  test "reuses one verdict for content-identical groups across targets", ctx do
    # Distinct trait_group rows holding the same trait: the cache is keyed on
    # the trait id set, so both targets resolve from a single lookup and must
    # still agree.
    twin = trait_group_fixture(ctx.owner, [ctx.music])

    a = target_fixture(ctx.owner, [[ctx.g_music]])
    b = target_fixture(ctx.owner, [[twin]])

    campaign_for!(a, ctx.marketer)
    campaign_for!(b, ctx.marketer)

    me_file = me_file_fixture([ctx.music])
    sync!(me_file)

    assert bands_for(me_file) == Enum.sort([a.id, b.id])
  end

  test "removes a population once the me_file no longer qualifies", ctx do
    target = target_fixture(ctx.owner, [[ctx.g_music]])
    campaign_for!(target, ctx.marketer)

    me_file = me_file_fixture([ctx.music])
    sync!(me_file)
    assert bands_for(me_file) == [target.id]

    Repo.delete_all(
      from(t in Qlarius.YouData.MeFiles.MeFileTag,
        where: t.me_file_id == ^me_file.id and t.trait_id == ^ctx.music.id
      )
    )

    sync!(me_file)
    assert bands_for(me_file) == []
  end

  test "a target sharing several campaigns is resolved once, not once per campaign", ctx do
    target = target_fixture(ctx.owner, [[ctx.g_music]])

    for _ <- 1..3, do: campaign_for!(target, ctx.marketer)

    me_file = me_file_fixture([ctx.music])
    sync!(me_file)

    assert bands_for(me_file) == [target.id]
  end
end
