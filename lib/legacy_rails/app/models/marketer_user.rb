class MarketerUser < ApplicationRecord
  belongs_to :user
  belongs_to :marketer
end
