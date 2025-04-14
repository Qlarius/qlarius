class SmsOfferNotificationWorker < ApplicationJob

  def perform(mf_id_array)
    mf_id_array.each { |this_mf_id| MeFile.find(this_mf_id).current_mobile_phone.send_sms_ad_notification if MeFile.find(this_mf_id).current_mobile_phone }
  end

end