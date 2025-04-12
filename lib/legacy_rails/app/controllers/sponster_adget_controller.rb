require "browser/aliases"

class SponsterAdgetController < ApplicationController
  Browser::Base.include(Browser::Aliases)
  # layout 'sponster_adget_frame_layout'
  before_action :get_sponster_user
  before_action :get_recipient_info
  # skip_before_action :authenticate_user!
  # skip_before_action :verify_authenticity_token

  def index
    if @current_sponster_user
      @split_amount = @current_sponster_user.me_file.split_amount
      flush_used_offers
      set_click_or_tap_string
    end
    log_widget_serve
  end

  def refresh_offers
    flush_used_offers
    set_click_or_tap_string
    get_sponster_user
    get_recipient_info
    Rails.logger.info "************ Refresh split info: " + @this_recipient.split_code + ":" + @this_recipient.id.to_s + ":" + @split_amount.to_s
    respond_to do |format|
      format.js
    end
  end

  def refresh_offer_counts
    respond_to do |format|
      format.js
    end
  end

  def reveal_banner
    set_click_or_tap_string
    respond_to do |format|
      format.js
    end
  end

  def collect_banner_impression
    if @current_sponster_user.me_file.offers.find_by(id: params[:offer_id]).blank?
      @error_message = "ERROR - not current offer"
    else
      @current_sponster_user.me_file.collect_banner_impression(params[:offer_id], params[:split_code], @this_recipient, request.remote_ip, request.url)
    end
    respond_to do |format|
      format.js
    end
  end

  def ad_jump_collection
    split_code = cookies[:split_code]
    result = MeFile.find_by(sponster_token: params[:sponster_token]).collect_ad_jump(params[:offer_id], split_code, request.remote_ip, split_code)
    if result[:success]
      redirect_to result[:offer].media_piece.jump_url, allow_other_host: true
    else
      render layout: false
    end
  end

  def close_offer
    collected = @current_sponster_user.me_file.close_offer(params[:offer_id])
    @collected_amount = collected[:collected_amount]
    @given_amount = collected[:given_amount]
    @this_recipient ||= @current_sponster_user.me_file.ad_events.reload.where("offer_id=#{params[:offer_id]}").first.recipient
    flush_used_offers #flush early flush often - help prevent multiple instances from confilcting for fraud and make count more responsive upon refresh
    respond_to do |format|
      format.js
    end
  end

  # DELETE after determined redundant. Should be using the same method in AdViewerConcern
  # def flush_used_offers
  #   @current_sponster_user.me_file.flush_used_offers
  #   @current_sponster_user.me_file.offers.reload
  # end

  def update_split_amount
    Rails.logger.info "update_split_amount :: split_amount=#{params[:split_amount]}"
    @current_sponster_user.me_file.update(split_amount: params[:split_amount].to_i)
  end

  def quick_give
    respond_to do |format|
      format.js
    end
  end

  private
  def get_sponster_user
    sponster_token = params[:sponster_token] || cookies[:sponster_token]
    if sponster_token
      @current_sponster_user = MeFile.find_by(sponster_token: sponster_token).try(:user)
      @split_amount = @current_sponster_user.me_file.split_amount
    end
  end

  def get_recipient_info
    split_code = params[:split_code] || cookies[:split_code]
    cookies[:split_code] = { value: params[:split_code], domain: cookie_domain, same_site: "None", secure: :true } if params[:split_code]
    @this_recipient = Recipient.find_by(split_code: split_code) if split_code.present?
  end

  def set_click_or_tap_string
    @clickTap = (browser.mobile? || browser.tablet?) ? 'Tap' : 'Click'
  end

  def log_widget_serve

    new_log = SponsterWidgetServeLog.new

    if @current_sponster_user
      new_log.user_id = @current_sponster_user.id
      new_log.username = @current_sponster_user.username
      new_log.user_email = @current_sponster_user.email
      new_log.offers_count = @current_sponster_user.me_file.current_offers.count
      new_log.offers_amount = @current_sponster_user.me_file.current_offers.sum(:offer_amt).round(2)
    end
    if @this_recipient
      new_log.recipient_id = @this_recipient.id
      new_log.recipient_split_code = @this_recipient.split_code
      new_log.recipient_referral_code = @this_recipient.referral_code
    end
    new_log.host_page_url = params[:host_url]
    new_log.ip_address = request.remote_ip
    new_log.browser = browser.meta
    new_log.device = browser.device.instance_variable_get("@ua")
    new_log.platform = browser.platform

    if new_log.save
      Rails.logger.info "****SPONSTER WIDGET SERVED**** :: #{new_log.inspect}"
    else
      Rails.logger.info "****SPONSTER WIDGET SERVED**** :: ERROR :: #{new_log.errors.inspect}"
    end
  end
end
