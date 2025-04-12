class EmailOfferNotificationWorker < ApplicationJob

  def perform(mf_id_array)
    mf_id_array.each { |this_mf_id| AdOfferNotificationEmailMailer.with(me_file_id: this_mf_id).notification_email.deliver_now}
  end

end