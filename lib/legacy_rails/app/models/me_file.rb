class MeFile < ApplicationRecord
  include Cacheable
  belongs_to :user
  has_many :me_file_tags, dependent: :destroy
  has_many :traits, through: :me_file_tags, dependent: :destroy
  has_many :ad_events
  has_many :offers
  has_one :ledger_header
  has_many :mobile_phones
  has_many :referrals
  has_many :referral_credits
  has_one :referral, foreign_key: :referred_me_file_id
  has_many :target_populations, dependent: :destroy
  has_many :target_bands, through: :target_populations

  before_save :set_default_values
  

  validates :split_amount, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  def display_name_dynamic
    if self.user.present?
      return self.user.username + " (username)"
    elsif self.display_name && self.display_name.length > 0
      return self.display_name + " (mf_display)"
    else
      return self.id.to_s + " (mf_id)"
    end
  end

  def is_me_file_mvp?
    (date_of_birth.present? && traits.where(parent_trait_id:1).first) ? true : false
  end 

  def true_user
    #original user if this is a proxy user
    UserProxy.where(active:true, proxy_user_id: self.user_id).first.true_user
  end

  def age
    ((Time.zone.now - date_of_birth.to_time) / 1.year.seconds).floor
  end

  def home_zip
    traits.exists?(parent_trait_id:4) ? traits.where(parent_trait_id:4).first.trait_name : "NO ZIP"
  end

  def trait_tag_count
    traits.distinct.count(:parent_trait_id) > 0 ? traits.distinct.count(:parent_trait_id) + 1 : traits.distinct.count(:parent_trait_id) #add one for birthdate if me_file has been properly started
  end

  def account_stats
    if self.user.mobile_number
      mn = self.user.mobile_number.insert(0,"(").insert(4,")").insert(5," ").insert(9,"-")
    else
      mn = "Mobile # Unknown"
    end
    if self.user.email
      user_alias = self.user.email
    else
      user_alias = "missing_alias"
    end
    {:user_alias => user_alias, :mobile_number => mn, :home_zip => home_zip, :tag_count => tag_count, :trait_tag_count => trait_tag_count, :current_offer_count => current_offers.count, :offer_count => offers.count, :ledger_balance => ledger_header.balance, :payable_ledger_balance => ledger_header.balance_payable }
  end

  def tag_count
    # add 1 for birthdate
    me_file_tags.count + 1
  end

  def birthday_tag
    {
      tag_id:               nil,
      trait_name:           "Birthdate",
      tag_value:            date_of_birth ? date_of_birth.strftime("%b %d, %Y") : nil,
      trait_category_id:    1,
      trait_display_order:  1
    }
  end

  # def current_mobile_phone
  #   mobile_phone = mobile_phones.last
  #   (mobile_phone.present? && mobile_phone.deactivated_at.nil?) ? mobile_phone : nil
  # end

  # def sponster_activated?
  #   current_mobile_phone.try(:activated_at).present? && sponster_token.present?
  # end

  def current_offers
    offers.where(is_current: true).order(offer_amt: :desc)
  end

  def non_current_offers
    offers.where(is_current: false).order(offer_amt: :desc)
  end

  def tags_with_full_data
    return @tags_array if @tags_array.present?
    @tags_array = [birthday_tag] + me_file_tags.map(&:tag_with_full_data)
    result = @tags_array.sort_by! { |hsh| hsh[:trait_display_order] }
    return result
  end

  def is_trait_tagged?(this_trait_id)
    #does this mefile have this_trait_id as a current tag?
    me_file_tags.where(trait_id: this_trait_id).exists?
  end

  def parent_traits_tagged_array
    #return array of all parent traits with current tags
    traits.distinct(:parent_trait_id).pluck(:parent_trait_id)
  end

  def is_parent_trait_tagged?(this_trait_id)
    #does this mefile have any child traits of this_trait_id as a current tag?
    parent_traits_tagged_array.include?(this_trait_id)
  end

  def survey_question_completion_string(which_survey_id)
    # return string of 0/1 representing completion of survey with id which_survey_id
    question_array = Survey.find(which_survey_id).survey_questions.pluck(:trait_id)
    pt_array = parent_traits_tagged_array
    completion_string = ""
    question_array.each do |which_parent_trait|
      if pt_array.include?(which_parent_trait)
        completion_string += "1"
      else
        completion_string += "0"
      end
    end
    # Rails.logger.info "*********** survey_question_completion_string = " + completion_string
    completion_string
  end

  def unique_trait_names_tagged(trait_category_id)
    loop_array = tags_with_full_data
    if trait_category_id.blank?
      loop_array = tags_with_full_data
    else
      loop_array = loop_array.select { |t| t[:trait_category_id].to_i == trait_category_id.to_i }
    end
    result = loop_array.collect {|x| x[:trait_name]}.uniq
    return result
  end

  def unique_trait_categories_tagged
    trait_category_ids = tags_with_full_data.collect { |x| x[:trait_category_id] }.uniq
    TraitCategory.where(id: trait_category_ids).order(:display_order)
  end

  def tags_grouped_by_trait_name_for_category(trait_category_id)
    trait_name_tag_pairs = unique_trait_names_tagged(trait_category_id).inject([]) do |acc, trait_name|
      acc << {
        trait_name: trait_name,
        tag_values: tags_with_full_data.select { |mft| trait_name ==  mft[:trait_name] }
      }
      acc
    end
    trait_name_tag_pairs.sort_by { |hsh| hsh[:tag_values].first[:trait_display_order] }
  end

  def trait_with_tags(trait_id)
    trait = Trait.find(trait_id)
    {
      trait_name:     trait.try(:trait_name),
      display_order:  trait.try(:display_order),
      tag_values:     tags_with_full_data.select {|t| t[:trait_id] == trait_id.to_i }
    }
  end

  def answered_survey_question_count(survey)
    Survey.question_trait_ids[survey.id.to_s].to_a.inject(0) do |acc, trait_id|
      acc += 1 if tags_with_full_data.select {|t| t[:trait_id] == trait_id }.present?
      acc
    end
  end

  def target_with_optimal_band_hash
    Target.includes(target_bands: { trait_groups: { traits: :me_files } }).where(me_files: { id: id }).uniq.inject({}) do |acc, target|
      band = target.optimal_band_for_me_file(id)
      acc[target] = band if band
      acc
    end
  end

  def ad_unit_complete_count
    ad_events.where(is_offer_complete: true).count
  end

  def ad_unit_complete_referrer_paid_count
    ad_events.where(is_offer_complete: true).where.not(referral_credit: nil).count
  end

  def ad_unit_complete_referrer_to_be_paid_count
    referral_ad_pay_limit = GlobalVariable.find_by(name: 'REFERRAL_AD_PAY_LIMIT').value.to_i
    if ad_unit_complete_count - ad_unit_complete_referrer_paid_count < referral_ad_pay_limit - ad_unit_complete_referrer_paid_count
      ad_unit_complete_count - ad_unit_complete_referrer_paid_count
    else
      referral_ad_pay_limit - ad_unit_complete_referrer_paid_count
    end
  end

  def ad_units_complete_referrer_to_be_paid
    ad_events.where(is_offer_complete: true, referral_credit: nil).first(ad_unit_complete_referrer_to_be_paid_count)
  end

  def referral_ad_units_complete_count
    me_file_ids = referrals.pluck(:referred_me_file_id)
    AdEvent.where(me_file_id: me_file_ids).where(is_offer_complete: true).count
  end

  def referral_ad_units_paid_count
    me_file_ids = referrals.pluck(:referred_me_file_id)
    AdEvent.where(me_file_id: me_file_ids).where(is_offer_complete: true).where.not(referral_credit: nil).count
  end

  def referral_ad_units_to_be_paid_count
    referrals.where(is_fulfilled: false).inject(0) {|total, ref| total += ref.referred_me_file.ad_unit_complete_referrer_to_be_paid_count}
  end

  def referral_ad_units_to_be_paid
    referrals.where(is_fulfilled: false).map(&:referred_me_file).map(&:ad_units_complete_referrer_to_be_paid).flatten
  end

  def referrals_to_be_paid
    referrals.where(is_fulfilled: false).select { |ref| ref.referred_me_file.ad_units_complete_referrer_to_be_paid.count > 0 }
  end

  def tips_given
    ad_events.where('event_recipient_collect_amt > 0.00').count
  end

  def tips_given_total_sum
    ad_events.sum(:event_recipient_collect_amt).to_f
  end

  def beta_bonus_status
    cache_key = ENV['SCORE_BOARD_KEY'] % {me_file_id: id}
    bbs_hash = self.class.get_cache(cache_key)
    if bbs_hash.present?
      Rails.logger.info "GET BONUS SCORE BOARD INFO FROM CACHE."
      return bbs_hash
    end

    global_variable_names = %w[ SPONSTER_BETA_TAG_COUNT
                                SPONSTER_BETA_AD_COUNT
                                SPONSTER_BETA_REFERRAL_COUNT
                                SPONSTER_BETA_TIP_COUNT
                                SPONSTER_BETA_TIP_AMOUNT
                                SPONSTER_BETA_TIP_JAR_COUNT
                                SPONSTER_BETA_TAG_COUNT_BONUS
                                SPONSTER_BETA_AD_COUNT_BONUS
                                SPONSTER_BETA_REFERRAL_COUNT_BONUS
                                SPONSTER_BETA_TIP_COUNT_BONUS
                                SPONSTER_BETA_TIP_AMOUNT_BONUS ]

    bbs_hash = GlobalVariable.where(name: global_variable_names).inject({}) do |acc, variable|
      acc[variable.name.downcase[14..-1]] = variable.name.end_with?("BONUS") ? variable.value.to_f : variable.value.to_i
      acc
    end

    bbs_hash['tag_count_bonus_earned'] = tag_count >= bbs_hash['tag_count'] ? bbs_hash['tag_count_bonus'] : 0.0
    bbs_hash['ad_count_bonus_earned'] = ad_unit_complete_count >= bbs_hash['ad_count'] ? bbs_hash['ad_count_bonus'] : 0.0
    bbs_hash['referral_count_bonus_earned'] = referrals.count >= bbs_hash['referral_count'] ? bbs_hash['referral_count_bonus'] : 0.0
    bbs_hash['tip_count_bonus_earned'] = tips_given >= bbs_hash['tip_count'] ? bbs_hash['tip_count_bonus'] : 0.0
    bbs_hash['tip_amount_bonus_earned'] = tips_given_total_sum >= bbs_hash['tip_amount'] ? bbs_hash['tip_amount_bonus'] : 0.0
    bbs_hash['total_bonus_earned'] = bbs_hash['tag_count_bonus_earned'] + bbs_hash['ad_count_bonus_earned'] + bbs_hash['referral_count_bonus_earned'] + bbs_hash['tip_count_bonus_earned'] + bbs_hash['tip_amount_bonus_earned']
    self.class.set_cache(cache_key, bbs_hash, ENV['SCORE_BOARD_EXPIRED_SECONDS'])
    bbs_hash
  end

  def clear_tags_for_trait(trait_id)
    Rails.logger.info "me_file.rb :: clear_tags_for_trait :: trait_id=" + trait_id.to_s
    tags_to_be_deleted_array = trait_with_tags(trait_id)
    tags_to_be_deleted_array[:tag_values].each { |tag| MeFileTag.destroy(tag[:tag_id]) }
    me_file_tags.reload
    @tags_array = nil
    confirm_gone = trait_with_tags(trait_id)
    if confirm_gone
      Rails.logger.info "me_file.rb :: clear_tags_for_trait :: trait" + trait_id.to_s + " DELETED SUCCESSFULLY"
      return true
    else
      return false
    end

    CheckOfferToTargetBandMatch.perform_later(self.id) #since tags deleted, check to see if offers should be removed
  end

  def add_me_file_tag(trait_id)
    trait = Trait.find_by(id: trait_id)
    me_file_tags.create(
      trait_id:         trait_id,
      tag_value:        trait.try(:trait_name),
      expiration_date:  100.years.from_now,
      modified_date:    Time.zone.now, #legacy column name
      modified_by:      1, #unecessary value, column should be removed, legacy
      added_date:       Time.zone.now, #legacy column name
      added_by:         1 #unecessary value, column should be removed, legacy
    )
    @tags_array = nil
  end

  def update_age_tag
    # Find parent trait and existing age tag
    parent_trait = Trait.find_by(trait_name: "Age")
    old_me_file_tag = MeFileTag.find_by(me_file_id: self.id, trait_id: parent_trait.child_traits.pluck(:id))
    trait = Trait.find_by(parent_trait_id: parent_trait.id, trait_name: self.age)

    if trait.present?
      begin
        ActiveRecord::Base.transaction do
          # Create new tag without specifying ID
          new_mft = me_file_tags.create!(
            trait_id:         trait.id,
            tag_value:        trait.trait_name,
            expiration_date:  date_of_birth+1.year,
            modified_date:    Time.zone.now,
            modified_by:      1,
            added_date:       Time.zone.now,
            added_by:         1
          )

          # If successful creation, delete old tag and check offers
          if old_me_file_tag
            old_me_file_tag.destroy
            CheckOfferToTargetBandMatch.perform_later(self.id)
          end

          Rails.logger.info "***** update_age_tag MeFile #{self.id} - new age me_file_tag created - #{new_mft.inspect}"
        end
      rescue ActiveRecord::RecordNotUnique => e
        Rails.logger.error "***** update_age_tag MeFile #{self.id} - duplicate tag error: #{e.message}"
        return false
      rescue StandardError => e
        Rails.logger.error "***** update_age_tag MeFile #{self.id} - new age me_file_tag not saved successfully. Old tag retained if present. Error: #{e.message}"
        return false
      end
    end
  end

  def add_me_file_tag_with_value(trait_id, tag_value)
    me_file_tags.create(
      trait_id:         trait_id,
      tag_value:        tag_value,
      expiration_date:  100.years.from_now,
      modified_date:    Time.zone.now,
      modified_by:      user.id,
      added_date:       Time.zone.now,
      added_by:         user.id
    )
    @tags_array = nil
  end

  # def collect_banner_impression(offer_id, split_code, this_recipient, ip, url)
  #   offer = Offer.find_by(id: offer_id)
  #   phase = offer.media_piece.media_piece_type.media_piece_phases.where(phase: 1).first

  #   offer_attributes = offer.attributes.symbolize_keys.extract!(:campaign_id, :media_run_id, :media_piece_id, :target_band_id, :is_payable, :is_demo, :is_throttled)
  #   ad_event_attributes = {
  #     media_piece_phase:  phase,
  #     offer:              offer,
  #     offer_bid_amt:      offer.offer_amt,
  #     matching_tags_snapshot: offer.matching_tags_snapshot,
  #     ip_address:         ip,
  #     url:                url,
  #     event_split_code:   split_code
  #   }.merge!(offer_attributes)
  #   ad_event = ad_events.new(ad_event_attributes)

  #   if this_recipient.nil?
  #     Rails.logger.info "MeFile #{self.id} :: this_recipient :: *** no recipient for this banner collection ***"
  #     ad_event.event_me_file_collect_amt = phase.pay_to_me_file_fixed
  #     ad_event.event_sponster_collect_amt = phase.pay_to_sponster_fixed
  #   else
  #     Rails.logger.info "MeFile #{self.id} :: this_recipient :: *** recipient for this banner collection = #{this_recipient.name}***"
  #     ad_event.recipient_id = this_recipient.id
  #     ad_event.event_recipient_split_pct = split_amount
  #     ad_event.event_recipient_collect_amt = ((phase.pay_to_me_file_fixed - 0.005) * (ad_event.event_recipient_split_pct * 0.01)).round(2)
  #     ad_event.event_sponster_collect_amt = (phase.pay_to_sponster_fixed - phase.pay_to_recipient_from_sponster_fixed)
  #     ad_event.event_sponster_to_recipient_amt = phase.pay_to_recipient_from_sponster_fixed
  #     ad_event.event_me_file_collect_amt = phase.pay_to_me_file_fixed - ad_event.event_recipient_collect_amt
  #   end

  #   ad_event.offer_marketer_cost_amt = offer.marketer_cost_amt.to_f
  #   ad_event.event_marketer_cost_amt = ad_event.event_me_file_collect_amt.to_f + ad_event.event_sponster_collect_amt.to_f + ad_event.event_recipient_collect_amt.to_f + ad_event.event_sponster_to_recipient_amt.to_f

  #   Rails.logger.info ad_event.inspect

  #   if ad_event.save
  #     ad_event.me_file.ledger_header.write_to_me_file_ledger_from_ad_event(ad_event)
  #     ad_event.campaign.ledger_header.write_to_campaign_ledger_from_ad_event(ad_event)
  #     ad_event.recipient.ledger_header.write_to_recipient_ledger_from_ad_event(ad_event) if this_recipient.present?
  #   else
  #     Rails.logger.info ad_event.errors.full_messages
  #   end

  #   { collected_amount: ad_event.event_me_file_collect_amt, given_amount: ad_event.event_recipient_collect_amt }
  # end

  # def close_offer(offer_id)
  #   collected_amount = 0.00
  #   given_amount = 0.00
  #   ad_events_array = ad_events.reload.where("offer_id = #{offer_id} and created_at >= '#{10.minutes.ago.to_s(:db)}'")
  #   ad_events.reload.where("offer_id = #{offer_id} and created_at >= '#{10.minutes.ago.to_s(:db)}'").collect { |ae| collected_amount += ae.event_me_file_collect_amt.to_f }
  #   ad_events.reload.where("offer_id = #{offer_id} and created_at >= '#{10.minutes.ago.to_s(:db)}'").collect { |ae| given_amount += ae.event_recipient_collect_amt.to_f }
  #   { collected_amount: collected_amount, given_amount: given_amount }
  # end

  # def offer_status_by_ad_events(offer_id)
  #   ad_events_collection = ad_events.where(offer_id: offer_id)
  #   completed_status = ad_events_collection.where(is_offer_complete: true).exists?
  #   collected_amount = 0.00
  #   given_amount = 0.00
  #   # ad_events_array = ad_events.reload.where("offer_id = #{offer_id} and created_at >= '#{10.minutes.ago.to_s(:db)}'")
  #   ad_events_collection.where("created_at >= '#{10.minutes.ago.to_fs(:db)}'").collect { |ae| collected_amount += ae.event_me_file_collect_amt.to_f }
  #   ad_events_collection.where("created_at >= '#{10.minutes.ago.to_fs(:db)}'").collect { |ae| given_amount += ae.event_recipient_collect_amt.to_f }
  #   offer_count = current_offers.count-1 #subtract 1 because this offer still exists and shows as current but has not been flushed yet
  #   ledger_balance = ledger_header.balance
  #   { completed_status: completed_status, collected_amount: collected_amount, given_amount: given_amount }
  # end

  # def flush_used_offers
  #   Rails.logger.info "MeFile #{self.id} :: flush_used_offers :: entered"
  #   offers_to_check = Offer.where(id: AdEvent.where(me_file_id: id).where(offer_id: offers.pluck(:id)).pluck(:offer_id))
  #   Rails.logger.info "MeFile #{self.id} :: flush_used_offers :: #{offers_to_check.count} offers (with ad events) to check"
  #   offers_to_check.each do |this_offer|
  #     Rails.logger.info "MeFile #{self.id} :: flush_used_offers :: checking offer #{this_offer.id} from #{this_offer.campaign ? this_offer.campaign.marketer.business_name : "unknown"} :: #{this_offer.campaign ? this_offer.campaign.title : "unknown"}"
  #     if this_offer.ad_events.where(is_offer_complete: true).present?
  #       Rails.logger.info "MeFile #{self.id} :: flush_used_offers :: offer #{this_offer.id} is considered complete"
  #       create_next_offer_if_needed(this_offer)
  #       Rails.logger.info "MeFile #{self.id} :: flush_used_offers :: destroying offer #{this_offer.id}"
  #       this_offer.destroy
  #     else
  #       Rails.logger.info "MeFile #{self.id} :: flush_used_offers :: offer #{this_offer.id} not completed"
  #       # if the offer has not been clicked through, check if the maximum banner count has been reached
  #       if this_offer.ad_events.count < this_offer.media_run.maximum_banner_count
  #         Rails.logger.info "MeFile #{self.id} :: flush_used_offers :: offer #{this_offer.id} maximum banner count not exceeded"
  #         new_pending_until = this_offer.ad_events.last.created_at + this_offer.media_run.banner_retry_buffer_hours.hours
  #         if new_pending_until > this_offer.pending_until
  #           Rails.logger.info "MeFile #{self.id} :: flush_used_offers :: resetting offer banner attempt pending until #{new_pending_until} and making not current"
  #           this_offer.update(:is_current => false, :pending_until => new_pending_until)
  #         else
  #           Rails.logger.info "MeFile #{self.id} :: flush_used_offers :: leaving offer as is"
  #         end
  #       # if the offer has been clicked through, check if the completion phase has been reached
  #       elsif this_offer.ad_events.joins(media_piece_phase: :media_piece_type)
  #                      .where('media_piece_phases.phase = media_piece_types.ad_phase_count_to_complete')
  #                      .exists?
  #         Rails.logger.info "MeFile #{self.id} :: flush_used_offers :: offer #{this_offer.id} has reached completion phase"
  #         #mark the last ad_event as complete and create next offer if needed
  #         this_offer.ad_events.last.update(is_offer_complete: true)
  #         create_next_offer_if_needed(this_offer)
  #       else
  #         Rails.logger.info "MeFile #{self.id} :: flush_used_offers :: offer #{this_offer.id} maximum banner count reached before click through"
  #         #mark the last ad_event as is_complete and create next offer if needed
  #         this_offer.ad_events.last.update(is_offer_complete: true)
  #         create_next_offer_if_needed(this_offer)
  #       end
  #       Rails.logger.info "MeFile #{self.id} :: flush_used_offers :: no offers considered complete"
  #     end
  #   end
  # end

  # def create_next_offer_if_needed(from_which_offer)
  #   Rails.logger.info "MeFile #{self.id} :: create_next_offer_if_needed :: offer:#{from_which_offer.id} - completed_offer_count is #{from_which_offer.completed_offer_count} of frequency #{from_which_offer.media_run.frequency}"
  #   if from_which_offer.completed_offer_count < from_which_offer.media_run.frequency
  #     Rails.logger.info "MeFile #{self.id} :: create_next_offer_if_needed :: creating clone offer for offer #{from_which_offer.id}"
  #     new_offer = from_which_offer.dup
  #     new_offer.pending_until = from_which_offer.ad_events.last.created_at + from_which_offer.media_run.frequency_buffer_hours.hours
  #     new_offer.is_current = 0
  #     Rails.logger.info "MeFile #{self.id} :: create_next_offer_if_needed :: new offer #{new_offer.id} created" if new_offer.save
  #   else
  #     Rails.logger.info "MeFile #{self.id} :: create_next_offer_if_needed :: media run for offer:#{from_which_offer.id} considered complete - no new offer created"
  #   end
  # end

  # def collect_ad_jump(offer_id, split_code, ip, url)
  #   Rails.logger.info "************ collect_ad_jump - offer_id: " + offer_id.to_s + " split_code: " + split_code.to_s + " ip:" + ip.to_s + " url:" + url.to_s
  #   error_message = ""
  #   offer = Offer.find(offer_id)

  #   if offer
  #     error_message = "This offer/ad is not available for this MeFile." if id != offer.me_file.id
  #     phase = offer.media_piece.media_piece_type.media_piece_phases.where(phase: 2).first
  #     error_message = "ERROR -  phase previously collected" if offer.ad_events.where(media_piece_phase_id: phase).present?
  #   else
  #     error_message = "Offer not found."
  #   end

  #   if error_message.blank?
  #     last_phase = offer.media_piece.media_piece_type.media_piece_phases.where(phase: 1).first
  #     split_code = 'null' == split_code ? nil : split_code
  #     this_recipient = Recipient.where(split_code: split_code.to_s).first

  #     offer_attributes = offer.attributes.symbolize_keys.extract!(:campaign_id, :media_run_id, :media_piece_id, :target_band_id, :is_payable, :is_demo, :is_throttled)
  #     ad_event_attributes = {
  #       media_piece_phase:  phase,
  #       offer:              offer,
  #       offer_bid_amt:      offer.offer_amt,
  #       matching_tags_snapshot: offer.matching_tags_snapshot,
  #       is_offer_complete:  true,
  #       ip_address:         ip,
  #       url:                url,
  #       event_split_code:   split_code
  #     }.merge!(offer_attributes)
  #     ad_event = ad_events.new(ad_event_attributes)

  #     amt_already_paid_total = last_phase.pay_to_me_file_fixed + last_phase.pay_to_sponster_fixed
  #     offer_amt_remaining = ad_event.offer_bid_amt - last_phase.pay_to_me_file_fixed

  #     if this_recipient.nil?
  #       ad_event.event_me_file_collect_amt = offer_amt_remaining
  #       ad_event.event_recipient_collect_amt = 0.00
  #     else
  #       ad_event.recipient_id = this_recipient.id
  #       ad_event.event_recipient_split_pct = self.split_amount
  #       ad_event.event_recipient_collect_amt = (offer_amt_remaining * (ad_event.event_recipient_split_pct * 0.01)).round(2)
  #       ad_event.event_me_file_collect_amt = offer_amt_remaining - ad_event.event_recipient_collect_amt
  #     end

  #     ad_event.event_sponster_collect_amt = offer.marketer_cost_amt - amt_already_paid_total - ad_event.event_me_file_collect_amt - ad_event.event_recipient_collect_amt
  #     ad_event.offer_marketer_cost_amt = offer.marketer_cost_amt
  #     ad_event.event_marketer_cost_amt = ad_event.event_me_file_collect_amt + ad_event.event_sponster_collect_amt + ad_event.event_recipient_collect_amt.to_f

  #     if ad_event.save
  #       ledger_header.write_to_me_file_ledger_from_ad_event(ad_event)
  #       ad_event.campaign.ledger_header.write_to_campaign_ledger_from_ad_event(ad_event)
  #       ad_event.recipient.ledger_header.write_to_recipient_ledger_from_ad_event(ad_event) if this_recipient.present?
  #     end
  #   end
  #   if error_message.blank?
  #     { collected_amount: ad_event.event_me_file_collect_amt, given_amount: ad_event.event_recipient_collect_amt }
  #   else
  #     {error: error_message}
  #   end
  #   flush_used_offers
  # end

  def create_tags(tag_ids_array, base_trait_id)
    if tag_ids_array.nil?
      Rails.logger.info "***** me_file.rb : create_tags : NO NEW TAGS"
    else
      Rails.logger.info "***** me_file.rb : create_tags"
      clear_tags_for_trait(base_trait_id)
      tag_ids_array.each do |t|
        add_me_file_tag t
      end
      @tags_array = nil
    end
  end

  def make_referral_payment_to_ledger
    ledger_header.write_to_me_file_ledger_from_referrals(referrals_to_be_paid, referral_ad_units_to_be_paid)
  end

  def set_default_values
    self.split_amount = 50 if self.split_amount.nil?
    build_ledger_header(
      me_file_id: self.id,
      balance: 0.00,
      balance_payable: 0.00
    ) unless ledger_header.present?
  end

end
