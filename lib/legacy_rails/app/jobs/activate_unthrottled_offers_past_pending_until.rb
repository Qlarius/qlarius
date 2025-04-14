class ActivateUnthrottledOffersPastPendingUntil < ApplicationJob

  # make current if is_current=0 AND is_throttled=0 AND is_jobbed=0 AND pending_until less than now

  # runs every 5 minutes
  def perform
    Rails.logger.info '***** ActivateUnthrottledOffersPastPendingUntil *****'

    now = Time.zone.now.to_formatted_s(:db)
    Rails.logger.info "activating offers with pending_until before #{now}"
    Offer.where(is_current: false).where(is_throttled: false).where('pending_until <= ?', now).update_all(is_current: true)
  end
end
