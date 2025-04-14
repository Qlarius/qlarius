class ReferralCredit < ApplicationRecord
  belongs_to :ledger_entry
  belongs_to :me_file
  has_many :ad_events
end
