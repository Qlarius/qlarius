class SurveyQuestion < ApplicationRecord
  belongs_to :trait
  has_many :survey_answers, dependent: :destroy
  has_many :survey_question_surveys
  has_many :surveys, through: :survey_question_surveys

  def survey_question_type
    trait.input_type
  end

  def survey_inclusion_array
    # in which surveys is this question included?
    surveys.select(is_active: true).pluck(:id)
  end

end
