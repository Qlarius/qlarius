require "browser/aliases"

class AdViewerController < ApplicationController
  include AdViewerConcern

  Browser::Base.include(Browser::Aliases)
  before_action :authorize!

  def index
    if @current_user
      @split_amount = @current_me_file.split_amount
      Rails.logger.info "****** ad_viewer_controller index ABOUT TO FLUSH OFFERS"
      flush_used_offers
    end
    log_widget_serve
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

  def reveal_banner
    set_click_or_tap_string
    respond_to do |format|
      format.js
    end
  end

  def banner_impression_collection
    if @current_me_file.offers.find_by(id: params[:offer_id]).blank?
      @error_message = "ERROR - not current offer"
    else
      result = collect_banner_impression(params[:offer_id], params[:split_code], @this_recipient, request.remote_ip, request.url)
    end
    Rails.logger.info "**** collect_banner_impression result = " + result.to_json
    Rails.logger.info "**** collect_banner_impression @current_me_file.account_stats = " + @current_me_file.account_stats.to_json
    render json: {"offer": Offer.find(params[:offer_id]).offer_status, "me_file": @current_me_file.account_stats }
  end

  def ad_jump_collection
    Rails.logger.info "************ ad_jump_collection - offer_id =  " + params[:offer_id].to_s + cookies[:split_code] + request.remote_ip.to_s +  request.original_url.to_s
    split_code = cookies[:split_code]
    result = collect_ad_jump(params[:offer_id], params[:split_code], request.remote_ip, request.original_url)
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

  def update_split_amount
    Rails.logger.info "update_split_amount :: split_amount=#{params[:split_amount]}"
    @current_me_file.update(split_amount: params[:split_amount].to_i)
  end

  def quick_give
    respond_to do |format|
      format.js
    end
  end
end

