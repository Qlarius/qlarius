class Referral < ApplicationRecord
  belongs_to :me_file
  belongs_to :recipient
  has_many :referral_clicks
  belongs_to :referred_me_file, class_name: 'MeFile', foreign_key: :referred_me_file_id
end
