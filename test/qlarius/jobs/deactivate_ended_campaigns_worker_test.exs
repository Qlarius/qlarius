defmodule Qlarius.Jobs.DeactivateEndedCampaignsWorkerTest do
  use Qlarius.DataCase, async: true

  alias Qlarius.AdCategoryFixtures
  alias Qlarius.Jobs.DeactivateEndedCampaignsWorker
  alias Qlarius.Repo
  alias Qlarius.Sponster.Campaigns.{Campaign, MediaRun, MediaSequence, Target, TargetBand}
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

    %{
      marketer: marketer,
      piece: piece,
      sequence: sequence,
      media_run: media_run,
      target: target,
      band: band,
      me_file: Repo.insert!(%MeFile{})
    }
  end

  test "deactivates a launched campaign whose end date has passed and deletes its offers",
       ctx do
    campaign = campaign!(ctx, launched_at: hours_ago(48), end_date: hours_ago(1))
    offer = offer!(ctx, campaign)

    assert :ok = DeactivateEndedCampaignsWorker.perform(%Oban.Job{args: %{}})

    assert Repo.get!(Campaign, campaign.id).deactivated_at
    refute Repo.get(Offer, offer.id)
  end

  test "leaves running, open-ended, draft and already stopped campaigns alone", ctx do
    running = campaign!(ctx, launched_at: hours_ago(48), end_date: hours_from_now(24))
    open_ended = campaign!(ctx, launched_at: hours_ago(48), end_date: nil)
    draft = campaign!(ctx, launched_at: nil, end_date: hours_ago(1))
    stopped_at = hours_ago(5)

    stopped =
      campaign!(ctx, launched_at: hours_ago(48), end_date: hours_ago(1), deactivated_at: stopped_at)

    running_offer = offer!(ctx, running)

    assert :ok = DeactivateEndedCampaignsWorker.perform(%Oban.Job{args: %{}})

    refute Repo.get!(Campaign, running.id).deactivated_at
    refute Repo.get!(Campaign, open_ended.id).deactivated_at
    refute Repo.get!(Campaign, draft.id).deactivated_at
    assert Repo.get!(Campaign, stopped.id).deactivated_at == stopped_at
    assert Repo.get(Offer, running_offer.id)
  end

  defp campaign!(ctx, opts) do
    %Campaign{}
    |> Campaign.changeset(%{
      marketer_id: ctx.marketer.id,
      title: "Campaign #{System.unique_integer([:positive])}",
      target_id: ctx.target.id,
      media_sequence_id: ctx.sequence.id,
      start_date: hours_ago(72)
    })
    |> Ecto.Changeset.change(Map.new(opts))
    |> Repo.insert!()
  end

  defp offer!(ctx, campaign) do
    %Offer{}
    |> Offer.changeset(%{
      campaign_id: campaign.id,
      me_file_id: ctx.me_file.id,
      media_run_id: ctx.media_run.id,
      media_piece_id: ctx.piece.id,
      target_band_id: ctx.band.id,
      offer_amt: Decimal.new("0.21"),
      marketer_cost_amt: Decimal.new("0.30"),
      is_payable: true,
      is_throttled: false,
      is_jobbed: false,
      matching_tags_snapshot: %{},
      ad_phase_count_to_complete: 2,
      pending_until: hours_ago(24),
      is_current: true
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
