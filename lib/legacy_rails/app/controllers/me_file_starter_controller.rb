class MeFileStarterController < ApplicationController

  # before_action :authorize!

  def index
    check_mobile_number
  end

  def check_mobile_number
    number_is_valid = false
    number_is_available = false
    reply_contents = {"foo": "bar"}
    if @current_me_file.user.is_active_proxy_user?
      @number_to_check = @current_me_file.true_user.mobile_number.gsub(/\D/, '')
    else
      @number_to_check = @current_me_file.user.mobile_number.gsub(/\D/, '')
    end
    # @number_to_check = "6503958208"
    # @number_to_check = "7138543564"
    account_sid = ENV['TWILIO_SID']
    auth_token = ENV['TWILIO_TOKEN']
    @client = Twilio::REST::Client.new(account_sid, auth_token)
    if @client.auth_token.nil?
      reply_contents = {status: "failure", message: "Connection unavailable"}
    else
      begin
        phone_number_info = @client.lookups
          .v1
          .phone_numbers(@number_to_check)
          .fetch(type: ['carrier'])
        reply_contents = {status: "success", message: phone_number_info.carrier}
      rescue
        reply_contents = {status: "failure", message: "Not a valid US mobile number"}
      end
    end
    @phone_status = reply_contents
  end

  def get_zip_code_info
    if params[:zip] && params[:zip].length == 5
      city_state = get_city_state_from_api(params[:zip])
      render json: { city: city_state["city"], state: city_state["state"] }
    else
      render json: { error: 'Invalid ZIP code' }
    end
  end

  def save_basics_to_me_file
    #sex/gender
    if params[:sex] != 0
      Rails.logger.info "params[:sex] = " + params[:sex].to_s
      @current_me_file.create_tags([params[:sex]], 1)
    end
    #date & age
    date_string = params[:yyyy].to_s + "-" + params[:mm].to_s + "-" + params[:dd].to_s
    @current_me_file.update!(date_of_birth: date_string)
    @current_me_file.update_age_tag
    Rails.logger.info "params[:zip] = " + params[:zip].to_s
    #home zip
    if params[:zip].length == 5
      Rails.logger.info "ZIP FOUND " + params[:zip].to_s
      zip_trait = Trait.where(parent_trait_id: 4, trait_name: params[:zip]).first
      Rails.logger.info "***** zip_trait = " + zip_trait.inspect
      @current_me_file.create_tags([zip_trait.id], 4)
    end
    #create ledger_header
    LedgerHeader.create(:me_file_id => @current_me_file.id, :balance => 0.00, :balance_payable => 0.00) if @current_me_file.is_me_file_mvp? if @current_me_file.ledger_header.nil?
    #create job for first ads (now)
    AddMeFileToActivePopulations.perform_now(@current_me_file.id, true)
    #go to home page
    Rails.logger.info "@@@@@@@@ should redirect_to root_path"
    redirect_to root_path
  end

private

def get_city_state_from_api(zip_code)
  response = HTTParty.get("https://www.zipcodeapi.com/rest/#{ENV['ZIP_CODE_API_KEY']}/info.json/#{zip_code}/degrees")
  Rails.logger.info JSON.parse response.body
  JSON.parse(response.body)
end
  
end
