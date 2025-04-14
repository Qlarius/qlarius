class Survey < ApplicationRecord
  include Cacheable
  belongs_to :survey_category
  has_many :survey_question_surveys, -> { order(:display_order) }, dependent: :destroy
  has_many :survey_questions, through: :survey_question_surveys

  scope :active, -> { where(active: true) }

  default_scope -> { order(:display_order) }

  def surveys_with_shared_questions
    survey_id_array = []
    survey_questions.each do |sq|
      sq.survey_inclusion_array.each do |sid|
        survey_id_array << sid
      end
    end
    survey_id_array = survey_id_array.uniq
    Rails.logger.info "***** surveys_with_shared_questions survey_id_array = " + survey_id_array.to_s
    survey_id_array
  end

  def restripe_sq_display_order
    self.survey_question_surveys.each_with_index do |sqs, index|
      Rails.logger.info "restripe_sq_display_order :: survey = #{self.name} :: sq = #{sqs.survey_question.text} :: old_do = #{sqs.display_order} :: new_do = #{index+1}"
      sqs.update(display_order: index+1)
    end 
  end

  class << self
    def active_question_counts
      cache_key = ENV['SURVEY_QUESTION_COUNTS_KEY']
      active_question_counts = self.get_cache(cache_key)
      return active_question_counts if active_question_counts.present?
      active_question_counts = SurveyQuestion.joins(:surveys).where(surveys: {active: true}).group("surveys.id").order("surveys.id").count.stringify_keys
      set_cache(cache_key, active_question_counts, ENV['SURVEY_QUESTION_COUNTS_EXPIRED_SECONDS'])
      active_question_counts
    end

    def question_trait_ids
      cache_key = ENV['SURVEY_QUESTION_TRAIT_IDS_KEY']
      trait_ids = self.get_cache(cache_key)
      return trait_ids if trait_ids.present?
      trait_ids = SurveyQuestion.joins(:surveys).where(surveys: {active: true}).group('surveys.id').order('surveys.id').pluck("surveys.id, ARRAY_AGG(survey_questions.trait_id)").inject({}) do |acc, data|
        acc[data[0].to_s] = data[1]
        acc
      end
      set_cache(cache_key, trait_ids, ENV['SURVEY_QUESTION_TRAIT_IDS_EXPIRED_SECONDS'])
      trait_ids
    end

  end
end
