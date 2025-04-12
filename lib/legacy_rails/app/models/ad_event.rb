class AdEvent < ApplicationRecord

  # NOTE - OPTIONALS ARE TEMPORARY TO TO ADD matching_tags_snapshot - REMOVE OPTIONALS WHEN COMPLETED

  has_one :ledger_entry
  belongs_to :campaign, optional: true
  belongs_to :me_file, optional: true
  belongs_to :media_run, optional: true
  belongs_to :media_piece, optional: true
  belongs_to :media_piece_phase, optional: true
  belongs_to :offer, optional: true
  belongs_to :recipient, optional: true
  belongs_to :target_band, optional: true
  belongs_to :referral_credit, optional: true

  def is_media_run_complete?
    complete_offer_count = AdEvent.where(campaign_id: campaign_id, media_run_id: media_run_id, me_file_id: me_file_id).order(:id).inject(0) do |acc, ad_event|
      acc += 1 if ad_event.is_offer_complete
      acc
    end
    complete_offer_count >= media_run.frequency
  end

  def related_ad_events_summary
    ad_events_collection = AdEvent.where(offer_id: offer_id)
    completed_status = ad_events_collection.where(is_offer_complete: true).exists?
    collected_amount = 0.00
    given_amount = 0.00
    # ad_events_array = ad_events.reload.where("offer_id = #{offer_id} and created_at >= '#{10.minutes.ago.to_s(:db)}'")
    ad_events_collection.collect { |ae| collected_amount += ae.event_me_file_collect_amt.to_f }
    ad_events_collection.collect { |ae| given_amount += ae.event_recipient_collect_amt.to_f }
    { completed_status: completed_status, collected_amount: collected_amount, given_amount: given_amount }
  end

end
