class CreateInitialPendingOffers < ApplicationJob
  # fetch the campaign object
  # if target_populations is not yet built, create a new job delayed three minutes
  # else create initial pending offers

  def perform(campaign_id)
    Rails.logger.info '***** CreateInitialPendingOffers *****'

    campaign = Campaign.find_by(id: campaign_id)
    if campaign.target.try(:is_populated?)
      offers_data = TargetPopulation.includes(target_band: { bids: [:campaign, media_run: { media_piece: :media_piece_type }] }).where(campaigns: { id: campaign.id }).inject([]) do |acc, target_population|
        target_population.target_band.bids.each do |bid|
          acc << {
            campaign_id:                campaign.id,
            me_file_id:                 target_population.me_file_id,
            media_run_id:               bid.media_run.id,
            media_piece_id:             bid.media_run.media_piece.id,
            ad_phase_count_to_complete: bid.media_run.media_piece.media_piece_type.ad_phase_count_to_complete,
            target_band_id:             bid.target_band.id,
            offer_amt:                  bid.offer_amt.to_f,
            marketer_cost_amt:          bid.marketer_cost_amt.to_f,
            pending_until:              campaign.start_date.to_s(:db),
            is_throttled:               campaign.is_throttled,
            is_demo:                    campaign.is_demo,
            is_payable:                 campaign.is_payable,
            is_current:                 false,
            matching_tags_snapshot:     bid.target_band.me_file_matching_traits(target_population.me_file_id)
          }
        end
        acc
      end
      Offer.create(offers_data)
    else
      # in case the initial target population is not yet processed and created, try again in 3 minutes
      CreateInitialPendingOffers.perform_in(3.minutes, campaign.id)
    end
  end
end
