class MeFileBuilderController < ApplicationController
  
  # before_action :authorize!

  def index
    @survey_categories = SurveyCategory.includes(:active_surveys).order(:display_order)
  end

  def open_survey_modal
    puts '*** open_survey_modal'
    @survey = Survey.find(params[:survey_id])
    render partial: "survey_modal"
  end

  def reset_survey_modal
    Rails.logger.info "***** reset_survey_modal"
    #render a blank loading mobile
    render partial: "survey_modal_reset"
  end

  def create_tags
    Rails.logger.info "***** me_file_builder_controller : create_tags"
    if params[:trait_ids].count == 0
      Rails.logger.info "***** me_file_builder_controller : create_tags : NO NEW TAGS"
    else
      Rails.logger.info "***** me_file_builder_controller : tag_ids_array = " + params[:trait_ids].to_s + " base_trait_id = " + params[:survey_question_trait_id] + " survey_id = " + params[:survey_id]
      @current_me_file.create_tags(params[:trait_ids], params[:survey_question_trait_id])
    end
    respond_to do |format|
      format.turbo_stream
      format.html
    end
  end

  def create_tag_from_found_trait_by_text_value
     if params[:value]
        Rails.logger.info "VALUE FOUND = " + params[:value].to_s
        trait_to_add = Trait.where(parent_trait_id: params[:survey_question_trait_id], trait_name: params[:value]).first
        Rails.logger.info "***** trait_to_add = " + trait_to_add.inspect
        @current_me_file.create_tags([trait_to_add.id], params[:survey_question_trait_id])
      else
        Rails.logger.info "no value in params"
      end
      respond_to do |format|
        format.turbo_stream
        format.html
      end
  end

end
