module AdViewerConcern
  extend ActiveSupport::Concern

  private

  def get_sponster_user
    sponster_token = params[:sponster_token] || cookies[:sponster_token]
    if sponster_token
      @current_user = MeFile.find_by(sponster_token: sponster_token).try(:user)
      @split_amount = @current_me_file.split_amount
    end
  end

  def get_recipient_info
    split_code = params[:split_code] || cookies[:split_code]
    cookies[:split_code] = { value: params[:split_code], domain: cookie_domain, same_site: "None", secure: :true } if params[:split_code]
    @this_recipient = Recipient.find_by(split_code: split_code) if split_code.present?
  end

  def collect_banner_impression(offer_id, split_code, recipient, ip, url)
    offer = Offer.find_by(id: offer_id)
    phase = offer.media_piece.media_piece_type.media_piece_phases.where(phase: 1).first

    offer_attributes = offer.attributes.symbolize_keys.extract!(:campaign_id, :media_run_id, :media_piece_id, :target_band_id, :is_payable, :is_demo, :is_throttled)
    ad_event_attributes = {
      media_piece_phase:  phase,
      offer:              offer,
      offer_bid_amt:      offer.offer_amt,
      matching_tags_snapshot: offer.matching_tags_snapshot,
      ip_address:         ip,
      url:                url,
      event_split_code:   split_code
    }.merge!(offer_attributes)
    ad_event = @current_me_file.ad_events.new(ad_event_attributes)

    if recipient.nil?
      Rails.logger.info "MeFile #{@current_me_file.id} :: recipient :: *** no recipient for this banner collection ***"
      ad_event.event_me_file_collect_amt = phase.pay_to_me_file_fixed #no sharing, keep all for me_file
      ad_event.event_sponster_collect_amt = phase.pay_to_sponster_fixed #no sharing, keep all for sponster
    else
      Rails.logger.info "MeFile #{@current_me_file.id} :: recipient :: *** recipient for this banner collection = #{recipient.name}***"
      ad_event.recipient_id = recipient.id
      ad_event.event_recipient_split_pct = @current_me_file.split_amount #snapshot of split amount at time of collection
      ad_event.event_recipient_collect_amt = ((phase.pay_to_me_file_fixed - 0.005) * (ad_event.event_recipient_split_pct * 0.01)).round(2) #subtract 0.005 to account for rounding errors, calculate recipient's share
      ad_event.event_sponster_collect_amt = (phase.pay_to_sponster_fixed - phase.pay_to_recipient_from_sponster_fixed) #subtract recipient's rev share from sponster's total
      ad_event.event_sponster_to_recipient_amt = phase.pay_to_recipient_from_sponster_fixed #sponster's rev share for recipient after subtracting recipient's rev share
      ad_event.event_me_file_collect_amt = phase.pay_to_me_file_fixed - ad_event.event_recipient_collect_amt #subtract recipient's rev share from me_file's total after share/tipping
    end

    ad_event.offer_marketer_cost_amt = offer.marketer_cost_amt.to_f
    ad_event.event_marketer_cost_amt = ad_event.event_me_file_collect_amt.to_f + ad_event.event_sponster_collect_amt.to_f + ad_event.event_recipient_collect_amt.to_f + ad_event.event_sponster_to_recipient_amt.to_f #total marketer cost is sum of all payouts

    Rails.logger.info ad_event.inspect

    if ad_event.save
      #write to ledgers if save is successful - should this be moved to a worker?
      ad_event.me_file.ledger_header.write_to_me_file_ledger_from_ad_event(ad_event)
      ad_event.campaign.ledger_header.write_to_campaign_ledger_from_ad_event(ad_event)
      ad_event.recipient.ledger_header.write_to_recipient_ledger_from_ad_event(ad_event) if recipient.present?
    else
      Rails.logger.info ad_event.errors.full_messages
    end

    { collected_amount: ad_event.event_me_file_collect_amt, given_amount: ad_event.event_recipient_collect_amt } #return an object with the collected and given amounts
  end

  def close_offer(offer_id)
    collected_amount = 0.00
    given_amount = 0.00
    ad_events = @current_me_file.ad_events.reload.where("offer_id = ? and created_at >= ?", offer_id, 10.minutes.ago)
    ad_events.each do |ae| 
      collected_amount += ae.event_me_file_collect_amt.to_f
      given_amount += ae.event_recipient_collect_amt.to_f
    end
    { collected_amount: collected_amount, given_amount: given_amount }
  end

  def offer_status_by_ad_events(offer_id)
    ad_events_collection = @current_me_file.ad_events.where(offer_id: offer_id)
    completed_status = ad_events_collection.where(is_offer_complete: true).exists?
    collected_amount = 0.00
    given_amount = 0.00
    
    recent_events = ad_events_collection.where("created_at >= ?", 10.minutes.ago)
    recent_events.each do |ae|
      collected_amount += ae.event_me_file_collect_amt.to_f
      given_amount += ae.event_recipient_collect_amt.to_f
    end
    
    { 
      completed_status: completed_status, 
      collected_amount: collected_amount, 
      given_amount: given_amount 
    }
  end

  def collect_ad_jump(offer_id, split_code, ip, url)
    Rails.logger.info "************ collect_ad_jump - offer_id: " + offer_id.to_s + " split_code: " + split_code.to_s + " ip:" + ip.to_s + " url:" + url.to_s
    error_message = ""
    offer = Offer.find(offer_id)
    Rails.logger.info "************ collect_ad_jump - offer: " + offer.inspect

    if offer
      error_message = "This offer/ad is not available for this MeFile." if @current_me_file.id != offer.me_file.id
      phase = offer.media_piece.media_piece_type.media_piece_phases.where(phase: 2).first
      Rails.logger.info "************ collect_ad_jump - phase: " + phase.inspect
      error_message = "ERROR -  phase previously collected" if offer.ad_events.where(media_piece_phase_id: phase).present?
    else
      error_message = "Offer not found."
    end

    if error_message.blank?
      last_phase = offer.media_piece.media_piece_type.media_piece_phases.where(phase: 1).first
      split_code = 'null' == split_code ? nil : split_code
      recipient = Recipient.where(split_code: split_code.to_s).first

      offer_attributes = offer.attributes.symbolize_keys.extract!(:campaign_id, :media_run_id, :media_piece_id, :target_band_id, :is_payable, :is_demo, :is_throttled)
      ad_event_attributes = {
        media_piece_phase:  phase,
        offer:              offer,
        offer_bid_amt:      offer.offer_amt,
        matching_tags_snapshot: offer.matching_tags_snapshot,
        is_offer_complete:  true,
        ip_address:         ip,
        url:                url,
        event_split_code:   split_code
      }.merge!(offer_attributes)
      ad_event = @current_me_file.ad_events.new(ad_event_attributes)

      amt_already_paid_total = last_phase.pay_to_me_file_fixed + last_phase.pay_to_sponster_fixed
      offer_amt_remaining = ad_event.offer_bid_amt - last_phase.pay_to_me_file_fixed

      if recipient.nil?
        ad_event.event_me_file_collect_amt = offer_amt_remaining
        ad_event.event_recipient_collect_amt = 0.00
      else
        ad_event.recipient_id = recipient.id
        ad_event.event_recipient_split_pct = @current_me_file.split_amount
        ad_event.event_recipient_collect_amt = (offer_amt_remaining * (ad_event.event_recipient_split_pct * 0.01)).round(2)
        ad_event.event_me_file_collect_amt = offer_amt_remaining - ad_event.event_recipient_collect_amt
      end

      ad_event.event_sponster_collect_amt = offer.marketer_cost_amt - amt_already_paid_total - ad_event.event_me_file_collect_amt - ad_event.event_recipient_collect_amt
      ad_event.offer_marketer_cost_amt = offer.marketer_cost_amt
      ad_event.event_marketer_cost_amt = ad_event.event_me_file_collect_amt + ad_event.event_sponster_collect_amt + ad_event.event_recipient_collect_amt.to_f

      if ad_event.save
        @current_me_file.ledger_header.write_to_me_file_ledger_from_ad_event(ad_event)
        ad_event.campaign.ledger_header.write_to_campaign_ledger_from_ad_event(ad_event)
        ad_event.recipient.ledger_header.write_to_recipient_ledger_from_ad_event(ad_event) if recipient.present?
      end
    end

    if error_message.blank?
      { collected_amount: ad_event.event_me_file_collect_amt, given_amount: ad_event.event_recipient_collect_amt }
    else
      { error: error_message }
    end
    
    flush_used_offers
  end

  def flush_used_offers
    Rails.logger.info "MeFile #{@current_me_file.id} :: flush_used_offers :: entered"
    offers_to_check = Offer.where(id: AdEvent.where(me_file_id: @current_me_file.id).where(offer_id: @current_me_file.offers.pluck(:id)).pluck(:offer_id))
    
    offers_to_check.each do |offer|
      Rails.logger.info "MeFile #{@current_me_file.id} :: flush_used_offers :: checking offer #{offer.id} from #{offer.campaign ? offer.campaign.marketer.business_name : "unknown"} :: #{offer.campaign ? offer.campaign.title : "unknown"}"
      
      if offer.ad_events.where(is_offer_complete: true).present?
        Rails.logger.info "MeFile #{@current_me_file.id} :: flush_used_offers :: offer #{offer.id} is considered complete"
        create_next_offer_if_needed(offer)
        Rails.logger.info "MeFile #{@current_me_file.id} :: flush_used_offers :: destroying offer #{offer.id}"
        offer.destroy
      else
        handle_incomplete_offer(offer)
      end
    end
  end

  private

  def handle_incomplete_offer(offer)
    Rails.logger.info "MeFile #{@current_me_file.id} :: flush_used_offers :: offer #{offer.id} not completed"
    
    if offer.ad_events.count < offer.media_run.maximum_banner_count
      handle_under_maximum_banner_count(offer)
    elsif offer_reached_completion_phase?(offer)
      handle_completion_phase_reached(offer)
    else
      handle_maximum_banner_count_reached(offer)
    end
  end

  def handle_under_maximum_banner_count(offer)
    Rails.logger.info "MeFile #{@current_me_file.id} :: flush_used_offers :: offer #{offer.id} maximum banner count not exceeded"
    new_pending_until = offer.ad_events.last.created_at + offer.media_run.banner_retry_buffer_hours.hours
    
    if new_pending_until > offer.pending_until
      Rails.logger.info "MeFile #{@current_me_file.id} :: flush_used_offers :: resetting offer banner attempt pending until #{new_pending_until} and making not current"
      offer.update(is_current: false, pending_until: new_pending_until)
    else
      Rails.logger.info "MeFile #{@current_me_file.id} :: flush_used_offers :: leaving offer as is"
    end
  end

  def offer_reached_completion_phase?(offer)
    offer.ad_events.joins(media_piece_phase: :media_piece_type)
         .where('media_piece_phases.phase = media_piece_types.ad_phase_count_to_complete')
         .exists?
  end

  def handle_completion_phase_reached(offer)
    Rails.logger.info "MeFile #{@current_me_file.id} :: flush_used_offers :: offer #{offer.id} has reached completion phase"
    offer.ad_events.last.update(is_offer_complete: true)
    create_next_offer_if_needed(offer)
  end

  def handle_maximum_banner_count_reached(offer)
    Rails.logger.info "MeFile #{@current_me_file.id} :: flush_used_offers :: offer #{offer.id} maximum banner count reached before click through"
    offer.ad_events.last.update(is_offer_complete: true)
    create_next_offer_if_needed(offer)
  end

  def create_next_offer_if_needed(from_which_offer)
    Rails.logger.info "MeFile #{@current_me_file.id} :: create_next_offer_if_needed :: offer:#{from_which_offer.id} - completed_offer_count is #{from_which_offer.completed_offer_count} of frequency #{from_which_offer.media_run.frequency}"
    
    if from_which_offer.completed_offer_count < from_which_offer.media_run.frequency
      Rails.logger.info "MeFile #{@current_me_file.id} :: create_next_offer_if_needed :: creating clone offer for offer #{from_which_offer.id}"
      new_offer = from_which_offer.dup
      new_offer.pending_until = from_which_offer.ad_events.last.created_at + from_which_offer.media_run.frequency_buffer_hours.hours
      new_offer.is_current = 0
      Rails.logger.info "MeFile #{@current_me_file.id} :: create_next_offer_if_needed :: new offer #{new_offer.id} created" if new_offer.save
    else
      Rails.logger.info "MeFile #{@current_me_file.id} :: create_next_offer_if_needed :: media run for offer:#{from_which_offer.id} considered complete - no new offer created"
    end
  end

  def log_widget_serve
    new_log = SponsterWidgetServeLog.new

    if @current_user
      new_log.user_id = @current_user.id
      new_log.username = @current_user.username
      new_log.user_email = @current_user.email
      new_log.offers_count = @current_me_file.current_offers.count
      new_log.offers_amount = @current_me_file.current_offers.sum(:offer_amt).round(2)
    end
    if @this_recipient
      new_log.recipient_id = @this_recipient.id
      new_log.recipient_split_code = @this_recipient.split_code
      new_log.recipient_referral_code = @this_recipient.referral_code
    end
    new_log.host_page_url = params[:host_url]
    new_log.ip_address = request.remote_ip
    new_log.browser = browser.meta
    new_log.device = browser.device.instance_variable_get("@ua")
    new_log.platform = browser.platform

    if new_log.save
      Rails.logger.info "****SPONSTER WIDGET SERVED**** :: #{new_log.inspect}"
    else
      Rails.logger.info "****SPONSTER WIDGET SERVED**** :: ERROR :: #{new_log.errors.inspect}"
    end
  end
end 