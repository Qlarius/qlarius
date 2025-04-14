class SurveyCategory < ApplicationRecord
  include Cacheable
  has_many :surveys
  has_many :active_surveys, -> { Survey.active }, class_name: 'Survey'

  class << self
    def active_question_counts
      cache_key = ENV['SURVEY_CATEGORY_QUESTION_COUNTS_KEY']
      active_question_counts = self.get_cache(cache_key)
      return active_question_counts if active_question_counts.present?
      active_question_counts = SurveyQuestion.joins(surveys: :survey_category).where(surveys: {active: true}).group("survey_categories.id").order("survey_categories.id").count.stringify_keys
      set_cache(cache_key, active_question_counts, ENV['SURVEY_CATEGORY_QUESTION_COUNTS_EXPIRED_SECONDS'])
      active_question_counts
    end
  end
end
