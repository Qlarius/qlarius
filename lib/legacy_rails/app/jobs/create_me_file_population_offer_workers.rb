class CreateMeFilePopulationOfferWorkers < ApplicationJob

  def perform
    job_time = Time.now
    Rails.logger.info "Starting CreateMeFilePopulationOfferWorkers at #{job_time}"
    
    last_ran = WorkerJobLog.find_or_create_by(job_name: 'CreateMeFilePopulationOfferWorkers', job_key:'last_ran')
    
    # Fix: Handle nil job_value case first and provide default
    since_date = if last_ran.job_value.present?
                   DateTime.parse(last_ran.job_value) 
                 else
                   1.year.ago
                 end

    Rails.logger.info "Processing MeFiles since: #{since_date}"
    
    me_file_ids = MeFileTag.where('added_date >= ?', since_date).pluck(:me_file_id).uniq
    Rails.logger.info "Found #{me_file_ids.count} MeFiles to process"

    me_file_ids.each do |me_file_id|
      Rails.logger.info "Queueing AddMeFileToActivePopulations job for MeFile ID: #{me_file_id}"
      AddMeFileToActivePopulations.perform_later(me_file_id)
    end

    # Convert Time to string for storage
    last_ran.update(job_value: job_time.to_s)
    Rails.logger.info "Completed CreateMeFilePopulationOfferWorkers at #{Time.now}"
  end
  
end
 

