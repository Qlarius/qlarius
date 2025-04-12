class SurveyQuestionSurvey < ApplicationRecord
  belongs_to :survey
  belongs_to :survey_question
end
