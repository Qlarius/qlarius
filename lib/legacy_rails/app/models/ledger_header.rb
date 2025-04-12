class LedgerHeader < ApplicationRecord
  after_initialize :set_defaults, unless: :persisted?

  belongs_to :me_file, optional: true
  belongs_to :campaign, optional: true
  belongs_to :recipient, optional: true

  has_many :ledger_entries, -> { order(id: :desc) }

  def write_to_me_file_ledger_from_ad_event(ad_event)
    ledger_entry = ledger_entries.new(
      ad_event_id:              ad_event.id,
      amt:                      ad_event.event_me_file_collect_amt,
      description:              ad_event.media_piece_phase.desc + " - " + ad_event.campaign.marketer.business_name.upcase,
      is_payable:               ad_event.is_payable,
      running_balance:          balance + ad_event.event_me_file_collect_amt,
      running_balance_payable:  (ad_event.is_payable ? balance_payable + ad_event.event_me_file_collect_amt : balance_payable)
    )
    if ledger_entry.save
      self.balance += ledger_entry.amt
      self.balance_payable += ledger_entry.amt if ledger_entry.is_payable
      self.save
    end
  end

  def write_to_campaign_ledger_from_ad_event(ad_event)
    ledger_entry = ledger_entries.new(
      ad_event_id:              ad_event.id,
      amt:                      ad_event.event_marketer_cost_amt,
      description:              ad_event.media_piece_phase.desc,
      running_balance:          balance - ad_event.event_marketer_cost_amt
    )
    if ledger_entry.save
      self.balance -= ledger_entry.amt
      self.save
    end
  end

  def write_to_recipient_ledger_from_ad_event(ad_event)
    if ad_event.event_recipient_collect_amt.to_f > 0.00
      ledger_entry = ledger_entries.new(
        ad_event_id:              ad_event.id,
        amt:                      ad_event.event_recipient_collect_amt,
        description:              ad_event.media_piece_phase.desc + " - MeFile Share",
        running_balance:          balance + ad_event.event_recipient_collect_amt
      )
      if ledger_entry.save
        self.balance += ledger_entry.amt
        self.save
      end
    end

    if ad_event.event_sponster_to_recipient_amt.to_f > 0.00
      ledger_entry = ledger_entries.new(
        ad_event_id:              ad_event.id,
        amt:                      ad_event.event_sponster_to_recipient_amt,
        description:              ad_event.media_piece_phase.desc + " - Sponster Share",
        running_balance:          balance + ad_event.event_sponster_to_recipient_amt
      )
      if ledger_entry.save
        self.balance += ledger_entry.amt
        self.save
      end
    end
  end

  def write_to_me_file_ledger_from_referrals(referrals, ad_events)
    Rails.logger.info "******** ad_events.blank? = " + ad_events.blank?.to_s
    return if ad_events.blank?
    ledger_entry_amt = ad_events.count * 0.01
    Rails.logger.info "******** ledger_entry_amt = " + ledger_entry_amt.to_s
    ledger_entry = ledger_entries.new(
      amt:                      ledger_entry_amt,
      description:              "Referral payment - #{referrals.count} referrals - #{ad_events.count} ads",
      is_payable:               false,
      running_balance:          balance + ledger_entry_amt,
      running_balance_payable:  balance_payable
    )
    if ledger_entry.save
      Rails.logger.info "******** ledger_entry.save = true"
      self.balance += ledger_entry.amt
      self.save
      me_file.referral_credits.create(
        credit_amt:   ad_events.count,
        ad_events:    ad_events,
        ledger_entry: ledger_entry
      )
      referral_ad_pay_limit = GlobalVariable.find_by(name: 'REFERRAL_AD_PAY_LIMIT').value.to_i
      referrals.each do |referral|
        if referral.referred_me_file.ad_unit_complete_referrer_paid_count >= referral_ad_pay_limit
          referral.update(:is_fulfilled, true)
        end
      end
    else
      Rails.logger.info "******** ledger_entry.save FAIL"
      Rails.logger.info "******** ledger_entry.errors.inspect = " + ledger_entry.errors.inspect
    end
  end

  def set_defaults
    self.balance ||= 0.00
    self.balance_payable ||= 0.00
  end
end
