defmodule Qlarius.Jobs.UpdateCampaignOffersWorker do
  use Oban.Worker, queue: :default, priority: 0

  import Ecto.Query
  alias Qlarius.Repo
  alias Qlarius.Sponster.Offer

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"campaign_id" => campaign_id, "bid_changes" => bid_changes}}) do
    Enum.each(bid_changes, fn %{
                                "target_band_id" => target_band_id,
                                "offer_amt" => offer_amt,
                                "marketer_cost_amt" => marketer_cost_amt
                              } ->
      offer_amt_decimal = Decimal.new(offer_amt)
      marketer_cost_amt_decimal = Decimal.new(marketer_cost_amt)

      from(o in Offer,
        where: o.campaign_id == ^campaign_id and o.target_band_id == ^target_band_id
      )
      |> Repo.update_all(
        set: [
          offer_amt: offer_amt_decimal,
          marketer_cost_amt: marketer_cost_amt_decimal,
          updated_at: DateTime.utc_now()
        ]
      )
    end)

    :ok
  end
end
