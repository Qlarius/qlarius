defmodule Qlarius.Jobs.ActivatePendingOffersWorker do
  use Oban.Worker, queue: :activations, max_attempts: 1

  import Ecto.Query
  alias Qlarius.Repo
  alias Qlarius.Sponster.Offer
  alias Qlarius.Sponster.AdEvent
  alias Qlarius.System
  alias Qlarius.Sponster.Campaigns.CampaignPubSub

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    require Logger
    Logger.info("ActivatePendingOffersWorker: Starting activation cycle")

    now = NaiveDateTime.utc_now()
    throttle_limit = System.get_global_variable_int("THROTTLE_AD_COUNT", 3)
    throttle_days = System.get_global_variable_int("THROTTLE_DAYS", 7)

    Logger.info(
      "ActivatePendingOffersWorker: throttle_limit=#{throttle_limit}, throttle_days=#{throttle_days}"
    )

    activate_unthrottled_offers(now)
    activate_throttled_offers(now, throttle_limit, throttle_days)

    Logger.info("ActivatePendingOffersWorker: Activation cycle complete")
    :ok
  end

  defp activate_unthrottled_offers(now) do
    require Logger

    {count, _} =
      from(o in Offer,
        where: o.is_current == false,
        where: o.is_throttled == false,
        where: o.pending_until <= ^now
      )
      |> Repo.update_all(set: [is_current: true, updated_at: now])

    Logger.info("ActivatePendingOffersWorker: Activated #{count} unthrottled offers")

    if count > 0 do
      broadcast_activations()
    end

    count
  end

  defp activate_throttled_offers(now, throttle_limit, throttle_days) do
    require Logger
    seven_days_ago = NaiveDateTime.add(now, -throttle_days * 24 * 60 * 60, :second)

    throttled_offers_by_me_file =
      from(o in Offer,
        where: o.is_current == false,
        where: o.is_throttled == true,
        where: o.pending_until <= ^now,
        order_by: [asc: o.me_file_id, asc: o.pending_until, asc: o.id],
        select: %{
          id: o.id,
          me_file_id: o.me_file_id,
          campaign_id: o.campaign_id
        }
      )
      |> Repo.all()
      |> Enum.group_by(& &1.me_file_id)

    Logger.info(
      "ActivatePendingOffersWorker: Processing throttled offers for #{map_size(throttled_offers_by_me_file)} me_files"
    )

    total_activated =
      Enum.reduce(throttled_offers_by_me_file, 0, fn {me_file_id, offers}, acc ->
        current_count = count_current_throttled_offers(me_file_id)
        completed_count = count_completed_throttled_ads(me_file_id, seven_days_ago)

        max_used = max(current_count, completed_count)
        remaining_slots = max(0, throttle_limit - max_used)

        if remaining_slots > 0 do
          offers_to_activate = Enum.take(offers, remaining_slots)
          offer_ids = Enum.map(offers_to_activate, & &1.id)
          campaign_ids = Enum.map(offers_to_activate, & &1.campaign_id) |> Enum.uniq()

          {activated, _} =
            from(o in Offer,
              where: o.id in ^offer_ids
            )
            |> Repo.update_all(set: [is_current: true, updated_at: now])

          if activated > 0 do
            Logger.info(
              "ActivatePendingOffersWorker: MeFile #{me_file_id}: activated #{activated} throttled offers (current=#{current_count}, completed=#{completed_count}, limit=#{throttle_limit})"
            )

            Enum.each(campaign_ids, fn campaign_id ->
              CampaignPubSub.broadcast_offers_created(campaign_id, activated)
            end)
          end

          acc + activated
        else
          Logger.debug(
            "ActivatePendingOffersWorker: MeFile #{me_file_id}: blocked (current=#{current_count}, completed=#{completed_count}, limit=#{throttle_limit})"
          )

          acc
        end
      end)

    Logger.info(
      "ActivatePendingOffersWorker: Activated #{total_activated} throttled offers total"
    )

    total_activated
  end

  defp count_current_throttled_offers(me_file_id) do
    from(o in Offer,
      where: o.me_file_id == ^me_file_id,
      where: o.is_current == true,
      where: o.is_throttled == true,
      select: count(o.id)
    )
    |> Repo.one()
  end

  defp count_completed_throttled_ads(me_file_id, since_date) do
    from(ae in AdEvent,
      where: ae.me_file_id == ^me_file_id,
      where: ae.is_throttled == true,
      where: ae.created_at >= ^since_date,
      select: count(ae.id)
    )
    |> Repo.one()
  end

  defp broadcast_activations do
    CampaignPubSub.broadcast_offers_activated()
  end
end
