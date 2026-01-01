defmodule Qlarius.Jobs.ReconcileOffersForMeFileWorker do
  use Oban.Worker,
    queue: :offers,
    max_attempts: 3,
    unique: [
      period: 60,
      keys: [:me_file_id],
      states: [:available, :scheduled]
    ]

  import Ecto.Query
  alias Qlarius.Repo
  alias Qlarius.Sponster.{Offer, AdEvent}
  alias Qlarius.Sponster.Campaigns.{Campaign, Bid, TargetPopulation}
  alias Qlarius.Sponster.Campaigns.CampaignPubSub
  alias Qlarius.YouData.MeFiles.MeFileTag
  alias Qlarius.Wallets.MeFileStatsBroadcaster

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"me_file_id" => me_file_id}}) do
    require Logger
    Logger.info("ReconcileOffersForMeFileWorker: Processing me_file #{me_file_id}")

    current_populations = get_target_bands_for_me_file(me_file_id)

    Logger.info(
      "ReconcileOffersForMeFileWorker: MeFile #{me_file_id} is in #{length(current_populations)} target bands"
    )

    eligible_bids = get_eligible_bids(current_populations, me_file_id)

    Logger.info(
      "ReconcileOffersForMeFileWorker: Found #{length(eligible_bids)} eligible bids for me_file #{me_file_id}"
    )

    {created_count, deleted_count} = reconcile_offers(me_file_id, eligible_bids)

    Logger.info(
      "ReconcileOffersForMeFileWorker: Created #{created_count}, deleted #{deleted_count} offers for me_file #{me_file_id}"
    )

    if created_count > 0 or deleted_count > 0 do
      MeFileStatsBroadcaster.broadcast_offers_updated(me_file_id)
    end

    :ok
  end

  defp get_target_bands_for_me_file(me_file_id) do
    from(tp in TargetPopulation,
      where: tp.me_file_id == ^me_file_id,
      select: tp.target_band_id
    )
    |> Repo.all()
  end

  defp get_eligible_bids(target_band_ids, me_file_id) do
    if target_band_ids == [] do
      []
    else
      from(b in Bid,
        where: b.target_band_id in ^target_band_ids,
        join: c in Campaign,
        on: c.id == b.campaign_id,
        where: is_nil(c.deactivated_at),
        preload: [campaign: [], media_run: [media_piece: :media_piece_type]],
        select: b
      )
      |> Repo.all()
      |> Enum.filter(fn bid ->
        not media_run_complete_for_me_file?(me_file_id, bid.media_run_id, bid.media_run)
      end)
    end
  end

  defp media_run_complete_for_me_file?(me_file_id, media_run_id, media_run) do
    completed_count =
      from(ae in AdEvent,
        where: ae.me_file_id == ^me_file_id,
        where: ae.media_run_id == ^media_run_id,
        where: ae.is_offer_complete == true,
        select: count(ae.id)
      )
      |> Repo.one()

    frequency = media_run.frequency || 1
    completed_count >= frequency
  end

  defp reconcile_offers(me_file_id, eligible_bids) do
    existing_offers =
      from(o in Offer,
        where: o.me_file_id == ^me_file_id,
        select: %{
          id: o.id,
          campaign_id: o.campaign_id,
          media_run_id: o.media_run_id,
          target_band_id: o.target_band_id
        }
      )
      |> Repo.all()

    is_new_user = Enum.empty?(existing_offers)

    existing_keys =
      Enum.map(existing_offers, fn o ->
        {o.campaign_id, o.media_run_id, o.target_band_id}
      end)
      |> MapSet.new()

    eligible_keys =
      Enum.map(eligible_bids, fn b ->
        {b.campaign_id, b.media_run_id, b.target_band_id}
      end)
      |> MapSet.new()

    keys_to_add = MapSet.difference(eligible_keys, existing_keys) |> MapSet.to_list()
    keys_to_remove = MapSet.difference(existing_keys, eligible_keys) |> MapSet.to_list()

    created_count = create_missing_offers(me_file_id, eligible_bids, keys_to_add, is_new_user)
    deleted_count = delete_invalid_offers(me_file_id, existing_offers, keys_to_remove)

    {created_count, deleted_count}
  end

  defp create_missing_offers(me_file_id, eligible_bids, keys_to_add, is_new_user) do
    if keys_to_add == [] do
      0
    else
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      current_tags = get_current_me_file_tags(me_file_id)

      offers_to_create =
        Enum.filter(eligible_bids, fn bid ->
          key = {bid.campaign_id, bid.media_run_id, bid.target_band_id}
          key in keys_to_add
        end)
        |> Enum.map(fn bid ->
          media_piece_type =
            get_in(bid, [
              Access.key(:media_run),
              Access.key(:media_piece),
              Access.key(:media_piece_type)
            ])

          ad_phase_count =
            if media_piece_type, do: media_piece_type.ad_phase_count_to_complete, else: 1

          %{
            campaign_id: bid.campaign_id,
            me_file_id: me_file_id,
            media_run_id: bid.media_run_id,
            media_piece_id: bid.media_run.media_piece_id,
            target_band_id: bid.target_band_id,
            offer_amt: bid.offer_amt,
            marketer_cost_amt: bid.marketer_cost_amt,
            pending_until: now,
            is_payable: bid.campaign.is_payable,
            is_throttled: bid.campaign.is_throttled,
            is_demo: bid.campaign.is_demo,
            is_current: false,
            is_jobbed: false,
            matching_tags_snapshot: current_tags,
            ad_phase_count_to_complete: ad_phase_count,
            created_at: now,
            updated_at: now
          }
        end)

      offers_to_create = apply_new_user_activation(offers_to_create, is_new_user)

      {count, _} =
        Repo.insert_all(Offer, offers_to_create,
          on_conflict: :nothing,
          conflict_target: [:campaign_id, :me_file_id, :media_run_id]
        )

      if count > 0 do
        Enum.each(offers_to_create, fn offer_data ->
          CampaignPubSub.broadcast_offers_created(offer_data.campaign_id, 1)
        end)
      end

      count
    end
  end

  defp apply_new_user_activation(offers, false), do: offers

  defp apply_new_user_activation(offers, true) do
    throttle_limit = get_throttle_ad_count()

    {unthrottled, throttled} = Enum.split_with(offers, fn offer -> !offer.is_throttled end)

    activated_unthrottled = Enum.map(unthrottled, &Map.put(&1, :is_current, true))

    {activated_throttled, pending_throttled} = Enum.split(throttled, throttle_limit)

    activated_throttled = Enum.map(activated_throttled, &Map.put(&1, :is_current, true))

    activated_unthrottled ++ activated_throttled ++ pending_throttled
  end

  defp get_throttle_ad_count do
    Qlarius.System.get_global_variable_int("THROTTLE_AD_COUNT", 3)
  end

  defp delete_invalid_offers(_me_file_id, existing_offers, keys_to_remove) do
    if keys_to_remove == [] do
      0
    else
      offer_ids_to_delete =
        Enum.filter(existing_offers, fn o ->
          key = {o.campaign_id, o.media_run_id, o.target_band_id}
          key in keys_to_remove
        end)
        |> Enum.map(& &1.id)

      {count, _} =
        from(o in Offer,
          where: o.id in ^offer_ids_to_delete
        )
        |> Repo.delete_all()

      count
    end
  end

  defp get_current_me_file_tags(me_file_id) do
    tags =
      from(mft in MeFileTag,
        where: mft.me_file_id == ^me_file_id,
        join: t in assoc(mft, :trait),
        select: %{
          trait_id: t.id,
          trait_name: t.trait_name,
          parent_trait_id: t.parent_trait_id
        }
      )
      |> Repo.all()
      |> Enum.map(fn tag ->
        %{
          "trait_id" => tag.trait_id,
          "trait_name" => tag.trait_name,
          "parent_trait_id" => tag.parent_trait_id
        }
      end)

    %{"tags" => tags, "snapshot_at" => NaiveDateTime.utc_now() |> NaiveDateTime.to_iso8601()}
  end
end
