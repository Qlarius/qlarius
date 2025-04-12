class LedgerEntry < ApplicationRecord
  belongs_to :ledger_header
  belongs_to :ad_event, optional: true
  has_many :referral_ad_events, class_name: 'AdEvent', foreign_key: :referrer_ledger_entry_id
  has_one :referral_credit
end
