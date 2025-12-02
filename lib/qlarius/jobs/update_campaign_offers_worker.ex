defmodule Qlarius.Jobs.UpdateCampaignOffersWorker do
  use Oban.Worker, queue: :offers, priority: 0

  import Ecto.Query
  alias Qlarius.Repo
  alias Qlarius.Sponster.{Offer, Campaigns.Campaign}
  alias Qlarius.Sponster.Campaigns.CampaignPubSub

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"campaign_id" => campaign_id, "bid_changes" => bid_changes}}) do
    require Logger
    Logger.info("UpdateCampaignOffersWorker: Updating offers for campaign #{campaign_id}")

    campaign = Repo.get!(Campaign, campaign_id)

    total_updated =
      Enum.reduce(bid_changes, 0, fn %{
                                       "target_band_id" => target_band_id,
                                       "offer_amt" => offer_amt,
                                       "marketer_cost_amt" => marketer_cost_amt
                                     },
                                     acc ->
        offer_amt_decimal = Decimal.new(offer_amt)
        marketer_cost_amt_decimal = Decimal.new(marketer_cost_amt)

        {count, _} =
          from(o in Offer,
            where: o.campaign_id == ^campaign_id and o.target_band_id == ^target_band_id
          )
          |> Repo.update_all(
            set: [
              offer_amt: offer_amt_decimal,
              marketer_cost_amt: marketer_cost_amt_decimal,
              updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
            ]
          )

        acc + count
      end)

    Logger.info(
      "UpdateCampaignOffersWorker: Updated #{total_updated} offers for campaign #{campaign_id}"
    )

    if total_updated > 0 do
      CampaignPubSub.broadcast_campaign_updated(campaign_id)
      CampaignPubSub.broadcast_marketer_campaign_updated(campaign.marketer_id, campaign_id)
    end

    :ok
  end
end
