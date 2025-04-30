defmodule Qlarius.Ads.ThreeTap do

  alias Qlarius.LegacyRepo
  alias Qlarius.Legacy.{AdEvent, Offer, MediaPiecePhase, MediaPieceType, MeFile, Campaign, MediaRun, TargetBand}
  alias Qlarius.Wallets

  def create_banner_ad_event(offer_id, ip \\ "0.0.0.0", url \\ "https://here.com") do

    offer = LegacyRepo.get!(Offer, offer_id)
    type = LegacyRepo.get!(MediaPieceType, 1)
    phase = LegacyRepo.get_by!(MediaPiecePhase, media_piece_type_id: type.id, phase: 1)

    #if recipient_split_code is provided, get the recipient and calculate the revshare to the recipient

    ad_event_attrs = %{
      offer_id: offer.id,
      me_file_id: offer.me_file_id,
      offer_bid_amt: offer.offer_amt,
      is_throttled: offer.is_throttled,
      is_demo: offer.is_demo,
      media_piece_id: offer.media_piece_id,
      media_piece_phase_id: 1,
      media_run_id: offer.media_run_id,
      campaign_id: offer.campaign_id,
      target_band_id: offer.target_band_id,
      is_payable: offer.is_payable,
      offer_marketer_cost_amt: offer.marketer_cost_amt,
      event_marketer_cost_amt: Decimal.add(phase.pay_to_me_file_fixed, phase.pay_to_sponster_fixed),
      event_me_file_collect_amt: phase.pay_to_me_file_fixed,
      event_sponster_collect_amt: phase.pay_to_sponster_fixed,
      is_offer_complete: phase.is_final_phase,
      matching_tags_snapshot: offer.matching_tags_snapshot,
      ip_address: ip,
      url: url
    }

    IO.inspect(ad_event_attrs, label: "Ad Event Attributes")

    ad_event_changeset = AdEvent.changeset(%AdEvent{}, ad_event_attrs)

    # TODO: determine if offer is complete
    # TODO: determine if recipient is provided
    # TODO: calculate splits when recipient is provided

    case LegacyRepo.insert(ad_event_changeset) do
      {:ok, ad_event} ->
        IO.inspect(ad_event, label: "Created Ad Event")
        case Wallets.update_ledgers_from_ad_event(ad_event) do
          {:ok, _} -> {:ok, ad_event}
          {:error, error} -> {:error, error}
        end
      {:error, changeset} ->
        IO.inspect(changeset, label: "Ad Event Creation Error")
        {:error, changeset}
    end

  end

  def create_jump_ad_event(offer_id, ip \\ "0.0.0.0", url \\ "https://here.com") do

    offer = LegacyRepo.get!(Offer, offer_id)
    type = LegacyRepo.get!(MediaPieceType, 1)
    phase = LegacyRepo.get_by!(MediaPiecePhase, media_piece_type_id: type.id, phase: 2)
    previous_phase = LegacyRepo.get_by!(MediaPiecePhase, media_piece_type_id: type.id, phase: 1)

    #if recipient_split_code is provided, get the recipient and calculate the revshare to the recipient

    event_marketer_cost_amt = Decimal.sub(offer.marketer_cost_amt, Decimal.add(previous_phase.pay_to_me_file_fixed, previous_phase.pay_to_sponster_fixed))
    event_me_file_collect_amt = Decimal.sub(offer.offer_amt, previous_phase.pay_to_me_file_fixed)
    event_sponster_collect_amt = Decimal.sub(event_marketer_cost_amt, event_me_file_collect_amt)


    ad_event_attrs = %{
      offer_id: offer.id,
      me_file_id: offer.me_file_id,
      offer_bid_amt: offer.offer_amt,
      is_throttled: offer.is_throttled,
      is_demo: offer.is_demo,
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
      matching_tags_snapshot: offer.matching_tags_snapshot,
      ip_address: ip,
      url: url
    }

    IO.inspect(ad_event_attrs, label: "Ad Event Attributes")

    ad_event_changeset = AdEvent.changeset(%AdEvent{}, ad_event_attrs)

    # TODO: determine if offer is complete
    # TODO: determine if recipient is provided
    # TODO: calculate splits when recipient is provided

    case LegacyRepo.insert(ad_event_changeset) do
      {:ok, ad_event} ->
        IO.inspect(ad_event, label: "Created Ad Event")
        case Wallets.update_ledgers_from_ad_event(ad_event) do
          {:ok, _} -> {:ok, ad_event}
          {:error, error} -> {:error, error}
        end
      {:error, changeset} ->
        IO.inspect(changeset, label: "Ad Event Creation Error")
        {:error, changeset}
    end

  end

end
