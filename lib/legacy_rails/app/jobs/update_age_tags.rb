class UpdateAgeTags < ApplicationJob

  def perform
    ActiveRecord::Base.transaction do
      # update people born on todays date (and yesterdays just in case of funkyness with timezone/timechange)
      today = Date.today

      # todo: account for leap years
      last_ran = Date.parse(WorkerJobLog.find_or_create_by(job_name: 'UpdateAgeTags', job_key: 'last_ran').job_value)
      last_ran = 1.year.ago if last_ran.nil?

      (today - last_ran).to_i.times do |days_ago|
        update_ages(today - days_ago.days)
      end
      
      # update ages of those born on leap day
      update_ages(1.day.ago) if (today.day == 1 and today.month == 3)

      WorkerJobLog.find_or_create_by(job_name: 'UpdateAgeTags', job_key: 'last_ran').update(job_value: today)
    end
  rescue ActiveRecord::RecordNotUnique => e
    # Log the error and possibly retry or skip
    Rails.logger.error "Duplicate record found: #{e.message}"
    # Decide if you want to retry the job or mark it as complete
  end

  private
  def update_ages(date)
    MeFile.where(
      'extract(month from date_of_birth) = ? and extract(day from date_of_birth) = ?',
      date.month, date.day
    ).order(:id).find_in_batches(batch_size: 100) do |batch|
      batch.each do |me_file|
        begin
          ActiveRecord::Base.transaction do
            # Instead of trying to create with a specific ID, let the database auto-increment
            me_file.update_age_tag
          end
        rescue ActiveRecord::RecordNotUnique => e
          # Log the error but continue processing other records
          Rails.logger.error "Duplicate tag found for MeFile #{me_file.id}: #{e.message}"
          next
        end
      end
    end
  end

end
