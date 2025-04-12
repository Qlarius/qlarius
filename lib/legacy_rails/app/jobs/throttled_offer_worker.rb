class ThrottledOfferWorker < ApplicationJob

  def perform(from_me_file_id, through_me_file_id, throttle_limit_passed, throttle_days_per_passed)
    Rails.logger.info '***** ThrottledOfferWorker *****'

    # fetch unique me_file_ids within range from offers that are past pending_thru date and not current and not jobbed, ordered by me_file_id
    # mark offers for those me_files as jobbed
    # iterate though each me_file in the array and mark current any eligible offers
    return if from_me_file_id.blank? || through_me_file_id.blank?

    Rails.logger.info "offer_worker for me_files #{from_me_file_id} - #{through_me_file_id}"
    me_file_id_and_offer_id_hash = Offer.where(is_throttled: true).where(is_current: false).where("me_file_id >= ?", from_me_file_id).where("me_file_id <= ?", through_me_file_id).where("pending_until <= ?", Time.zone.now.to_fs(:db)).select([:me_file_id, :id]).to_a

    Rails.logger.info "no throttled offers currently to check" and return if me_file_id_and_offer_id_hash.empty?
    me_file_ids =  me_file_id_and_offer_id_hash.map(&:me_file_id).uniq.sort
    Rails.logger.info "to examine #{me_file_ids.count} me_file(s)"

    ad_event_counts = AdEvent.where(is_throttled: true).where(media_piece_phase_id: true).where(me_file_id: me_file_ids).where("created_at >= ?", throttle_days_per_passed.days.ago.to_s(:db)).select(:me_file_id).group(:me_file_id).count(:id)
    offer_counts = Offer.where(is_throttled: true).where(is_current: true).where(me_file_id: me_file_ids).select(:me_file_id).group(:me_file_id).count(:id)
    offer_ids = me_file_ids.inject([]) do |acc, me_file_id|
      throttled_offer_count = (ad_event_counts[me_file_id].presence || 0) + (offer_counts[me_file_id].presence || 0)
      number_of_offers_to_activate = throttle_limit_passed - throttled_offer_count
      if number_of_offers_to_activate > 0
        acc += me_file_id_and_offer_id_hash.select {|x| x.me_file_id == me_file_id}.first(number_of_offers_to_activate).map(&:id)
      end
      acc
    end

    Rails.logger.info "offers to activate = #{offer_ids.count}"
    Rails.logger.info "no offers currently to update after throttling check" and return if offer_ids.empty?
    Offer.where(id: offer_ids).update_all(is_current: true)
  end
end
