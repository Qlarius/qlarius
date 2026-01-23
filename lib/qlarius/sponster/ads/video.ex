defmodule Qlarius.Sponster.Ads.Video do
  alias Qlarius.Repo
  alias Qlarius.Sponster.AdEvent
  alias Qlarius.Sponster.Ads.MediaPiecePhase
  alias Qlarius.Wallets
  alias Qlarius.Jobs.HandleOfferCompletionWorker

  def create_video_ad_event(offer, recipient \\ nil, split_amount \\ 0, ip \\ "0.0.0.0") do
    offer = Repo.preload(offer, media_run: [media_piece: :media_piece_type])
    media_run = offer.media_run
    media_piece_type = media_run.media_piece.media_piece_type

    # Get the phase for video ads (media_piece_type_id: 2, phase: 1)
    phase = Repo.get_by!(MediaPiecePhase, media_piece_type_id: 2, phase: 1)

    offer_amt = offer.offer_amt || Decimal.new("0.00")

    # Use database pricing values
    base_fee = media_piece_type.base_fee
    # Convert markup_multiplier (1.5) to sponster markup percent (0.5)
    # Formula: sponster_cut = base_fee + (offer_amt × (markup_multiplier - 1))
    markup_percent = Decimal.sub(media_piece_type.markup_multiplier, Decimal.new("1.0"))

    sponster_cut = Decimal.add(base_fee, Decimal.mult(offer_amt, markup_percent))
    marketer_cost = Decimal.add(offer_amt, sponster_cut)

    ad_event_attrs = %{
      offer_id: offer.id,
      me_file_id: offer.me_file_id,
      offer_bid_amt: offer.offer_amt,
      is_throttled: offer.is_throttled,
      is_demo: offer.is_demo,
      media_piece_id: media_run.media_piece_id,
      media_piece_phase_id: phase.id,
      media_run_id: media_run.id,
      campaign_id: offer.campaign_id,
      target_band_id: offer.target_band_id,
      is_payable: offer.is_payable,
      offer_marketer_cost_amt: marketer_cost,
      event_marketer_cost_amt: marketer_cost,
      event_me_file_collect_amt: offer_amt,
      event_sponster_collect_amt: sponster_cut,
      is_offer_complete: true,
      matching_tags_snapshot: offer.matching_tags_snapshot,
      ip_address: ip,
      url: "video://watched"
    }

    ad_event_attrs =
      if recipient && split_amount > 0 do
        split_percentage = Decimal.div(Decimal.new(split_amount), Decimal.new(100))

        split_amount_to_recipient =
          ad_event_attrs.event_me_file_collect_amt
          |> Decimal.mult(split_percentage)
          |> Decimal.round(2, :half_up)

        adjusted_me_file_collect_amt =
          Decimal.sub(ad_event_attrs.event_me_file_collect_amt, split_amount_to_recipient)

        Map.merge(ad_event_attrs, %{
          recipient_id: recipient.id,
          event_split_code: recipient.split_code,
          event_recipient_split_pct: split_amount,
          event_recipient_collect_amt: split_amount_to_recipient,
          event_me_file_collect_amt: adjusted_me_file_collect_amt,
          event_sponster_collect_amt:
            Decimal.sub(ad_event_attrs.event_sponster_collect_amt, Decimal.new("0.01")),
          event_sponster_to_recipient_amt: Decimal.new("0.01")
        })
      else
        ad_event_attrs
      end

    ad_event_changeset = AdEvent.changeset(%AdEvent{}, ad_event_attrs)

    case Repo.insert(ad_event_changeset) do
      {:ok, ad_event} ->
        case Wallets.update_ledgers_from_ad_event(ad_event) do
          {:ok, _} ->
            require Logger
            Logger.info("📹 Video ad_event created, enqueueing HandleOfferCompletionWorker for offer #{ad_event.offer_id}")

            case HandleOfferCompletionWorker.new(%{
              offer_id: ad_event.offer_id,
              completed_at: NaiveDateTime.to_iso8601(ad_event.created_at)
            })
            |> Oban.insert() do
              {:ok, job} ->
                Logger.info("✅ HandleOfferCompletionWorker job enqueued successfully: #{job.id}")
                {:ok, ad_event}

              {:error, changeset} ->
                Logger.error("❌ Failed to enqueue HandleOfferCompletionWorker: #{inspect(changeset)}")
                {:ok, ad_event}  # Still return success for the ad_event itself
            end

          {:error, error} ->
            {:error, error}
        end

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Calculate the total collected and given amounts for a video offer.
  Queries all ad_events for this offer_id and me_file_id (though typically only one).
  Returns {me_file_collect_total, recipient_collect_total}.
  """
  def calculate_offer_totals(offer_id, me_file_id, recipient \\ nil) do
    import Ecto.Query

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
