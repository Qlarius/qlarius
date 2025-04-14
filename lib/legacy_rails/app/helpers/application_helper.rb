require "browser/aliases"

module ApplicationHelper

  def is_tag_editable? (trait_name = "")
    ["Sex", "Gender", "Birthdate", "Age"].exclude? trait_name
  end

  def flash_class(level)
    case level
    when 'notice' then 'alert alert-info alert-dismissible'
    when 'success' then 'alert alert-success alert-dismissible'
    when 'error' then 'alert alert-warning alert-dismissible'
    else
      'alert alert-info alert-dismissible'
    end
  end

  def smart_add_url_protocol(which_url)
    safe_url = which_url
    safe_url = "http://#{which_url}" unless which_url =~ /^https?:\/\//
    return safe_url
  end

  def get_current_marketer
    session[:current_marketer_id] = 1 if session[:current_marketer_id].nil?
    @current_marketer = Marketer.find(session[:current_marketer_id]) rescue Marketer.first
  end

  def smart_add_url_protocol(which_url)
    safe_url = which_url
    safe_url = "http://#{which_url}" unless which_url =~ /^https?:\/\//
    return safe_url
  end

  # FIX THIS!!!!! Not DRY with following method almost a complete duplicate
  def action_based_on_question_type_mfb(survey_question_type)
    Rails.logger.info "***** application_helper : action_based_on_question_type : " + survey_question_type
    case survey_question_type
    when "FreeText"
      me_file_builder_create_tag_with_value_path
    when "single_select_from_text"
      me_file_builder_create_tag_from_found_trait_by_text_value_path
    when "single_select_zip"
      me_file_builder_create_tag_from_found_trait_by_text_value_path
    else
      me_file_builder_create_tags_path
    end
  end
# FIX THIS!!!!! Not DRY with previous method almost a complete duplicate
  def action_based_on_question_type_mfd(survey_question_type)
    Rails.logger.info "***** tag_editor_modal_helper : action_based_on_question_type"
    case survey_question_type
    when "FreeText"
      create_tag_with_value_me_file_tags_path
    when "single_select_from_text"
      create_tag_from_found_trait_by_text_value_me_file_tags_path
    when "single_select_zip"
      create_tag_from_found_trait_by_text_value_me_file_tags_path
    else
      create_tags_me_file_tags_path
    end
  end

  def click_or_tap_string
    (browser.mobile? || browser.tablet?) ? 'Tap' : 'Click'
  end

end