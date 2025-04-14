class Trait < ApplicationRecord
  has_many :me_file_tags
  has_many :me_files, through: :me_file_tags
  has_many :trait_group_traits, dependent: :destroy
  has_many :trait_groups, through: :trait_group_traits

  has_many :child_traits, -> { order(:display_order) }, class_name: "Trait", foreign_key: :parent_trait_id

  belongs_to :parent_trait, class_name: "Trait", foreign_key: :parent_trait_id, optional: true  #if no parent_trait_d, this is a parent_trait
  belongs_to :trait_category, foreign_key: :trait_category_id

  has_one :survey_question
  has_one :survey_answer

  def is_geo?
    # move to model schema eventually - for now, anything using zip code
    ((parent_trait) && (parent_trait.trait_name.downcase.include? "zip code")) || (trait_name.downcase.include? "zip code")
  end


  def self.aggregated_names_group_by_trait_group_id(marketer_id)
    self.includes(:trait_groups).where(trait_groups: {marketer_id: marketer_id, deactivated_at: nil}).group("trait_groups.id").pluck("trait_groups.id, STRING_AGG(trait_name, ',')").inject({}) do |acc, group_id_and_aggregated_name|
      acc[group_id_and_aggregated_name[0]] = group_id_and_aggregated_name[1]
      acc
    end
  end
end
