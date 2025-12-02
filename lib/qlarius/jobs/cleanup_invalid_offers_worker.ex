defmodule Qlarius.Jobs.CleanupInvalidOffersWorker do
  use Oban.Worker, queue: :default, max_attempts: 1

  import Ecto.Query
  alias Qlarius.Repo
  alias Qlarius.Sponster.{Offer, AdEvent}
  alias Qlarius.Sponster.Campaigns.{Campaign, TargetPopulation}

  @batch_size 1000

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    require Logger
    Logger.info("CleanupInvalidOffersWorker: Starting cleanup")

    {deactivated_count, orphaned_count, completed_count} = cleanup_invalid_offers()

    Logger.info(
      "CleanupInvalidOffersWorker: Cleanup complete - deactivated campaigns: #{deactivated_count}, orphaned: #{orphaned_count}, completed media runs: #{completed_count}"
    )

    :ok
  end

  defp cleanup_invalid_offers do
    deactivated_count = cleanup_offers_for_deactivated_campaigns()
    orphaned_count = cleanup_orphaned_offers()
    completed_count = cleanup_completed_media_run_offers()

    {deactivated_count, orphaned_count, completed_count}
  end

  defp cleanup_offers_for_deactivated_campaigns do
    require Logger

    {count, _} =
      from(o in Offer,
        join: c in Campaign,
        on: o.campaign_id == c.id,
        where: not is_nil(c.deactivated_at)
      )
      |> Repo.delete_all()

    Logger.info("CleanupInvalidOffersWorker: Deleted #{count} offers for deactivated campaigns")
    count
  end

  defp cleanup_orphaned_offers do
    require Logger

    offers_to_check =
      from(o in Offer,
        left_join: tp in TargetPopulation,
        on:
          tp.me_file_id == o.me_file_id and
            tp.target_band_id == o.target_band_id,
        where: is_nil(tp.id),
        select: o.id
      )
      |> Repo.all()
      |> Enum.chunk_every(@batch_size)

    count =
      Enum.reduce(offers_to_check, 0, fn batch, acc ->
        {deleted, _} =
          from(o in Offer,
            where: o.id in ^batch
          )
          |> Repo.delete_all()

        acc + deleted
      end)

    Logger.info("CleanupInvalidOffersWorker: Deleted #{count} orphaned offers")
    count
  end

  defp cleanup_completed_media_run_offers do
    require Logger

    offers_to_check =
      from(o in Offer,
        distinct: [o.me_file_id, o.media_run_id],
        join: mr in assoc(o, :media_run),
        where: not is_nil(mr.frequency),
        select: %{
          me_file_id: o.me_file_id,
          media_run_id: o.media_run_id,
          frequency: mr.frequency
        }
      )
      |> Repo.all()

    offer_ids_to_delete =
      Enum.flat_map(offers_to_check, fn %{
                                          me_file_id: me_file_id,
                                          media_run_id: media_run_id,
                                          frequency: frequency
                                        } ->
        completed_count =
          from(ae in AdEvent,
            where: ae.me_file_id == ^me_file_id,
            where: ae.media_run_id == ^media_run_id,
            where: ae.is_offer_complete == true,
            select: count(ae.id)
          )
          |> Repo.one()

        if completed_count >= frequency do
          from(o in Offer,
            where: o.me_file_id == ^me_file_id,
            where: o.media_run_id == ^media_run_id,
            select: o.id
          )
          |> Repo.all()
        else
          []
        end
      end)

    count =
      if offer_ids_to_delete != [] do
        offer_ids_to_delete
        |> Enum.chunk_every(@batch_size)
        |> Enum.reduce(0, fn batch, acc ->
          {deleted, _} =
            from(o in Offer,
              where: o.id in ^batch
            )
            |> Repo.delete_all()

          acc + deleted
        end)
      else
        0
      end

    Logger.info("CleanupInvalidOffersWorker: Deleted #{count} offers for completed media runs")
    count
  end
end
