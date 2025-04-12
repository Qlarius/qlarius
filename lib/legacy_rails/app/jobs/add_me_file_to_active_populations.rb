class AddMeFileToActivePopulations < ApplicationJob

  def perform(me_file_id, try_to_make_current_immediately=nil)
    Rails.logger.info "MeFile #{me_file_id} :: AddMeFileToActivePopulations :: entering"
    Sidekiq.logger.info "MeFile #{me_file_id} :: AddMeFileToActivePopulations :: entering"

    # check all active campaigns to see if mefile belongs -- NEED TO OPTIMIZE -- HOW?
    target_band_ids = Target.includes(:campaigns).where(campaigns: { deactivated_at: nil }).inject([]) do |acc, t|
      # if mefile belongs add the optimal target band id to acc array
      acc << t.optimal_band_for_me_file(me_file_id).id if t.optimal_band_for_me_file(me_file_id)
      acc
    end
    Rails.logger.info "MeFile #{me_file_id} :: AddMeFileToActivePopulations :: optimal targetbands for current campaigns = #{target_band_ids}"
    Sidekiq.logger.info "MeFile #{me_file_id} :: AddMeFileToActivePopulations :: optimal targetbands for current campaigns = #{target_band_ids}"

    # remove target_populations from array if already existing - to only add new
    target_bands_to_insert = target_band_ids - TargetPopulation.where(me_file_id: me_file_id).pluck(:target_band_id).uniq
    Rails.logger.info "MeFile #{me_file_id} :: AddMeFileToActivePopulations :: new targetbands to add = #{target_bands_to_insert}"
    target_populations_data = target_bands_to_insert.inject([]) do |acc, target_band_id|
      acc << { target_band_id: target_band_id, me_file_id: me_file_id }
      acc
    end
    Rails.logger.info "MeFile #{me_file_id} :: AddMeFileToActivePopulations ::  create target_populations_data new to add = #{target_populations_data}"
    Sidekiq.logger.info "MeFile #{me_file_id} :: AddMeFileToActivePopulations ::  create target_populations_data new to add = #{target_populations_data}"
    TargetPopulation.create(target_populations_data) if target_populations_data.present?

    #exclude bids/offers where offer is already present
    filtered_bids = Bid.where(target_band_id: target_band_ids).to_a
    Offer.where(me_file_id: me_file_id).each do |o|
      filtered_bids.reject! {|b| b.campaign_id == o.campaign_id && b.target_band_id == o.target_band_id && b.media_run == o.media_run}
    end
    Rails.logger.info "MeFile #{me_file_id} :: AddMeFileToActivePopulations ::  bids without current offers  = #{filtered_bids}"
    Sidekiq.logger.info "MeFile #{me_file_id} :: AddMeFileToActivePopulations ::  bids without current offers  = #{filtered_bids}"

    # remove from array if media_run is complete  TO BE CONTINUED
    active_campaign_ids = Campaign.where(deactivated_at: nil).pluck(:id)  #OPTIMIZATION needed so not to check all active campaigns, only campaigns in relevant target populations
    media_runs_completed_ad_events = AdEvent.where(me_file_id: me_file_id).where(campaign_id: active_campaign_ids).where(is_offer_complete: true).select {|ad_event| ad_event.is_media_run_complete? }
    #delete any rogue offers where media run is already complete
    offers_to_delete = Offer.where(id: media_runs_completed_ad_events.pluck(:offer_id))
    Rails.logger.info "MeFile #{me_file_id} :: AddMeFileToActivePopulations ::  count of rogue offers found to delete = #{offers_to_delete.length}"
    if offers_to_delete.length > 0
      Rails.logger.info "MeFile #{me_file_id} :: AddMeFileToActivePopulations ::  deleting offers #{offers_to_delete.pluck(:id)} from campaigns #{offers_to_delete.pluck(:campaign_id)}"
      offers_to_delete.delete_all
    end
    #remove potential rogue offers from array where media run already complete (so as not to add new offers)
    media_runs_completed_ad_events.each do |ae|      
      filtered_bids.reject! {|b| b.campaign_id == ae.campaign_id && b.media_run == ae.media_run}
    end
    Rails.logger.info "MeFile #{me_file_id} :: AddMeFileToActivePopulations ::  final filtered bids to add (that do not already exist) = #{filtered_bids}"
    Sidekiq.logger.info "MeFile #{me_file_id} :: AddMeFileToActivePopulations ::  final filtered bids to add (that do not already exist) = #{filtered_bids}"

    offers_data = filtered_bids.inject([]) do |acc, bid|
      acc << {
        campaign_id:                bid.campaign_id,
        me_file_id:                 me_file_id,
        media_run_id:               bid.media_run.id,
        media_piece_id:             bid.media_run.media_piece.id,
        ad_phase_count_to_complete: bid.media_run.media_piece.media_piece_type.ad_phase_count_to_complete,
        target_band_id:             bid.target_band.id,
        matching_tags_snapshot:     bid.target_band.me_file_matching_traits(me_file_id),
        offer_amt:                  bid.offer_amt.to_f,
        marketer_cost_amt:          bid.marketer_cost_amt.to_f,
        pending_until:              bid.campaign.start_date.to_fs(:db),
        is_throttled:               bid.campaign.is_throttled,
        is_demo:                    bid.campaign.is_demo,
        is_payable:                 bid.campaign.is_payable,
        is_current:                 false
      } if bid.campaign.present?
      acc
    end
    Offer.create(offers_data) if offers_data.present?
    ActivateUnthrottledOffersPastPendingUntil.perform_later if try_to_make_current_immediately
  end
end
