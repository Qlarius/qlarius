require 'clockwork'
require_relative './boot'
require_relative './environment'

module Clockwork
  every(5.minutes, 'ActivateUnthrottledOffersPastPendingUntil') { ActivateUnthrottledOffersPastPendingUntil.perform_later }
  every(10.minutes, 'CreateMeFilePopulationOfferWorkers') { CreateMeFilePopulationOfferWorkers.perform_later }
  every(10.minutes, 'CreateThrottledOfferWorkers') { CreateThrottledOfferWorkers.perform_later }
  every(1.day, 'UpdateAgeTags') { UpdateAgeTags.perform_later }
  # every(1.day, 'CreateEmailOfferNotificationWorkers', :at => '09:00') { CreateEmailOfferNotificationWorkers.perform_later }
  # every(1.day, 'CreateSmsOfferNotificationWorkers', :at => '11:00') { CreateSmsOfferNotificationWorkers.perform_later}
end
