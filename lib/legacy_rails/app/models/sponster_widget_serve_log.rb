class SponsterWidgetServeLog < ApplicationRecord
  belongs_to :user
  belongs_to :recipient, optional: true
end
