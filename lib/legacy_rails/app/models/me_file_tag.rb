class MeFileTag < ApplicationRecord
  belongs_to :me_file
  belongs_to :trait
  after_save :update_customized_hash

  serialize :customized_hash, Hash

  def tag_with_full_data
    return customized_hash if customized_hash.present?
    if trait.parent_trait.present?
      trait_holder = trait.parent_trait
      tag_value_holder = trait.trait_name
    else
      trait_holder = trait
      tag_value_holder = tag_value
    end

    data = {
      tag_id:               id,
      tag_value:            tag_value_holder,
      trait_id:             trait_holder.id,
      trait_name:           trait_holder.trait_name,
      trait_category_id:    trait_holder.trait_category_id,
      trait_display_order:  trait_holder.display_order
    }
    self.update_columns(customized_hash: data)
    data
  end

  private
  def update_customized_hash
    self.update_columns(customized_hash: tag_with_full_data)
  end
end
