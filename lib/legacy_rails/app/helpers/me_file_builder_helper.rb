module MeFileBuilderHelper

  def survey_completion_label_info(survey)
    sq_answered = @current_me_file.answered_survey_question_count(survey)
    sq_count = Survey.active_question_counts[survey.id.to_s].to_i
    label_class = if sq_answered == sq_count
      "badge bg-success"
    elsif sq_answered == 0
      "badge bg-danger"
    else
      "badge bg-warning"
    end
    return [sq_answered, sq_count, label_class]
  end

  def survey_category_percentage_complete(survey_category)
    numerator = 0
    denominator = SurveyCategory.active_question_counts[survey_category.id.to_s].to_i
    survey_category.active_surveys.each do |s|
      survey_completion_array = survey_completion_label_info(s)
      numerator += survey_completion_array[0]
    end

    progress_class = if numerator < denominator
      "bg-warning"
    elsif numerator == 0
      "bg-danger"
    else
      "bg-success"
    end

    return [((numerator*1.00)/(denominator*1.00)*100), progress_class, numerator, denominator]
  end

  def action_based_on_question_type(survey_question_type)
    Rails.logger.info "***** me_file_builder_helper : action_based_on_question_type"
    case survey_question_type
    when "FreeText"
      create_tag_with_value_surveys_path
    when "single_select_from_text"
      create_tag_from_found_trait_by_text_value_surveys_path
    else
      create_tags_surveys_path
    end
  end

end
