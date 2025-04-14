class Target < ApplicationRecord
  belongs_to :marketer
  has_many :target_bands, dependent: :destroy
  has_many :campaigns

  def bullseye_band
    target_bands.where(is_bullseye: true).first
  end

  def unused_trait_groups
    marketer.try(:trait_groups).try(:all).to_a - bullseye_band.try(:trait_groups).to_a
  end

  def target_band_id_array
    target_bands.order(:id).pluck(:id)
  end

  def target_band_unique_me_file_counts_array
    count_array = [target_bands.first.matching_me_file_ids.count]
    (1..target_bands.count-1).each do |i|
      count_total = count_array.inject(:+)
      count_array << (target_bands[i].matching_me_file_ids.count - count_total)
    end
    count_array
  end

  def create_population
    new_target_populations = []
    target_population_me_file_ids = []
    target_bands.order(:id).each do |target_band|
      matching_me_file_ids = target_band.matching_me_file_ids - target_population_me_file_ids
      matching_me_file_ids.each do |me_file_id|
        new_target_populations << { target_band_id: target_band.id, me_file_id: me_file_id }
      end
      target_population_me_file_ids += matching_me_file_ids
    end
    TargetPopulation.create(new_target_populations) if new_target_populations.present?
  end

  def clear_population
    TargetPopulation.joins(:target_band).references(:target_bands).where(target_bands: {target_id: id}).delete_all
  end

  def optimal_band_for_me_file(me_file_id)
    target_bands.order(:id).each do |target_band|
      return target_band if target_band.does_include_me_file_live(me_file_id)
    end
    nil
  end

  def current_total_population_count
    TargetPopulation.where(target_band_id: target_bands.pluck(:id)).count
  end

  def is_populated?
    current_total_population_count > 0
  end
end
