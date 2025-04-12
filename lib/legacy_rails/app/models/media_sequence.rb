class MediaSequence < ApplicationRecord
  belongs_to :marketer
  has_many :media_runs
  has_many :campaigns
end
