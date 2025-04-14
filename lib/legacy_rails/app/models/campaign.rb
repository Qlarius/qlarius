class Campaign < ApplicationRecord
  before_save :set_default_values

  belongs_to :marketer
  belongs_to :media_sequence
  belongs_to :target
  has_one :ledger_header, dependent: :delete
  has_many :bids, dependent: :delete_all
  has_many :offers, dependent: :delete_all
  has_many :ad_events

  has_one :view_campaign_banner_text_metric

  def total_spend_to_date
    ad_events.sum(:event_marketer_cost_amt)
  end

  def seed_initial_bids
    media_sequence.media_runs.each do |media_run|
      target.target_bands.each do |target_band|
        if target_band.bids.where(campaign_id: id, media_run_id: media_run.id).blank?
          minimum_bid_amount = target_band.minimum_bid_amount
          target_band.bids.create(
            campaign_id:        id,
            media_run_id:       media_run.id,
            offer_amt:          minimum_bid_amount,
            marketer_cost_amt:  minimum_bid_amount * 1.50 + 0.10
          )
        end
      end
    end
  end

  def seed_initial_ledger_header
    create_ledger_header(balance: 0.0) unless ledger_header
  end

  private
  def set_default_values
    self.is_throttled ||= 0
    self.is_demo ||= 0
  end
end
