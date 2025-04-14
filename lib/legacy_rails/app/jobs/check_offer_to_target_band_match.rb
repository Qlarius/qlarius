class CheckOfferToTargetBandMatch < ApplicationJob
  
    def perform(me_file_id)

        Rails.logger.info "MeFile #{me_file_id} :: worker CheckOfferToTargetBandMatch :: ENTERING"
        mf = MeFile.find (me_file_id)
        Rails.logger.info "MeFile #{mf.id} :: worker CheckOfferToTargetBandMatch :: user #{mf.display_name_dynamic}"

        #check each offer to see if MeFile is still in target band, destroy offer if not
        Rails.logger.info "MeFile #{mf.id} :: worker CheckOfferToTargetBandMatch :: checking #{mf.offers.length} offers"
        @destroyed_count = 0
        mf.offers.each do |o|
            o_result = o.is_me_file_in_target_band?
            campaign_title = o.campaign&.title || 'DELETED_CAMPAIGN'
            Rails.logger.info "MeFile #{mf.id} :: worker CheckOfferToTargetBandMatch :: offer #{o.id}, campaign #{campaign_title}, result: #{o_result}"
            if o_result == false
                Rails.logger.info "MeFile #{mf.id} :: worker CheckOfferToTargetBandMatch :: offer #{o.id} should destroy"
                if o.destroy
                    Rails.logger.info "MeFile #{mf.id} :: worker CheckOfferToTargetBandMatch :: offer #{o.id}, campaign #{campaign_title} destroyed"
                    @destroyed_count += 1
                end
            end
        end

        Rails.logger.info "MeFile #{mf.id} :: worker CheckOfferToTargetBandMatch :: #{@destroyed_count} offer(s) destroyed"

        #if offers destroyed, indicates that MeFile tags deleted/changed, run job to match to appropriate target bands
        if @destroyed_count > 0
            job = AddMeFileToActivePopulations.perform_now(mf.id)
            Rails.logger.info "MeFile #{mf.id} :: worker CheckOfferToTargetBandMatch :: AddMeFileToActivePopulations job created #{job}"
        end

        Rails.logger.info "MeFile #{mf.id} :: worker CheckOfferToTargetBandMatch :: COMPLETE"

    end

end