class Api::V1::StatsController < ApplicationController

  before_action :authorize!

  def user_stats
    Rails.logger.info "##### @current_me_file = " + @current_me_file.inspect
    if @current_me_file
      return_object = @current_me_file.account_stats
      return_object.merge!(:response_code => status)
      Rails.logger.info "##### return_object = " + return_object.to_s
      render json: return_object
    else
      Rails.logger.info "##### SHOULD RETURN ERROR OBJECT"
      render json: {:status => "error", :description =>"no @current_me_file"}
    end
  end
end
