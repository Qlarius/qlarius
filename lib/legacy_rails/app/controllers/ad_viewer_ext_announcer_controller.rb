class AdViewerExtAnnouncerController < ApplicationController

  # skip_before_action :authenticate_user!
  layout 'tipjar_ext'

  before_action :authorize!, :allow_iframe

  content_security_policy do |f|
    f.frame_ancestors "*"
  end

  def index
    # @current_sponster_user = MeFile.where("sponster_token = '#{cookies[:sponster_token]}'").first.try(:user)
    split_code = params[:split_code] || cookies[:split_code]
    cookies[:split_code] = { value: params[:split_code], domain: cookie_domain, same_site: "None", secure: :true  } if params[:split_code]
    @this_recipient = Recipient.find_by(split_code: split_code) if split_code.present?
  end

  private

  def allow_iframe
    response.headers.except! 'X-Frame-Options'
    response.headers['Content-Security-Policy'] = "frame-ancestors *;"
  end

end
