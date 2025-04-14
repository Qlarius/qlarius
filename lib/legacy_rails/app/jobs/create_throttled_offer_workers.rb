class CreateThrottledOfferWorkers < ApplicationJob
  # fetch unique me_file_ids from offers that are past pending_thru date and not current and not jobbed, ordered by me_file_id
  # divide me_file_id array into parts of 200 me_files
  # create graduate_offers_to_current jobs for each grouping, sending first me_file_id and last_me_file_id - last group sends -999999 as last_me_file_id to indicate to grab any new me_files

  # this should be run every 10 minutes
  def perform
    Rails.logger.info '***** CreateThrottledOfferWorkers *****'

    throttle_limit = GlobalVariable.where("name = 'THROTTLE_AD_COUNT'").first.value.to_i
    throttle_days_per = GlobalVariable.where("name = 'THROTTLE_DAYS'").first.value.to_i
    me_files_per_group = GlobalVariable.where("name = 'THROTTLE_JOB_WORKER_MEFILE_COUNT'").first.value.to_i
    me_file_ids = Offer.where(is_throttled: true).where(is_current: false).where("pending_until <= ?", Time.zone.now.to_fs(:db)).order(:me_file_id).pluck(:me_file_id).uniq

    Rails.logger.info "create workers for #{me_file_ids.count} me_files"
    me_file_ids.in_groups_of(me_files_per_group, false).each do |group|
      ThrottledOfferWorker.perform_later(group.first, group.last, throttle_limit, throttle_days_per)
    end
  end
end
