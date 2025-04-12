class PopulateInitialTargetPopulation < ApplicationJob

  def perform(target_id)
    Rails.logger.info '***** PopulateInitialTargetPopulation *****'

    target = Target.find(target_id)
    target.clear_population
    target.create_population
  end
end
