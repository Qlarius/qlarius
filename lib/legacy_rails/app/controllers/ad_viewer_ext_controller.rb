require "browser/aliases"

class AdViewerExtController < ApplicationController
  include AdViewerConcern

  layout 'tipjar_ext'
 
  Browser::Base.include(Browser::Aliases)
  before_action :authorize!, :allow_iframe, :get_recipient_info

  content_security_policy do |f|
    f.frame_ancestors "*"
  end

  def index
    if @current_user
      @split_amount = @current_me_file.split_amount
      Rails.logger.info "****** ad_viewer_controller index ABOUT TO FLUSH OFFERS"
      flush_used_offers
      # set_click_or_tap_string
    end
    log_widget_serve
  end

  def update_split_amount
    Rails.logger.info "update_split_amount :: split_amount=#{params[:split_amount]}"
    @current_me_file.update(split_amount: params[:split_amount].to_i)
  end

  # def refresh_offers
  #   flush_used_offers
  #   set_click_or_tap_string
  #   get_sponster_user
  #   get_recipient_info
  #   Rails.logger.info "************ Refresh split info: " + @this_recipient.split_code + ":" + @this_recipient.id.to_s + ":" + @split_amount.to_s
  #   respond_to do |format|
  #     format.js
  #   end
  # end

  def refresh_offer_counts
    respond_to do |format|
      format.js
    end
  end

  # def reveal_banner
  #   set_click_or_tap_string
  #   respond_to do |format|
  #     format.js
  #   end
  # end

  def collect_banner_impression
    if @current_me_file.offers.find_by(id: params[:offer_id]).blank?
      @error_message = "ERROR - not current offer"
    else
      result = collect_banner_impression(params[:offer_id], params[:split_code], @this_recipient, request.remote_ip, request.url) #collect_banner_impression is defined in AdViewerConcern
    end
    Rails.logger.info "**** collect_banner_impression result = " + result.to_json
    Rails.logger.info "**** collect_banner_impression @current_me_file.account_stats = " + @current_me_file.account_stats.to_json
    render json: {"offer": Offer.find(params[:offer_id]).offer_status, "me_file": @current_me_file.account_stats }
  end

  def collect_ad_jump
    Rails.logger.info params[:offer_id]
    Rails.logger.info cookies[:split_code]
    Rails.logger.info request.remote_ip.to_s
    Rails.logger.info request.original_url.to_s
    Rails.logger.info "*********** ad_jump_collection - offer_id =  " + params[:offer_id].to_s + cookies[:split_code] + request.remote_ip.to_s +  request.original_url.to_s
    result = collect_ad_jump(params[:offer_id], params[:split_code], request.remote_ip, request.original_url) #collect_ad_jump is defined in AdViewerConcern 
    Rails.logger.info "**** ad_jump_collection result = " + result.inspect
    Rails.logger.info "**** ad_jump_collection @current_me_file.account_stats = " + @current_me_file.account_stats.to_json
    render json: {"offer": @current_me_file.offer_status_by_ad_events(params[:offer_id]), "me_file": @current_me_file.account_stats }
  end

  # def close_offer
  #   collected = @current_user.me_file.close_offer(params[:offer_id])
  #   @this_recipient ||= @current_user.me_file.ad_events.reload.where("offer_id=#{params[:offer_id]}").first.recipient
  #   flush_used_offers #flush early flush often - help prevent multiple instances from confilcting for fraud and make count more responsive upon refresh
  #   respond_to do |format|
  #     format.js
  #   end
  # end

  # def update_split_amount
  #   Rails.logger.info "update_split_amount :: split_amount=#{params[:split_amount]}"
  #   @current_me_file.update(split_amount: params[:split_amount].to_i)
  # end

  def save_split_amount
    Rails.logger.info "update_split_amount :: split_amount = " + params[:split_amount]
    if @current_me_file.update(split_amount: params[:split_amount])
      render json: { status: "success", split_amount: @current_me_file.split_amount }, status: :ok
    else
      render json: { status: "error", errors: @current_me_file.errors.full_messages }, status: :unprocessable_entity
    end
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
      @current_user = MeFile.find_by(sponster_token: sponster_token).try(:user)
      @split_amount = @current_me_file.split_amount
    end
  end

  def get_recipient_info
    split_code = params[:split_code] || cookies[:split_code]
    cookies[:split_code] = { value: params[:split_code], domain: cookie_domain, same_site: "None", secure: :true } if params[:split_code]
    @this_recipient = Recipient.find_by(split_code: split_code) if split_code.present?
  end
# DELETE after determined redundant. Should be using the same method in AdViewerConcern
  # def flush_used_offers
  #   @current_me_file.flush_used_offers
  #   @current_me_file.offers.reload
  # end

  def set_click_or_tap_string
    @clickTap = (browser.mobile? || browser.tablet?) ? 'Tap' : 'Click'
  end

  def log_widget_serve

    new_log = SponsterWidgetServeLog.new

    if @current_user
      new_log.user_id = @current_user.id
      new_log.username = @current_user.username
      new_log.user_email = @current_user.email
      new_log.offers_count = @current_me_file.current_offers.count
      new_log.offers_amount = @current_me_file.current_offers.sum(:offer_amt).round(2)
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

  def allow_iframe
    response.headers.except! 'X-Frame-Options'
    response.headers['Content-Security-Policy'] = "frame-ancestors *;"
  end

end
