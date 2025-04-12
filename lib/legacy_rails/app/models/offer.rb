class Offer < ApplicationRecord

  # NOTE - OPTIONALS ARE TEMPORARY TO TO ADD matching_tags_snapshot - REMOVE OPTIONALS WHEN COMPLETED

  belongs_to :campaign, required: true
  belongs_to :me_file, required: true
  belongs_to :media_run, required: true
  belongs_to :media_piece, required: true
  belongs_to :target_band, required: true
  has_many :ad_events

  def phase_1_offer_amt
    media_piece.media_piece_type.media_piece_phases.where(phase: 1).first.pay_to_me_file_fixed rescue 0
  end

  def phase_2_offer_amt
    offer_amt - phase_1_offer_amt
  end

  def completed_offer_count
    AdEvent.where(me_file_id: me_file_id, campaign_id: campaign_id, media_run_id: media_run_id, is_offer_complete: true).count
  end

  def is_geo?
    target_band.is_geo?
  end

  def is_me_file_in_target_band?
    target_band.does_include_me_file_live(me_file)
  end

  def offer_status
    #NOTE doesn't work is offer is already flushed by me_file flush_used_offers - use me_file.offer_status instead
    completed_status = ad_events.where(is_offer_complete: true).exists?
    collected_amount = 0.00
    given_amount = 0.00
    # ad_events_array = ad_events.reload.where("offer_id = #{offer_id} and created_at >= '#{10.minutes.ago.to_s(:db)}'")
    ad_events.where("created_at >= '#{10.minutes.ago.to_fs(:db)}'").collect { |ae| collected_amount += ae.event_me_file_collect_amt.to_f }
    ad_events.where("created_at >= '#{10.minutes.ago.to_fs(:db)}'").collect { |ae| given_amount += ae.event_recipient_collect_amt.to_f }
    offer_count = me_file.current_offers.count-1 #subtract 1 because this offer still exists and shows as current but has not been flushed yet
    ledger_balance = me_file.ledger_header.balance
    { completed_status: completed_status, collected_amount: collected_amount, given_amount: given_amount }
  end

end
