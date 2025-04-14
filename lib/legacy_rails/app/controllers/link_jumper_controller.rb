require "browser/aliases"

class LinkJumperController < ApplicationController
  include AdViewerConcern

  layout "application_blank"

  Browser::Base.include(Browser::Aliases)
  before_action :authorize!

  def index
    Rails.logger.info "************ LinkJumperController index - offer_id: " + params[:offer_id].to_s + " split_code: " + cookies[:split_code] + " ip:" + request.remote_ip.to_s + " url:" + request.original_url
    split_code = cookies[:split_code] if cookies[:split_code]
    offer = @current_me_file.current_offers.where('id = ?', params[:offer_id]).first if params[:offer_id]
    collect_ad_jump(offer.id, split_code, request.remote_ip, request.original_url) unless offer.nil?
  end

end
