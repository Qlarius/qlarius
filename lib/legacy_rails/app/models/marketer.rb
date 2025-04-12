class Marketer < ApplicationRecord
  has_many :targets
  has_many :users, through: :marketer_users
  has_many :campaigns
  has_many :trait_groups
  has_many :media_pieces
  has_many :media_sequences
  has_many :media_runs
end
