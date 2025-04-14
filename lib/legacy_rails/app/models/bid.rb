class Bid < ApplicationRecord
  belongs_to :campaign
  belongs_to :media_run
  belongs_to :target_band

  def update_current_offers
    Offer.where(campaign_id: campaign_id, media_run_id: media_run_id, target_band_id: target_band_id).update_all(offer_amt: offer_amt, marketer_cost_amt: marketer_cost_amt)
  end
end
