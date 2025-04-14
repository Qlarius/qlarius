require 'services/sms'

class MobilePhone < ApplicationRecord
  belongs_to :me_file

  def active?
    activated_at.present? && deactivated_at.nil?
  end

  def awaiting_activation?
    activated_at.nil? && deactivated_at.nil?
  end

  def send_sms_activation_code
    Service::SMS.deliver_activation_code(mobile_number, activation_code)
  end

  def send_sms_ad_notification
    url = ENV['SHOW_ME_URL']
    Service::SMS.deliver_ad_notification(mobile_number, me_file.current_offers.reload.count, me_file.current_offers.sum(:offer_amt), url)
  end

end
