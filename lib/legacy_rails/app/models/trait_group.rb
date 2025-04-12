class TraitGroup < ApplicationRecord
  belongs_to :marketer
  has_many :target_band_trait_groups
  has_many :target_bands, through: :target_band_trait_groups
  has_many :trait_group_traits, dependent: :destroy
  has_many :traits, through: :trait_group_traits
  belongs_to :trait, foreign_key: :parent_trait_id  

  def matching_me_file_ids
    MeFileTag.joins(trait: [trait_group_traits: :trait_group]).references(:traits, :trait_groups).where(trait_groups: { id: id }).pluck(:me_file_id).uniq
  end

  def is_geo?
    parent_trait_name = traits.present? ? traits.first.parent_trait.trait_name : "nada"
    parent_trait_name.downcase.include?("zip code")
  end

  def trait_list_string
    traits.pluck(:trait_name).join(", ")
  end 

  def self.grouped_me_file_counts(marketer_id)
    self.includes(traits: :me_file_tags).where(deactivated_at: nil).where(marketer_id: marketer_id).group("trait_groups.id").count("DISTINCT me_file_tags.me_file_id")
  end

  def self.grouped_target_band_counts(marketer_id)
    self.includes(:target_bands).group("trait_groups.id").where(marketer_id: marketer_id).count("target_bands.id")
  end
end
