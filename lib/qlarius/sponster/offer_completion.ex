defmodule Qlarius.Sponster.OfferCompletion do
  @moduledoc """
  Finalizes an offer after an attempt completes (full funnel or banner-max).

  Deletes the current offer and, when media_run `frequency` still has room,
  creates the next pending offer with `pending_until = completed_at +
  frequency_buffer_hours`.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias Qlarius.Repo
  alias Qlarius.Sponster.{AdEvent, Offer}
  alias Qlarius.Sponster.Campaigns.{CampaignPubSub, TargetPopulation}
  alias Qlarius.Wallets.MeFileStatsBroadcaster

  @doc """
  Finalize a completed offer by id. Idempotent if the offer was already deleted.
  """
  def finalize(offer_id, completed_at) when is_integer(offer_id) do
    completed_at = truncate_time(completed_at)

    case Repo.get(Offer, offer_id) do
      nil ->
        {:ok, :already_finalized}

      offer ->
        offer = Repo.preload(offer, [:campaign, media_run: [media_piece: :media_piece_type]])
        do_finalize(offer, completed_at)
    end
  end

  defp do_finalize(offer, completed_at) do
    if should_create_next_offer?(offer) do
      create_next_offer_and_delete_original(offer, completed_at)
    else
      Repo.delete(offer)
      MeFileStatsBroadcaster.broadcast_offers_updated(offer.me_file_id)
      {:ok, :run_complete}
    end
  end

  defp should_create_next_offer?(offer) do
    if is_nil(offer.media_run) do
      false
    else
      completed_count = count_completed_offers(offer.me_file_id, offer.media_run_id)
      frequency = offer.media_run.frequency || 1
      completed_count < frequency
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

  defp create_next_offer_and_delete_original(original_offer, completed_at) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    buffer_hours = original_offer.media_run.frequency_buffer_hours || 24
    pending_until = NaiveDateTime.add(completed_at, buffer_hours * 3600, :second)

    current_tags_snapshot =
      get_snapshot_from_target_population(
        original_offer.me_file_id,
        original_offer.target_band_id
      ) ||
        original_offer.matching_tags_snapshot ||
        %{}

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

    Multi.new()
    |> Multi.delete(:delete_original, original_offer)
    |> Multi.insert(:create_next, Offer.changeset(%Offer{}, new_offer_attrs))
    |> Multi.run(:broadcast, fn _repo, %{create_next: new_offer} ->
      CampaignPubSub.broadcast_offers_created(original_offer.campaign_id, 1)

      CampaignPubSub.broadcast_marketer_campaign_updated(
        original_offer.campaign.marketer_id,
        original_offer.campaign_id
      )

      MeFileStatsBroadcaster.broadcast_offers_updated(original_offer.me_file_id)

      {:ok, new_offer}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{create_next: new_offer}} ->
        {:ok, {:next_offer, new_offer}}

      {:error, _failed_operation, reason, _changes} ->
        {:error, reason}
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
          "OfferCompletion: No target_population for me_file #{me_file_id}, band #{target_band_id}"
        )

        nil

      snapshot ->
        snapshot
    end
  end

  defp truncate_time(%NaiveDateTime{} = dt), do: NaiveDateTime.truncate(dt, :second)

  defp truncate_time(%DateTime{} = dt) do
    dt
    |> DateTime.to_naive()
    |> NaiveDateTime.truncate(:second)
  end
end
