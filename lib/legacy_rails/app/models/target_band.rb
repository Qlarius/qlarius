class TargetBand < ApplicationRecord

  require 'json'

  belongs_to :target
  has_many :target_band_trait_groups, dependent: :destroy
  has_many :trait_groups, through: :target_band_trait_groups
  has_many :target_populations, dependent: :destroy
  has_many :me_files, through: :target_populations
  has_many :bids
  has_many :offers
  has_many :ad_events

  def matching_me_file_ids
    TargetBand.joins(trait_groups: [traits: :me_file_tags]).where(id: id).group("trait_groups.id").pluck(Arel.sql("ARRAY_AGG(DISTINCT me_file_tags.me_file_id)")).inject(:&).to_a
  end

  def index_of_band_in_target
    target.target_band_id_array.index(id)
  end

  def unique_me_file_match_count
    target.target_band_unique_me_file_counts_array[index_of_band_in_target]
  end

  def does_include_me_file_live(me_file_id)
    MeFileTag.joins(trait: {trait_groups: :target_bands}).where(target_bands: {id: id}).where(me_file_id: me_file_id).group("trait_groups.id").pluck("trait_groups.id").count == trait_groups.count
  end

  def minimum_bid_amount
    0.10 - (index_of_band_in_target - (target.target_bands.count - 1)) / 100.00
  end

  def is_geo?
    is_geo = false
    trait_groups.each do |tg|
      is_geo ||=  tg.is_geo?
    end
    is_geo
  end

  def me_file_matching_traits(me_file_id)
    band_trait_ids = []
    Rails.logger.info trait_groups.count
    trait_groups.each do |tg|
      Rails.logger.info tg.traits.count
      band_trait_ids.concat(tg.traits.order(:id).pluck(:id))
    end
    Rails.logger.info band_trait_ids
    me_file_trait_ids = MeFile.find(me_file_id).me_file_tags.order(:trait_id).pluck(:trait_id)
    Rails.logger.info me_file_trait_ids.count
    Rails.logger.info me_file_trait_ids
    matched_trait_ids = me_file_trait_ids & band_trait_ids
    Rails.logger.info matched_trait_ids
    matching_trait_snapshot = []
    matched_trait_ids.each do |tid|
      t = Trait.find(tid)
      matching_trait_snapshot << {trait_name: t.parent_trait.trait_name, tag_value: t.trait_name}
    end
    Rails.logger.info matching_trait_snapshot
    return matching_trait_snapshot
  end

end
