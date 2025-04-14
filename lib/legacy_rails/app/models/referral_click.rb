class ReferralClick < ApplicationRecord
  belongs_to :referral
  belongs_to :ad_event
  belongs_to :referral_credit
end
