class TipJarExtScriptController < ApplicationController

  # skip_before_action :authenticate_user!
  protect_from_forgery except: :show
  layout false

  def show
    @script_host = if request.host.include?('herokuapp') || ['youdata.qlarius.com', 'sponster.qlarius.com', 'secure.qlarius.com'].include?(request.host)
      request.protocol + request.host
    elsif request.host.include?('localhost')
      'http://localhost:3000'
    elsif Rails.env.production?
      'https://secure.qlarius.com'
    else
      ''
    end
    respond_to do |format|
      format.js
    end
  end

  def update_split_amount
    @current_me_file.update(split_amount: params[:split_amount])
    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(
            "autosplit_settings",
            partial: "ad_viewer_ext/autosplit_settings"
          ),
          turbo_stream.replace(
            "autosplit_settings_tab_amount",
            partial: "ad_viewer_ext/autosplit_settings_tab_amount"
          )
        ]
      end
    end
  end

end
