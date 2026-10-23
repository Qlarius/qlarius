defmodule Qlarius.Jobs.ReconcileOffersForMeFileWorkerTest do
  use Qlarius.DataCase, async: true

  alias Qlarius.AdCategoryFixtures
  alias Qlarius.Jobs.ReconcileOffersForMeFileWorker
  alias Qlarius.Repo

  alias Qlarius.Sponster.Campaigns.{
    Bid,
    Campaign,
    MediaRun,
    MediaSequence,
    Target,
    TargetBand,
    TargetPopulation
  }

  alias Qlarius.Sponster.Offer
  alias Qlarius.YouData.MeFiles.MeFile

  setup do
    marketer = AdCategoryFixtures.marketer_fixture()
    piece = AdCategoryFixtures.media_piece_fixture(AdCategoryFixtures.row_fixture(), marketer)

    sequence =
      %MediaSequence{}
      |> MediaSequence.changeset(%{title: "Seq", marketer_id: marketer.id})
      |> Repo.insert!()

    media_run =
      %MediaRun{}
      |> MediaRun.changeset(%{
        marketer_id: marketer.id,
        media_piece_id: piece.id,
        media_sequence_id: sequence.id,
        frequency: 3,
        frequency_buffer_hours: 24,
        maximum_banner_count: 3,
        banner_retry_buffer_hours: 10,
        is_active: true,
        sequence_start_phase: 1,
        sequence_end_phase: 2
      })
      |> Repo.insert!()

    target =
      %Target{}
      |> Target.changeset(%{title: "Target", marketer_id: marketer.id})
      |> Repo.insert!()

    band =
      %TargetBand{}
      |> TargetBand.changeset(%{target_id: target.id, is_bullseye: "1"})
      |> Repo.insert!()

    me_file = Repo.insert!(%MeFile{})

    %TargetPopulation{}
    |> TargetPopulation.changeset(%{
      target_band_id: band.id,
      me_file_id: me_file.id,
      matching_tags_snapshot: %{}
    })
    |> Repo.insert!()

    %{
      marketer: marketer,
      sequence: sequence,
      media_run: media_run,
      target: target,
      band: band,
      me_file: me_file
    }
  end

  test "a matching draft campaign gets no offer until it is launched", ctx do
    campaign = campaign!(ctx, launched_at: nil, start_date: hours_ago(1), end_date: nil)
    bid!(ctx, campaign)

    assert :ok =
             ReconcileOffersForMeFileWorker.perform(%Oban.Job{
               args: %{"me_file_id" => ctx.me_file.id}
             })

    refute Repo.get_by(Offer, campaign_id: campaign.id, me_file_id: ctx.me_file.id)

    Repo.update!(Ecto.Changeset.change(campaign, %{launched_at: hours_ago(1)}))

    assert :ok =
             ReconcileOffersForMeFileWorker.perform(%Oban.Job{
               args: %{"me_file_id" => ctx.me_file.id}
             })

    assert Repo.get_by(Offer, campaign_id: campaign.id, me_file_id: ctx.me_file.id)
  end

  test "a launched campaign outside its date window gets no offer", ctx do
    campaign =
      campaign!(ctx,
        launched_at: hours_ago(48),
        start_date: hours_from_now(2),
        end_date: nil
      )

    bid!(ctx, campaign)

    assert :ok =
             ReconcileOffersForMeFileWorker.perform(%Oban.Job{
               args: %{"me_file_id" => ctx.me_file.id}
             })

    refute Repo.get_by(Offer, campaign_id: campaign.id, me_file_id: ctx.me_file.id)
  end

  defp campaign!(ctx, opts) do
    %Campaign{}
    |> Campaign.changeset(%{
      marketer_id: ctx.marketer.id,
      title: "Campaign #{System.unique_integer([:positive])}",
      target_id: ctx.target.id,
      media_sequence_id: ctx.sequence.id,
      start_date: Keyword.get(opts, :start_date, hours_ago(1)),
      is_payable: true,
      is_throttled: false
    })
    |> Ecto.Changeset.change(Map.new(opts))
    |> Repo.insert!()
  end

  defp bid!(ctx, campaign) do
    %Bid{}
    |> Bid.changeset(%{
      campaign_id: campaign.id,
      media_run_id: ctx.media_run.id,
      target_band_id: ctx.band.id,
      offer_amt: Decimal.new("0.21"),
      marketer_cost_amt: Decimal.new("0.30")
    })
    |> Repo.insert!()
  end

  defp hours_ago(hours), do: hours_from_now(-hours)

  defp hours_from_now(hours) do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.add(hours * 3600, :second)
    |> NaiveDateTime.truncate(:second)
  end
end
