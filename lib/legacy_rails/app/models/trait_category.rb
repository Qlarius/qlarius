class TraitCategory < ApplicationRecord
  has_many :traits
  has_many :trait_groups
  has_many :parent_traits, -> { where(parent_trait_id: nil).order(:display_order) }, class_name: 'Trait', foreign_key: :trait_category_id
end
