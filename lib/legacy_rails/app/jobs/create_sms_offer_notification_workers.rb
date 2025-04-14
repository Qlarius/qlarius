class CreateSmsOfferNotificationWorkers < ApplicationJob

  def perform

    Rails.logger.info "CreateSMSOfferNotificationWorkers :: ENTERING"

    me_files_per_group = GlobalVariable.where("name = 'SPONSTER_OFFER_SMS_NOTIFICATION_WORKER_MEFILE_COUNT'").first.value.to_i

    # grab MeFiles with active offers
    me_file_ids_with_offers = Offer.where(is_current:true).order(:me_file_id).pluck(:me_file_id).uniq
    Rails.logger.info "CreateSMSOfferNotificationWorkers :: me_file_ids_with_offers count = #{me_file_ids_with_offers.count}"

    # grab MeFiles with SMS notifications on
    me_file_ids_with_email_notifications_on = MeFile.joins(user: :user_pref).where('user_prefs.sponster_email_alerts' => true).order('me_files.id').pluck('me_files.id')
    Rails.logger.info "CreateSMSOfferNotificationWorkers :: me_file_ids_with_email_notifications_on count = #{me_file_ids_with_email_notifications_on.count}"
    
    # union the two for list of MeFiles to SMS
    me_files_to_notify = me_file_ids_with_offers & me_file_ids_with_email_notifications_on
    Rails.logger.info "CreateSMSOfferNotificationWorkers :: me_files_to_notify count = #{me_files_to_notify.count}"

    # divvy up and process emails in batches
    me_files_to_notify.in_groups_of(me_files_per_group, false).each do |group|
      Rails.logger.info "CreateSMSOfferNotificationWorkers :: group = #{group}"
      SmsOfferNotificationWorker.perform_later(group)
    end
    
  end

end