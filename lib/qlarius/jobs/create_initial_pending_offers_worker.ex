defmodule Qlarius.Jobs.CreateInitialPendingOffersWorker do
  use Oban.Worker, queue: :default, max_attempts: 5

  import Ecto.Query
  alias Qlarius.Repo
  alias Qlarius.Sponster.Campaigns.{Campaign, TargetPopulation, CampaignPubSub}
  alias Qlarius.Sponster.Offer

  @batch_size 1000

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"campaign_id" => campaign_id}}) do
    require Logger

    campaign =
      Repo.get!(Campaign, campaign_id)
      |> Repo.preload(
        target: [target_bands: []],
        bids: [:media_run],
        media_sequence: [media_runs: [media_piece: :media_piece_type]]
      )

    Logger.info(
      "CreateInitialPendingOffersWorker: Campaign #{campaign_id}, Target status: #{campaign.target.population_status}"
    )

    if campaign.target.population_status != "populated" do
      Logger.warning(
        "CreateInitialPendingOffersWorker: Target not populated for campaign #{campaign_id}, snoozing for 3 minutes"
      )

      {:snooze, 180}
    else
      create_offers_for_campaign(campaign)
      :ok
    end
  end

  defp create_offers_for_campaign(campaign) do
    target_band_ids = Enum.map(campaign.target.target_bands, & &1.id)

    bids_by_band_id =
      campaign.bids
      |> Enum.group_by(& &1.target_band_id)
      |> Map.new(fn {band_id, bids} -> {band_id, List.first(bids)} end)

    media_run = List.first(campaign.media_sequence.media_runs)

    unless media_run do
      raise "Campaign #{campaign.id} has no media runs"
    end

    ad_phase_count =
      if media_run.media_piece && media_run.media_piece.media_piece_type do
        media_run.media_piece.media_piece_type.ad_phase_count_to_complete
      else
        1
      end

    target_populations_query =
      from(tp in TargetPopulation,
        where: tp.target_band_id in ^target_band_ids,
        select: %{
          me_file_id: tp.me_file_id,
          target_band_id: tp.target_band_id,
          matching_tags_snapshot: tp.matching_tags_snapshot
        }
      )

    total_inserted =
      Repo.transaction(
        fn ->
          target_populations_query
          |> Repo.stream()
          |> Stream.chunk_every(@batch_size)
          |> Enum.reduce(0, fn batch, acc ->
            count = process_batch(batch, campaign, bids_by_band_id, media_run, ad_phase_count)
            acc + count
          end)
        end,
        timeout: :infinity
      )

    case total_inserted do
      {:ok, count} when count > 0 ->
        CampaignPubSub.broadcast_offers_created(campaign.id, count)
        CampaignPubSub.broadcast_marketer_campaign_updated(campaign.marketer_id, campaign.id)

      _ ->
        :ok
    end
  end

  defp process_batch(target_populations, campaign, bids_by_band_id, media_run, ad_phase_count) do
    require Logger
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    offers_data =
      Enum.flat_map(target_populations, fn tp ->
        bid = Map.get(bids_by_band_id, tp.target_band_id)

        if bid do
          [
            %{
              campaign_id: campaign.id,
              me_file_id: tp.me_file_id,
              media_run_id: media_run.id,
              media_piece_id: media_run.media_piece_id,
              target_band_id: tp.target_band_id,
              offer_amt: bid.offer_amt,
              marketer_cost_amt: bid.marketer_cost_amt,
              pending_until: campaign.launched_at,
              is_payable: campaign.is_payable,
              is_throttled: campaign.is_throttled,
              is_demo: campaign.is_demo,
              is_current: false,
              is_jobbed: false,
              matching_tags_snapshot: tp.matching_tags_snapshot,
              ad_phase_count_to_complete: ad_phase_count,
              created_at: now,
              updated_at: now
            }
          ]
        else
          []
        end
      end)

    if offers_data != [] do
      {count, _} =
        Repo.insert_all(Offer, offers_data,
          on_conflict: :nothing,
          conflict_target: [:campaign_id, :me_file_id, :media_run_id]
        )

      Logger.info(
        "CreateInitialPendingOffersWorker: Inserted #{count} offers for campaign #{campaign.id}"
      )

      count
    else
      Logger.warning(
        "CreateInitialPendingOffersWorker: No offers to insert for campaign #{campaign.id} in this batch"
      )

      0
    end
  end
end
