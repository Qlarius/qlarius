defmodule Qlarius.Sponster.Ads.ThreeTap do
  alias Qlarius.Repo
  import Ecto.Query, except: [update: 2, update: 3]

  alias Qlarius.Sponster.AdEvent
  alias Qlarius.Sponster.Ads.{MediaPiecePhase, MediaPieceType, PublisherCredit, Rates}
  alias Qlarius.Sponster.Campaigns.CampaignPubSub
  alias Qlarius.Wallets
  alias Qlarius.Jobs.HandleOfferCompletionWorker

  def create_banner_ad_event(
        offer,
        recipient \\ nil,
        split_amount \\ 0,
        ip \\ "0.0.0.0",
        url \\ "https://here.com"
      ) do
    offer = Repo.preload(offer, campaign: [])
    phase = Repo.get_by!(MediaPiecePhase, media_piece_type_id: 1, phase: 1)

    ad_event_attrs = %{
      offer_id: offer.id,
      me_file_id: offer.me_file_id,
      offer_bid_amt: offer.offer_amt,
      is_throttled: offer.is_throttled,
      media_piece_id: offer.media_piece_id,
      media_piece_phase_id: 1,
      media_run_id: offer.media_run_id,
      campaign_id: offer.campaign_id,
      target_band_id: offer.target_band_id,
      is_payable: offer.is_payable,
      offer_marketer_cost_amt: offer.marketer_cost_amt,
      event_marketer_cost_amt:
        Decimal.add(phase.pay_to_me_file_fixed, phase.pay_to_sponster_fixed),
      event_me_file_collect_amt: phase.pay_to_me_file_fixed,
      event_sponster_collect_amt: phase.pay_to_sponster_fixed,
      is_offer_complete: phase.is_final_phase,
      matching_tags_snapshot: offer.matching_tags_snapshot,
      ip_address: ip,
      url: url
    }

    ad_event_attrs =
      PublisherCredit.apply(
        ad_event_attrs,
        recipient,
        split_amount,
        Rates.three_tap_publisher_credit_amt(),
        PublisherCredit.share_of(ad_event_attrs.event_me_file_collect_amt, split_amount)
      )

    ad_event_changeset = AdEvent.changeset(%AdEvent{}, ad_event_attrs)

    case Repo.insert(ad_event_changeset) do
      {:ok, ad_event} ->
        case Wallets.update_ledgers_from_ad_event(ad_event) do
          {:ok, _} ->
            CampaignPubSub.broadcast_campaign_updated(offer.campaign_id)

            CampaignPubSub.broadcast_marketer_campaign_updated(
              offer.campaign.marketer_id,
              offer.campaign_id
            )

            enqueue_completion_worker_if_needed(ad_event)

            {:ok, ad_event}

          {:error, error} ->
            {:error, error}
        end

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def create_jump_ad_event(
        offer,
        recipient \\ nil,
        split_amount \\ 0,
        ip \\ "0.0.0.0",
        url \\ "https://here.com"
      ) do
    offer = Repo.preload(offer, campaign: [])
    type = Repo.get!(MediaPieceType, 1)
    phase = Repo.get_by!(MediaPiecePhase, media_piece_type_id: type.id, phase: 2)
    previous_phase = Repo.get_by!(MediaPiecePhase, media_piece_type_id: type.id, phase: 1)

    event_marketer_cost_amt =
      Decimal.sub(
        offer.marketer_cost_amt,
        Decimal.add(previous_phase.pay_to_me_file_fixed, previous_phase.pay_to_sponster_fixed)
      )

    event_me_file_collect_amt = Decimal.sub(offer.offer_amt, previous_phase.pay_to_me_file_fixed)

    event_sponster_collect_amt = Decimal.sub(event_marketer_cost_amt, event_me_file_collect_amt)

    ad_event_attrs = %{
      offer_id: offer.id,
      me_file_id: offer.me_file_id,
      offer_bid_amt: offer.offer_amt,
      is_throttled: offer.is_throttled,
      media_piece_id: offer.media_piece_id,
      media_piece_phase_id: 2,
      media_run_id: offer.media_run_id,
      campaign_id: offer.campaign_id,
      target_band_id: offer.target_band_id,
      is_payable: offer.is_payable,
      offer_marketer_cost_amt: offer.marketer_cost_amt,
      event_marketer_cost_amt: event_marketer_cost_amt,
      event_me_file_collect_amt: event_me_file_collect_amt,
      event_sponster_collect_amt: event_sponster_collect_amt,
      is_offer_complete: phase.is_final_phase,
      completion_kind: if(phase.is_final_phase, do: "full_funnel", else: nil),
      matching_tags_snapshot: offer.matching_tags_snapshot,
      ip_address: ip,
      url: url
    }

    # Phase 2 finishes the reader's split: the recipient's share of the whole
    # offer, minus whatever the banner events already paid. A 0% or missing
    # split pays none of the reader's collect and still credits the publisher
    # from Sponster's keep.
    reader_share =
      if PublisherCredit.split_pct(split_amount) > 0 do
        total_recipient_amount =
          offer.offer_amt
          |> Decimal.mult(Decimal.div(Decimal.new(split_amount), Decimal.new(100)))
          |> Decimal.round(2, :half_up)

        phase1_recipient_amount =
          from(a in AdEvent,
            where: a.offer_id == ^offer.id,
            where: a.me_file_id == ^offer.me_file_id,
            where: a.media_piece_phase_id == ^previous_phase.id,
            select: sum(a.event_recipient_collect_amt)
          )
          |> Repo.one()
          |> case do
            nil -> Decimal.new("0.00")
            %Decimal{} = d -> d
          end

        Decimal.sub(total_recipient_amount, phase1_recipient_amount)
      else
        nil
      end

    ad_event_attrs =
      PublisherCredit.apply(
        ad_event_attrs,
        recipient,
        split_amount,
        Rates.three_tap_publisher_credit_amt(),
        reader_share
      )

    ad_event_changeset = AdEvent.changeset(%AdEvent{}, ad_event_attrs)

    case Repo.insert(ad_event_changeset) do
      {:ok, ad_event} ->
        case Wallets.update_ledgers_from_ad_event(ad_event) do
          {:ok, _} ->
            CampaignPubSub.broadcast_campaign_updated(offer.campaign_id)

            CampaignPubSub.broadcast_marketer_campaign_updated(
              offer.campaign.marketer_id,
              offer.campaign_id
            )

            enqueue_completion_worker_if_needed(ad_event)

            {:ok, ad_event}

          {:error, error} ->
            {:error, error}
        end

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp enqueue_completion_worker_if_needed(ad_event) do
    if ad_event.is_offer_complete do
      create_referral_click_if_applicable(ad_event)

      HandleOfferCompletionWorker.new(%{
        offer_id: ad_event.offer_id,
        completed_at: NaiveDateTime.to_iso8601(ad_event.created_at)
      })
      |> Oban.insert()
    end

    :ok
  end

  defp create_referral_click_if_applicable(ad_event) do
    case Qlarius.Referrals.get_referral_by_me_file(ad_event.me_file_id) do
      nil ->
        :no_referral

      referral ->
        if DateTime.compare(referral.expires_at, DateTime.utc_now()) == :gt &&
             referral.status == "active" do
          Qlarius.Referrals.create_referral_click(referral.id, ad_event.id)
        else
          :expired_or_inactive
        end
    end
  end

  @doc """
  Calculate the total amounts collected by user and given to recipient for an offer.

  Returns a tuple of {me_file_collect_total, recipient_collect_total} where
  recipient_collect_total is nil if no recipient is provided.
  """
  def calculate_offer_totals(offer_id, me_file_id, recipient \\ nil) do
    query =
      from(ad_event in AdEvent,
        where: ad_event.offer_id == ^offer_id and ad_event.me_file_id == ^me_file_id
      )

    ad_events = Repo.all(query)

    me_file_collect_total =
      Enum.reduce(ad_events, Decimal.new("0.00"), fn event, acc ->
        Decimal.add(acc, event.event_me_file_collect_amt || Decimal.new("0.00"))
      end)

    recipient_collect_total =
      if recipient do
        Enum.reduce(ad_events, Decimal.new("0.00"), fn event, acc ->
          Decimal.add(acc, event.event_recipient_collect_amt || Decimal.new("0.00"))
        end)
      else
        nil
      end

    {me_file_collect_total, recipient_collect_total}
  end
end
