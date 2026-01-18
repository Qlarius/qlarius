defmodule Qlarius.Jobs.HandleOfferCompletionWorker do
  use Oban.Worker, queue: :offers, max_attempts: 3

  import Ecto.Query
  alias Qlarius.Repo
  alias Qlarius.Sponster.{Offer, AdEvent}
  alias Qlarius.Sponster.Campaigns.{CampaignPubSub, TargetPopulation}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"offer_id" => offer_id, "completed_at" => completed_at_string}}) do
    require Logger
    Logger.info("HandleOfferCompletionWorker: Processing offer #{offer_id}")

    completed_at = NaiveDateTime.from_iso8601!(completed_at_string)

    case Repo.get(Offer, offer_id) do
      nil ->
        Logger.info(
          "HandleOfferCompletionWorker: Offer #{offer_id} no longer exists (already deleted), skipping"
        )

        :ok

      offer ->
        offer = Repo.preload(offer, [:campaign, media_run: [media_piece: :media_piece_type]])

        if should_create_next_offer?(offer) do
          create_next_offer(offer, completed_at)

          Logger.info(
            "HandleOfferCompletionWorker: Created next offer for me_file #{offer.me_file_id}"
          )
        else
          Logger.info(
            "HandleOfferCompletionWorker: Media run complete for me_file #{offer.me_file_id}, no next offer created"
          )
        end

        :ok
    end
  end

  defp should_create_next_offer?(offer) do
    if is_nil(offer.media_run) do
      false
    else
      completed_count = count_completed_offers(offer.me_file_id, offer.media_run_id)
      frequency = offer.media_run.frequency || 1

      if completed_count >= frequency do
        false
      else
        not maximum_banner_count_exceeded?(offer)
      end
    end
  end

  defp count_completed_offers(me_file_id, media_run_id) do
    from(ae in AdEvent,
      where: ae.me_file_id == ^me_file_id,
      where: ae.media_run_id == ^media_run_id,
      where: ae.is_offer_complete == true,
      select: count(ae.id)
    )
    |> Repo.one()
  end

  defp maximum_banner_count_exceeded?(offer) do
    media_piece_type =
      get_in(offer, [
        Access.key(:media_run),
        Access.key(:media_piece),
        Access.key(:media_piece_type)
      ])

    max_banner_count = offer.media_run.maximum_banner_count

    if is_nil(media_piece_type) or is_nil(max_banner_count) do
      false
    else
      phase_1_ad_events_count = count_phase_1_events_for_offer(offer.id, media_piece_type.id)
      phase_1_ad_events_count >= max_banner_count
    end
  end

  defp count_phase_1_events_for_offer(offer_id, media_piece_type_id) do
    phase_1_id =
      from(mpp in Qlarius.Sponster.Ads.MediaPiecePhase,
        where: mpp.media_piece_type_id == ^media_piece_type_id,
        where: mpp.phase == 1,
        select: mpp.id,
        limit: 1
      )
      |> Repo.one()

    if phase_1_id do
      from(ae in AdEvent,
        where: ae.offer_id == ^offer_id,
        where: ae.media_piece_phase_id == ^phase_1_id,
        select: count(ae.id)
      )
      |> Repo.one()
    else
      0
    end
  end

  defp create_next_offer(original_offer, completed_at) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    buffer_hours = original_offer.media_run.frequency_buffer_hours || 24
    pending_until = NaiveDateTime.add(completed_at, buffer_hours * 3600, :second)

    current_tags_snapshot =
      get_snapshot_from_target_population(
        original_offer.me_file_id,
        original_offer.target_band_id
      )

    new_offer_attrs = %{
      campaign_id: original_offer.campaign_id,
      me_file_id: original_offer.me_file_id,
      media_run_id: original_offer.media_run_id,
      media_piece_id: original_offer.media_piece_id,
      target_band_id: original_offer.target_band_id,
      offer_amt: original_offer.offer_amt,
      marketer_cost_amt: original_offer.marketer_cost_amt,
      pending_until: pending_until,
      is_payable: original_offer.is_payable,
      is_throttled: original_offer.is_throttled,
      is_demo: original_offer.is_demo,
      is_current: false,
      is_jobbed: false,
      matching_tags_snapshot: current_tags_snapshot,
      ad_phase_count_to_complete: original_offer.ad_phase_count_to_complete,
      created_at: now,
      updated_at: now
    }

    case Repo.insert_all(Offer, [new_offer_attrs],
           on_conflict: :nothing,
           conflict_target: [:campaign_id, :me_file_id, :media_run_id],
           returning: true
         ) do
      {1, [inserted_offer]} ->
        CampaignPubSub.broadcast_offers_created(original_offer.campaign_id, 1)

        CampaignPubSub.broadcast_marketer_campaign_updated(
          original_offer.campaign.marketer_id,
          original_offer.campaign_id
        )

        {:ok, inserted_offer}

      {0, _} ->
        require Logger

        Logger.warning(
          "HandleOfferCompletionWorker: Offer already exists for campaign #{original_offer.campaign_id}, me_file #{original_offer.me_file_id}, media_run #{original_offer.media_run_id}"
        )

        {:ok, :already_exists}
    end
  end

  defp get_snapshot_from_target_population(me_file_id, target_band_id) do
    case Repo.one(
           from(tp in TargetPopulation,
             where: tp.me_file_id == ^me_file_id and tp.target_band_id == ^target_band_id,
             select: tp.matching_tags_snapshot
           )
         ) do
      nil ->
        require Logger

        Logger.warning(
          "HandleOfferCompletionWorker: No target_population found for me_file #{me_file_id}, band #{target_band_id}"
        )

        nil

      snapshot ->
        snapshot
    end
  end
end
