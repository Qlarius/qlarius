class SurveyModalController < ApplicationController
  
  # before_action :authorize!
  # before_action :get_current_user

  def index
    @survey = Survey.find(params[:survey_id])
  end

end
