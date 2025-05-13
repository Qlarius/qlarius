defmodule Qlarius.Ads.ThreeTap do
  alias Qlarius.LegacyRepo
  import Ecto.Query, except: [update: 2, update: 3]

  alias Qlarius.Legacy.{
    AdEvent,
    Offer,
    MediaPiecePhase,
    MediaPieceType,
    MeFile,
    Campaign,
    MediaRun,
    TargetBand,
    Recipient
  }

  alias Qlarius.Wallets

  def create_banner_ad_event(offer, recipient, split_amount, ip \\ "0.0.0.0", url \\ "https://here.com") do
    # type = LegacyRepo.get!(MediaPieceType, 1)
    phase = LegacyRepo.get_by!(MediaPiecePhase, media_piece_type_id: 1, phase: 1)

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
      event_marketer_cost_amt:
        Decimal.add(phase.pay_to_me_file_fixed, phase.pay_to_sponster_fixed),
      event_me_file_collect_amt: phase.pay_to_me_file_fixed,
      event_sponster_collect_amt: phase.pay_to_sponster_fixed,
      is_offer_complete: phase.is_final_phase,
      matching_tags_snapshot: offer.matching_tags_snapshot,
      ip_address: ip,
      url: url
    }

    # if recipient is provided, calculate the revshare to the recipient
    ad_event_attrs = if recipient do
      split_percentage = Decimal.div(Decimal.new(split_amount), Decimal.new(100))
      IO.inspect(split_percentage, label: "Split percentage")

      split_amount_to_recipient =
        ad_event_attrs.event_me_file_collect_amt
        |> Decimal.mult(split_percentage)
        |> Decimal.round(2, :down)
      IO.inspect(split_amount_to_recipient, label: "Split amount to recipient")

      adjusted_me_file_collect_amt = Decimal.sub(ad_event_attrs.event_me_file_collect_amt, split_amount_to_recipient)
      IO.inspect(adjusted_me_file_collect_amt, label: "Adjusted me file collect amount")

      updated_attrs = Map.merge(ad_event_attrs, %{
        recipient_id: recipient.id,
        event_split_code: recipient.split_code,
        event_recipient_split_pct: split_amount,
        #update the recipient collect amt to be the event_me_file_collect_amt - minus the split_pct amount
        event_recipient_collect_amt: split_amount_to_recipient,
        event_me_file_collect_amt: adjusted_me_file_collect_amt,
        #update the sponster keep to give  $0.01 to recipient
        event_sponster_collect_amt: Decimal.sub(ad_event_attrs.event_sponster_collect_amt, Decimal.new("0.01")),
        event_sponster_to_recipient_amt: Decimal.new("0.01")
      })
      IO.inspect(updated_attrs, label: "Updated ad event attrs with recipient")
      updated_attrs
    else
      ad_event_attrs
    end

    IO.inspect(ad_event_attrs, label: "Final Ad Event Attributes")

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

  def create_jump_ad_event(offer, recipient, split_amount, ip \\ "0.0.0.0", url \\ "https://here.com") do
    type = LegacyRepo.get!(MediaPieceType, 1)
    phase = LegacyRepo.get_by!(MediaPiecePhase, media_piece_type_id: type.id, phase: 2)
    previous_phase = LegacyRepo.get_by!(MediaPiecePhase, media_piece_type_id: type.id, phase: 1)

    event_marketer_cost_amt =
      Decimal.sub(
        offer.marketer_cost_amt,
        Decimal.add(previous_phase.pay_to_me_file_fixed, previous_phase.pay_to_sponster_fixed)
      )

    event_me_file_collect_amt = Decimal.sub(offer.offer_amt, previous_phase.pay_to_me_file_fixed)
    IO.inspect(event_me_file_collect_amt, label: "Event Me File Collect Amount")

    event_sponster_collect_amt = Decimal.sub(event_marketer_cost_amt, event_me_file_collect_amt)
    IO.inspect(event_sponster_collect_amt, label: "Event Sponster Collect Amount")

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
    IO.inspect(ad_event_attrs, label: "Initial Ad Event Attributes")

    # if recipient is provided, calculate the revshare to the recipient
    ad_event_attrs = if recipient do

      split_percentage = Decimal.div(Decimal.new(split_amount), Decimal.new(100))
      IO.inspect(split_percentage, label: "Split percentage")

      split_amount_to_recipient =
        ad_event_attrs.event_me_file_collect_amt
        |> Decimal.mult(split_percentage)
        |> Decimal.round(2, :down)
      IO.inspect(split_amount_to_recipient, label: "Split amount to recipient")

      adjusted_me_file_collect_amt = Decimal.sub(ad_event_attrs.event_me_file_collect_amt, split_amount_to_recipient)
      IO.inspect(adjusted_me_file_collect_amt, label: "Adjusted me file collect amount")

      updated_attrs = Map.merge(ad_event_attrs, %{
        recipient_id: recipient.id,
        event_split_code: recipient.split_code,
        event_recipient_split_pct: split_amount,
        #update the recipient collect amt to be the event_me_file_collect_amt - minus the split_pct amount
        event_recipient_collect_amt: split_amount_to_recipient,
        event_me_file_collect_amt: adjusted_me_file_collect_amt,
        #update the sponster keep to give  $0.01 to recipient
        event_sponster_collect_amt: Decimal.sub(ad_event_attrs.event_sponster_collect_amt, Decimal.new("0.01")),
        event_sponster_to_recipient_amt: Decimal.new("0.01")
      })
      updated_attrs
    else
      ad_event_attrs
    end

    IO.inspect(ad_event_attrs, label: "Final Ad Event Attributes")

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

  @doc """
  Calculate the total amounts collected by user and given to recipient for an offer.

  Returns a tuple of {me_file_collect_total, recipient_collect_total} where
  recipient_collect_total is nil if no recipient is provided.
  """
  def calculate_offer_totals(offer_id, recipient \\ nil) do
    # Use a more explicit query format
    query = from(ad_event in AdEvent,
                where: ad_event.offer_id == ^offer_id)
    ad_events = LegacyRepo.all(query)

    # Calculate total collected by the user
    me_file_collect_total = Enum.reduce(ad_events, Decimal.new("0.00"), fn event, acc ->
      Decimal.add(acc, event.event_me_file_collect_amt || Decimal.new("0.00"))
    end)

    # Calculate total given to recipient (if any)
    recipient_collect_total = if recipient do
      Enum.reduce(ad_events, Decimal.new("0.00"), fn event, acc ->
        Decimal.add(acc, event.event_recipient_collect_amt || Decimal.new("0.00"))
      end)
    else
      nil
    end

    {me_file_collect_total, recipient_collect_total}
  end
end
