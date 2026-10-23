defmodule Qlarius.Sponster.DraftOfferCleanupTest do
  use Qlarius.DataCase, async: true

  alias Qlarius.AdCategoryFixtures
  alias Qlarius.Repo
  alias Qlarius.Sponster.AdEvent
  alias Qlarius.Sponster.Campaigns.{Campaign, MediaRun, MediaSequence, Target, TargetBand}
  alias Qlarius.Sponster.DraftOfferCleanup
  alias Qlarius.Sponster.Offer
  alias Qlarius.YouData.MeFiles.MeFile

  test "deletes draft offers and leaves launched offers and collected draft offers" do
    ctx = build!()
    draft = campaign!(ctx, nil)
    launched = campaign!(ctx, hours_ago(2))
    collected = campaign!(ctx, nil)

    draft_offer = offer!(ctx, draft)
    launched_offer = offer!(ctx, launched)
    collected_offer = offer!(ctx, collected)
    event!(ctx, collected_offer)

    assert %{deleted: deleted, kept_with_events: kept} =
             DraftOfferCleanup.delete_unlaunched_offers()

    assert deleted >= 1
    assert kept >= 1

    refute Repo.get(Offer, draft_offer.id)
    assert Repo.get(Offer, launched_offer.id)
    assert Repo.get(Offer, collected_offer.id)
  end

  defp build! do
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
        frequency: 1,
        frequency_buffer_hours: 24,
        maximum_banner_count: 1,
        banner_retry_buffer_hours: 1,
        is_active: true,
        sequence_start_phase: 1,
        sequence_end_phase: 1
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

  defp campaign!(ctx, launched_at) do
    %Campaign{}
    |> Campaign.changeset(%{
      marketer_id: ctx.marketer.id,
      title: "Campaign #{System.unique_integer([:positive])}",
      target_id: ctx.target.id,
      media_sequence_id: ctx.sequence.id,
      start_date: hours_ago(5)
    })
    |> Ecto.Changeset.change(%{launched_at: launched_at})
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
      ad_phase_count_to_complete: 1,
      pending_until: hours_ago(1),
      is_current: true
    })
    |> Repo.insert!()
  end

  defp event!(ctx, offer) do
    %AdEvent{}
    |> AdEvent.changeset(%{
      offer_bid_amt: offer.offer_amt,
      is_throttled: false,
      is_offer_complete: false,
      ip_address: "127.0.0.1",
      url: "https://example.com",
      offer_id: offer.id,
      me_file_id: ctx.me_file.id,
      campaign_id: offer.campaign_id,
      media_run_id: ctx.media_run.id,
      media_piece_id: ctx.piece.id,
      media_piece_phase_id: 1,
      target_band_id: ctx.band.id,
      is_payable: true,
      offer_marketer_cost_amt: offer.marketer_cost_amt,
      event_marketer_cost_amt: Decimal.new("0.06"),
      event_me_file_collect_amt: Decimal.new("0.05"),
      event_sponster_collect_amt: Decimal.new("0.01"),
      matching_tags_snapshot: %{}
    })
    |> Repo.insert!()
  end

  defp hours_ago(hours) do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.add(-hours * 3600, :second)
    |> NaiveDateTime.truncate(:second)
  end
end
