class MeFileTagsController < ApplicationController

  # before_action :authorize!
  # before_action :get_current_user

  def index
  end

  def open_tag_editor_modal
    puts '*** open_tag_editor_modal'
    @trait_to_edit = Trait.find(params[:trait_id])
    render partial: "tag_editor_modal"
  end

  def create_tags
    sleep 0.5 #slight delay to allow css animation to begin first
    Rails.logger.info "***** me_file_tags_controller : create_tags"
    if params[:trait_ids].count == 0
      Rails.logger.info "***** me_file_tags_controller : create_tags : NO NEW TAGS"
    else
      Rails.logger.info "***** me_file_tags_controller : tag_ids_array = " + params[:trait_ids].to_s + " base_trait_id = " + params[:survey_question_trait_id]
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

  def delete_tags
    Rails.logger.info "***** me_file_tags_controller : delete_tags"
    @current_me_file.clear_tags_for_trait(params[:trait_id].to_i)
    sleep 0.75
    respond_to do |format|
      format.turbo_stream
      format.html
    end
  end

  def open_delete_confirm_modal
    @trait_to_delete = Trait.find(params[:trait_id])
    render partial: "delete_confirm_modal"
  end

end
