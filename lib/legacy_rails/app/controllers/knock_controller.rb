class KnockController < ApplicationController

  skip_before_action :authorize!

  def index
    cookies[:from_knock] = true
    Rails.logger.info "cookies[:from_knock] = " + cookies[:from_knock].to_s
  end

  def logout
    cookies.delete :psg_auth_token
    reset_session
    #local storage deleted via stimulus controller
    redirect_to root_path
  end

end
