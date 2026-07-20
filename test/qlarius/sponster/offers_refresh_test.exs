defmodule Qlarius.Sponster.OffersRefreshTest do
  use Qlarius.DataCase, async: true

  alias Qlarius.Accounts.Marketer
  alias Qlarius.Repo
  alias Qlarius.Sponster.AdEvent
  alias Qlarius.Sponster.Ads.{AdCategory, MediaPiece, MediaPiecePhase, MediaPieceType}
  alias Qlarius.Sponster.Campaigns.{Campaign, MediaRun, MediaSequence, Target, TargetBand}
  alias Qlarius.Sponster.Offer
  alias Qlarius.Sponster.Offers
  alias Qlarius.YouData.MeFiles.MeFile

  describe "refresh_statuses_for_me_file/1" do
    test "parks a current 3-tap offer when banner was collected inside retry buffer" do
      %{me_file: me_file, offer: offer, phase_1_id: phase_1_id, media_run: media_run} =
        setup_current_three_tap_offer!(
          maximum_banner_count: 3,
          banner_retry_buffer_hours: 10
        )

      banner_at = hours_ago(2)
      insert_banner_event!(offer, phase_1_id, created_at: banner_at)

      assert {:ok, %{parked: 1, finalized: 0}} = Offers.refresh_statuses_for_me_file(me_file.id)

      refreshed = Repo.get!(Offer, offer.id)
      refute refreshed.is_current

      expected_pending =
        banner_at
        |> NaiveDateTime.add(media_run.banner_retry_buffer_hours * 3600, :second)
        |> NaiveDateTime.truncate(:second)

      assert refreshed.pending_until == expected_pending
    end

    test "keeps offer current when banner retry buffer has elapsed" do
      %{me_file: me_file, offer: offer, phase_1_id: phase_1_id} =
        setup_current_three_tap_offer!(
          maximum_banner_count: 3,
          banner_retry_buffer_hours: 10
        )

      insert_banner_event!(offer, phase_1_id, created_at: hours_ago(11))

      assert {:ok, %{parked: 0, finalized: 0}} = Offers.refresh_statuses_for_me_file(me_file.id)

      refreshed = Repo.get!(Offer, offer.id)
      assert refreshed.is_current
    end

    test "finalizes with banner_max completion when maximum_banner_count is reached" do
      %{me_file: me_file, offer: offer, phase_1_id: phase_1_id, media_run: media_run} =
        setup_current_three_tap_offer!(
          maximum_banner_count: 2,
          banner_retry_buffer_hours: 10,
          frequency: 3
        )

      insert_banner_event!(offer, phase_1_id, created_at: hours_ago(1))
      insert_banner_event!(offer, phase_1_id, created_at: hours_ago(0))

      assert {:ok, %{parked: 0, finalized: 1}} = Offers.refresh_statuses_for_me_file(me_file.id)
      assert is_nil(Repo.get(Offer, offer.id))

      banner_max =
        Repo.one(
          from ae in AdEvent,
            where: ae.offer_id == ^offer.id and ae.completion_kind == "banner_max"
        )

      assert banner_max
      assert banner_max.is_offer_complete
      refute banner_max.is_payable

      next =
        Repo.one(
          from o in Offer,
            where: o.me_file_id == ^me_file.id and o.media_run_id == ^media_run.id
        )

      assert next
      refute next.is_current
      assert next.id != offer.id
    end

    test "does not park or finalize offers with no banner events" do
      %{me_file: me_file, offer: offer} =
        setup_current_three_tap_offer!(
          maximum_banner_count: 2,
          banner_retry_buffer_hours: 10
        )

      assert {:ok, %{parked: 0, finalized: 0}} = Offers.refresh_statuses_for_me_file(me_file.id)

      refreshed = Repo.get!(Offer, offer.id)
      assert refreshed.is_current
    end

    test "finalizes current offers that already have a full_funnel complete event" do
      %{me_file: me_file, offer: offer, phase_1_id: phase_1_id, media_run: media_run} =
        setup_current_three_tap_offer!(
          maximum_banner_count: 3,
          banner_retry_buffer_hours: 10,
          frequency: 3
        )

      insert_banner_event!(offer, phase_1_id, created_at: hours_ago(1))
      insert_complete_event!(offer, phase_1_id)

      assert {:ok, %{finalized: 1}} = Offers.refresh_statuses_for_me_file(me_file.id)
      assert is_nil(Repo.get(Offer, offer.id))

      next =
        Repo.one(
          from o in Offer,
            where: o.me_file_id == ^me_file.id and o.media_run_id == ^media_run.id
        )

      assert next
      refute next.is_current
    end

    test "activates pending offers whose pending_until has elapsed" do
      %{me_file: me_file, offer: offer} =
        setup_pending_three_tap_offer!(pending_until: hours_ago(1))

      assert {:ok, %{activated: 1}} = Offers.refresh_statuses_for_me_file(me_file.id)
      assert Repo.get!(Offer, offer.id).is_current
    end

    test "does not activate pending offers still waiting on pending_until" do
      %{me_file: me_file, offer: offer} =
        setup_pending_three_tap_offer!(pending_until: hours_from_now(5))

      assert {:ok, %{activated: 0}} = Offers.refresh_statuses_for_me_file(me_file.id)
      refute Repo.get!(Offer, offer.id).is_current
    end
  end

  describe "list_current_three_tap_offers/1" do
    test "returns current 3-tap offers at UI phase 0" do
      %{me_file: me_file, offer: offer, phase_1_id: phase_1_id} =
        setup_current_three_tap_offer!(
          maximum_banner_count: 3,
          banner_retry_buffer_hours: 10
        )

      insert_banner_event!(offer, phase_1_id, created_at: hours_ago(11))

      assert [{listed, 0}] = Offers.list_current_three_tap_offers(me_file.id)
      assert listed.id == offer.id
    end

    test "omits parked offers" do
      %{me_file: me_file, offer: offer, phase_1_id: phase_1_id} =
        setup_current_three_tap_offer!(
          maximum_banner_count: 3,
          banner_retry_buffer_hours: 10
        )

      insert_banner_event!(offer, phase_1_id, created_at: hours_ago(1))
      assert {:ok, %{parked: 1}} = Offers.refresh_statuses_for_me_file(me_file.id)

      assert Offers.list_current_three_tap_offers(me_file.id) == []
    end
  end

  defp setup_current_three_tap_offer!(opts) do
    ctx = build_three_tap_context!(opts)

    offer =
      insert_offer!(ctx, %{
        is_current: true,
        pending_until: hours_ago(24)
      })

    Map.put(ctx, :offer, offer)
  end

  defp setup_pending_three_tap_offer!(opts) do
    pending_until = Keyword.fetch!(opts, :pending_until)
    ctx = build_three_tap_context!(Keyword.drop(opts, [:pending_until]))

    offer =
      insert_offer!(ctx, %{
        is_current: false,
        pending_until: pending_until
      })

    Map.put(ctx, :offer, offer)
  end

  defp build_three_tap_context!(opts) do
    max_banners = Keyword.get(opts, :maximum_banner_count, 3)
    retry_hours = Keyword.get(opts, :banner_retry_buffer_hours, 10)
    frequency = Keyword.get(opts, :frequency, 3)
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    me_file = Repo.insert!(%MeFile{})

    marketer =
      %Marketer{}
      |> Marketer.changeset(%{business_name: "Offers Refresh #{System.unique_integer()}"})
      |> Repo.insert!()

    ensure_three_tap_type_and_phase!(now)

    category =
      %AdCategory{}
      |> AdCategory.changeset(%{ad_category_name: "Cat #{System.unique_integer()}"})
      |> Repo.insert!()

    media_piece =
      %MediaPiece{}
      |> MediaPiece.changeset(%{
        title: "Banner Ad #{System.unique_integer()}",
        media_piece_type_id: 1,
        ad_category_id: category.id,
        marketer_id: marketer.id,
        active: true,
        banner_image: "banner.png",
        display_url: "example.com",
        jump_url: "https://example.com/jump"
      })
      |> Repo.insert!()

    sequence =
      %MediaSequence{}
      |> MediaSequence.changeset(%{
        title: "Seq #{System.unique_integer()}",
        marketer_id: marketer.id
      })
      |> Repo.insert!()

    media_run =
      %MediaRun{}
      |> MediaRun.changeset(%{
        marketer_id: marketer.id,
        media_piece_id: media_piece.id,
        media_sequence_id: sequence.id,
        frequency: frequency,
        frequency_buffer_hours: 24,
        maximum_banner_count: max_banners,
        banner_retry_buffer_hours: retry_hours,
        is_active: true,
        sequence_start_phase: 1,
        sequence_end_phase: 2
      })
      |> Repo.insert!()

    target =
      %Target{}
      |> Target.changeset(%{
        title: "Target #{System.unique_integer()}",
        marketer_id: marketer.id
      })
      |> Repo.insert!()

    target_band =
      %TargetBand{}
      |> TargetBand.changeset(%{target_id: target.id, is_bullseye: "1"})
      |> Repo.insert!()

    campaign =
      %Campaign{}
      |> Campaign.changeset(%{
        marketer_id: marketer.id,
        title: "Campaign #{System.unique_integer()}",
        target_id: target.id,
        media_sequence_id: sequence.id,
        start_date: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        is_payable: true,
        is_throttled: false,
        is_demo: false
      })
      |> Repo.insert!()

    phase_1 = Repo.get_by!(MediaPiecePhase, media_piece_type_id: 1, phase: 1)

    %{
      me_file: me_file,
      marketer: marketer,
      media_piece: media_piece,
      media_run: media_run,
      campaign: campaign,
      target_band: target_band,
      phase_1_id: phase_1.id
    }
  end

  defp insert_offer!(ctx, attrs) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    defaults = %{
      campaign_id: ctx.campaign.id,
      me_file_id: ctx.me_file.id,
      media_run_id: ctx.media_run.id,
      media_piece_id: ctx.media_piece.id,
      target_band_id: ctx.target_band.id,
      offer_amt: Decimal.new("0.21"),
      marketer_cost_amt: Decimal.new("0.30"),
      is_payable: true,
      is_throttled: false,
      is_demo: false,
      is_jobbed: false,
      matching_tags_snapshot: %{},
      ad_phase_count_to_complete: 2,
      pending_until: now,
      is_current: true
    }

    %Offer{}
    |> Offer.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  defp insert_banner_event!(offer, phase_1_id, opts) do
    created_at = Keyword.fetch!(opts, :created_at) |> NaiveDateTime.truncate(:second)

    %AdEvent{}
    |> AdEvent.changeset(%{
      offer_bid_amt: offer.offer_amt,
      is_throttled: offer.is_throttled,
      is_offer_complete: false,
      ip_address: "127.0.0.1",
      url: "https://example.com",
      offer_id: offer.id,
      me_file_id: offer.me_file_id,
      campaign_id: offer.campaign_id,
      media_run_id: offer.media_run_id,
      media_piece_id: offer.media_piece_id,
      media_piece_phase_id: phase_1_id,
      target_band_id: offer.target_band_id,
      is_payable: true,
      offer_marketer_cost_amt: offer.marketer_cost_amt,
      event_marketer_cost_amt: Decimal.new("0.06"),
      event_me_file_collect_amt: Decimal.new("0.05"),
      event_sponster_collect_amt: Decimal.new("0.01"),
      matching_tags_snapshot: %{}
    })
    |> Ecto.Changeset.put_change(:created_at, created_at)
    |> Ecto.Changeset.put_change(:updated_at, created_at)
    |> Repo.insert!()
  end

  defp insert_complete_event!(offer, phase_1_id) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    %AdEvent{}
    |> AdEvent.changeset(%{
      offer_bid_amt: offer.offer_amt,
      is_throttled: offer.is_throttled,
      is_offer_complete: true,
      completion_kind: "full_funnel",
      ip_address: "127.0.0.1",
      url: "https://example.com",
      offer_id: offer.id,
      me_file_id: offer.me_file_id,
      campaign_id: offer.campaign_id,
      media_run_id: offer.media_run_id,
      media_piece_id: offer.media_piece_id,
      media_piece_phase_id: phase_1_id,
      target_band_id: offer.target_band_id,
      is_payable: true,
      offer_marketer_cost_amt: offer.marketer_cost_amt,
      event_marketer_cost_amt: Decimal.new("0.24"),
      event_me_file_collect_amt: Decimal.new("0.16"),
      event_sponster_collect_amt: Decimal.new("0.08"),
      matching_tags_snapshot: %{}
    })
    |> Ecto.Changeset.put_change(:created_at, now)
    |> Ecto.Changeset.put_change(:updated_at, now)
    |> Repo.insert!()
  end

  defp ensure_three_tap_type_and_phase!(now) do
    unless Repo.get(MediaPieceType, 1) do
      Repo.insert!(%MediaPieceType{
        id: 1,
        name: "three_tap",
        desc: "3-tap",
        ad_phase_count_to_complete: 2,
        base_fee: Decimal.new("0.10"),
        markup_multiplier: Decimal.new("1.5"),
        created_at: now
      })
    end

    unless Repo.get_by(MediaPiecePhase, media_piece_type_id: 1, phase: 1) do
      Repo.insert!(%MediaPiecePhase{
        id: 1,
        media_piece_type_id: 1,
        phase: 1,
        name: "Banner",
        desc: "Banner",
        is_final_phase: false,
        pay_to_me_file_fixed: Decimal.new("0.05"),
        pay_to_sponster_fixed: Decimal.new("0.01"),
        created_at: now
      })
    end
  end

  defp hours_ago(hours) do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.add(-hours * 3600, :second)
    |> NaiveDateTime.truncate(:second)
  end

  defp hours_from_now(hours) do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.add(hours * 3600, :second)
    |> NaiveDateTime.truncate(:second)
  end
end
