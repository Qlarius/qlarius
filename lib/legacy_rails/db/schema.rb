# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2023_04_24_130940) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
  end

  create_table "ad_categories", id: :serial, force: :cascade do |t|
    t.string "ad_category_name", limit: 256, default: "", null: false
  end

  create_table "ad_events", id: :serial, force: :cascade do |t|
    t.integer "campaign_id"
    t.integer "me_file_id"
    t.integer "media_run_id"
    t.integer "media_piece_id"
    t.integer "media_piece_phase_id"
    t.integer "target_id"
    t.integer "target_band_id"
    t.integer "offer_id"
    t.decimal "offer_bid_amt", precision: 8, scale: 2
    t.boolean "is_payable"
    t.boolean "is_throttled"
    t.boolean "is_demo"
    t.boolean "is_offer_complete", default: false
    t.decimal "offer_marketer_cost_amt", precision: 8, scale: 2
    t.decimal "event_marketer_cost_amt", precision: 8, scale: 2
    t.decimal "event_me_file_collect_amt", precision: 8, scale: 2
    t.integer "referral_credit_id"
    t.integer "recipient_id"
    t.integer "event_recipient_split_pct"
    t.decimal "event_recipient_collect_amt", precision: 8, scale: 2
    t.decimal "event_sponster_collect_amt", precision: 8, scale: 2
    t.decimal "event_sponster_to_recipient_amt", precision: 8, scale: 2
    t.string "event_split_code", limit: 255
    t.string "ip_address", limit: 255
    t.string "url", limit: 255
    t.string "adget_id_string", limit: 255
    t.string "session_id_string", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "matching_tags_snapshot"
    t.index ["campaign_id"], name: "index_ad_events_on_campaign_id"
    t.index ["me_file_id"], name: "index_ad_events_on_me_file_id"
    t.index ["media_piece_id"], name: "index_ad_events_on_media_piece_id"
    t.index ["media_piece_phase_id"], name: "index_ad_events_on_media_piece_phase_id"
    t.index ["media_run_id"], name: "index_ad_events_on_media_run_id"
    t.index ["offer_id"], name: "index_ad_events_on_offer_id"
    t.index ["recipient_id"], name: "index_ad_events_on_recipient_id"
    t.index ["referral_credit_id"], name: "index_ad_events_on_referral_credit_id"
    t.index ["target_band_id"], name: "index_ad_events_on_target_band_id"
    t.index ["target_id"], name: "index_ad_events_on_target_id"
  end

  create_table "bids", id: :serial, force: :cascade do |t|
    t.integer "campaign_id"
    t.integer "media_run_id"
    t.integer "target_band_id"
    t.decimal "offer_amt", precision: 10, scale: 2
    t.decimal "marketer_cost_amt", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "campaigns", id: :serial, force: :cascade do |t|
    t.integer "marketer_id"
    t.integer "target_id"
    t.integer "media_sequence_id"
    t.string "title", limit: 255
    t.text "description"
    t.datetime "start_date"
    t.datetime "end_date"
    t.boolean "is_payable"
    t.boolean "is_throttled"
    t.boolean "is_demo"
    t.datetime "deactivated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "global_variables", id: :serial, force: :cascade do |t|
    t.string "name", limit: 64, default: "", null: false
    t.text "value"
  end

  create_table "ledger_entries", id: :serial, force: :cascade do |t|
    t.decimal "amt", precision: 8, scale: 2
    t.string "description", limit: 255
    t.boolean "is_payable"
    t.integer "ledger_header_id"
    t.integer "ad_event_id"
    t.integer "transfer_event_id"
    t.integer "payout_event_id"
    t.decimal "running_balance", precision: 8, scale: 2
    t.decimal "running_balance_payable", precision: 8, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "ledger_headers", id: :serial, force: :cascade do |t|
    t.string "description", limit: 255
    t.decimal "balance", precision: 10, scale: 2
    t.decimal "balance_payable", precision: 10, scale: 2
    t.integer "me_file_id"
    t.integer "campaign_id"
    t.integer "recipient_id"
    t.integer "marketer_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "marketer_users", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.integer "marketer_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "marketers", id: :serial, force: :cascade do |t|
    t.string "business_name", limit: 255
    t.string "business_url", limit: 255
    t.string "contact_first_name", limit: 255
    t.string "contact_last_name", limit: 255
    t.string "contact_number", limit: 255
    t.string "contact_email", limit: 255
    t.string "sic_code", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "me_file_tags", id: :integer, default: -> { "nextval('sponster_widget_serve_logs_id_seq'::regclass)" }, force: :cascade do |t|
    t.integer "me_file_id", null: false
    t.integer "trait_id", null: false
    t.string "tag_value", limit: 256
    t.datetime "expiration_date", null: false
    t.datetime "modified_date", null: false
    t.integer "modified_by", null: false
    t.datetime "added_date", null: false
    t.integer "added_by", null: false
    t.text "customized_hash"
  end

  create_table "me_files", id: :integer, default: -> { "nextval('\"me_files_MeFileId_seq\"'::regclass)" }, force: :cascade do |t|
    t.integer "user_id"
    t.string "display_name", limit: 75
    t.date "date_of_birth"
    t.integer "ledger_header_id"
    t.string "sponster_token", limit: 50
    t.integer "split_amount", default: 50
    t.integer "referral_id"
    t.string "referral_code", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "media_piece_phases", id: :serial, force: :cascade do |t|
    t.integer "media_piece_type_id"
    t.integer "phase"
    t.string "name", limit: 255
    t.string "desc", limit: 255
    t.boolean "is_final_phase", default: false
    t.decimal "pay_to_me_file_fixed", precision: 8, scale: 2
    t.decimal "pay_to_me_file_percent", precision: 8, scale: 2
    t.decimal "pay_to_sponster_fixed", precision: 8, scale: 2
    t.decimal "pay_to_sponster_percent", precision: 8, scale: 2
    t.decimal "pay_to_recipient_from_sponster_fixed", precision: 8, scale: 2
    t.decimal "pay_to_recipient_from_sponster_percent", precision: 8, scale: 2
    t.decimal "pay_to_recipient_from_me_file_fixed", precision: 8, scale: 2
    t.decimal "pay_to_recipient_from_me_file_percent", precision: 8, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "media_piece_types", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.string "desc", limit: 255
    t.integer "ad_phase_count_to_complete"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "media_pieces", id: :serial, force: :cascade do |t|
    t.integer "marketer_id", null: false
    t.integer "ad_category_id", null: false
    t.integer "media_piece_type_id", limit: 2, null: false
    t.string "title", limit: 256
    t.string "display_url", limit: 256
    t.string "body_copy", limit: 1028
    t.string "resource_url_old", limit: 512
    t.string "resource_url", limit: 512
    t.string "resource_file_name", limit: 255
    t.string "resource_content_type", limit: 255
    t.integer "resource_file_size"
    t.datetime "resource_updated_at"
    t.integer "duration"
    t.string "jump_url", limit: 512
    t.boolean "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "media_runs", id: :serial, force: :cascade do |t|
    t.integer "marketer_id"
    t.integer "media_sequence_id"
    t.integer "media_piece_id"
    t.integer "sequence_start_phase"
    t.integer "sequence_end_phase"
    t.integer "frequency"
    t.integer "frequency_buffer_hours"
    t.integer "maximum_banner_count"
    t.integer "banner_retry_buffer_hours"
    t.boolean "is_active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "media_sequences", id: :serial, force: :cascade do |t|
    t.integer "marketer_id"
    t.string "title", limit: 255
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "mobile_phones", id: :serial, force: :cascade do |t|
    t.integer "me_file_id", null: false
    t.string "mobile_number", limit: 11, default: "", null: false
    t.string "activation_code", limit: 255, default: ""
    t.datetime "activation_code_sent_at"
    t.datetime "activated_at"
    t.datetime "deactivated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "mobile_registration_requests", force: :cascade do |t|
    t.string "mobile_number", null: false
    t.string "referral_code"
    t.string "validation_code", null: false
    t.string "validation_api_response"
    t.datetime "validation_code_sent"
    t.datetime "validation_success_at"
    t.string "gender"
    t.date "birthdate"
    t.string "home_zip_entered"
    t.string "home_zip_trait_id"
    t.string "ip_address"
    t.string "browser"
    t.string "device"
    t.string "platform"
    t.datetime "registration_success_at"
    t.bigint "me_file_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "oauth_access_grants", id: :serial, force: :cascade do |t|
    t.integer "resource_owner_id", null: false
    t.integer "application_id", null: false
    t.string "token", limit: 255, null: false
    t.integer "expires_in", null: false
    t.text "redirect_uri", null: false
    t.datetime "created_at", null: false
    t.datetime "revoked_at"
    t.string "scopes", limit: 255
  end

  create_table "oauth_access_tokens", id: :serial, force: :cascade do |t|
    t.integer "resource_owner_id"
    t.integer "application_id"
    t.string "token", limit: 255, null: false
    t.string "refresh_token", limit: 255
    t.integer "expires_in"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.string "scopes", limit: 255
  end

  create_table "oauth_applications", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.string "uid", limit: 255, null: false
    t.string "secret", limit: 255, null: false
    t.text "redirect_uri", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "scopes", limit: 255, default: "", null: false
  end

  create_table "offers", id: :serial, force: :cascade do |t|
    t.integer "campaign_id", null: false
    t.integer "me_file_id", null: false
    t.integer "media_run_id", null: false
    t.integer "media_piece_id", null: false
    t.integer "ad_phase_count_to_complete", limit: 2, null: false
    t.integer "target_band_id", null: false
    t.decimal "offer_amt", precision: 10, scale: 2, null: false
    t.decimal "marketer_cost_amt", precision: 10, scale: 2, null: false
    t.datetime "pending_until"
    t.boolean "is_payable", default: false, null: false
    t.boolean "is_throttled", default: false, null: false
    t.boolean "is_demo", default: false, null: false
    t.boolean "is_current", default: false, null: false
    t.boolean "is_jobbed", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "matching_tags_snapshot"
  end

  create_table "recipient_types", id: :serial, force: :cascade do |t|
    t.string "type_name", limit: 255
  end

  create_table "recipients", id: :serial, force: :cascade do |t|
    t.string "split_code", limit: 255, default: ""
    t.integer "user_id", null: false
    t.string "name", limit: 255
    t.text "description"
    t.text "message"
    t.decimal "target_amount", precision: 10, scale: 2
    t.string "site_url", limit: 255
    t.string "graphic_url", limit: 255
    t.integer "recipient_type_id"
    t.string "contact_email", limit: 255
    t.datetime "approval_date"
    t.integer "approved_by_user_id"
    t.datetime "updated_at"
    t.datetime "created_at"
    t.string "referral_code", limit: 255
  end

  create_table "referral_clicks", id: :serial, force: :cascade do |t|
    t.integer "referral_id"
    t.integer "referral_credit_id"
    t.integer "ad_event_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "referral_credits", id: :serial, force: :cascade do |t|
    t.integer "ledger_entry_id"
    t.integer "credit_amt"
    t.integer "me_file_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "referrals", id: :serial, force: :cascade do |t|
    t.integer "me_file_id"
    t.integer "recipient_id"
    t.integer "referred_me_file_id", null: false
    t.boolean "is_fulfilled", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sponster_widget_serve_logs", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "recipient_id"
    t.string "username"
    t.string "user_email"
    t.integer "offers_count"
    t.decimal "offers_amount"
    t.string "recipient_split_code"
    t.string "recipient_referral_code"
    t.string "ip_address"
    t.text "host_page_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "browser"
    t.text "device"
    t.string "platform"
  end

  create_table "survey_answers", id: :integer, default: -> { "nextval('\"survey_answers_SurveyAnswerId_seq\"'::regclass)" }, force: :cascade do |t|
    t.string "text", limit: 4096
    t.integer "survey_question_id"
    t.integer "trait_id"
    t.integer "display_order"
    t.integer "next_survey_question_id"
    t.datetime "modified_date", null: false
    t.integer "modified_by", null: false
    t.datetime "added_date", null: false
    t.integer "added_by", null: false
  end

  create_table "survey_categories", id: :integer, default: -> { "nextval('\"survey_categories_SurveyCategoryId_seq\"'::regclass)" }, force: :cascade do |t|
    t.string "survey_category_name", limit: 256, null: false
    t.integer "display_order"
    t.datetime "modified_date", null: false
    t.integer "modified_by", null: false
    t.datetime "added_date", null: false
    t.integer "added_by", null: false
  end

  create_table "survey_question_surveys", id: :serial, force: :cascade do |t|
    t.integer "survey_question_id", null: false
    t.integer "survey_id", null: false
    t.integer "display_order"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "survey_questions", id: :integer, default: -> { "nextval('\"survey_questions_SurveyQuestionId_seq\"'::regclass)" }, force: :cascade do |t|
    t.string "text", limit: 4096
    t.integer "trait_id"
    t.datetime "modified_date", null: false
    t.integer "modified_by", null: false
    t.datetime "added_date", null: false
    t.integer "added_by", null: false
    t.binary "active", null: false
    t.integer "display_order"
  end

  create_table "surveys", id: :serial, force: :cascade do |t|
    t.string "name", limit: 512, null: false
    t.integer "survey_category_id"
    t.datetime "updated_at", null: false
    t.integer "updated_by", null: false
    t.datetime "created_at", null: false
    t.integer "created_by", null: false
    t.integer "display_order"
    t.boolean "active", default: false, null: false
  end

  create_table "target_band_trait_groups", id: :serial, force: :cascade do |t|
    t.integer "target_band_id"
    t.integer "trait_group_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "target_bands", id: :serial, force: :cascade do |t|
    t.integer "target_id"
    t.string "title", limit: 255
    t.string "description", limit: 255
    t.string "is_bullseye", default: "0", null: false
    t.integer "user_created_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "target_populations", id: :serial, force: :cascade do |t|
    t.integer "target_band_id"
    t.integer "me_file_id"
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
  end

  create_table "targets", id: :serial, force: :cascade do |t|
    t.integer "marketer_id"
    t.string "title", limit: 255
    t.string "description", limit: 255
    t.integer "user_created_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "trait_categories", id: :integer, default: -> { "nextval('\"trait_categories_TraitCategoryId_seq\"'::regclass)" }, force: :cascade do |t|
    t.string "trait_category_name", limit: 256, null: false
    t.integer "display_order"
    t.datetime "modified_date", null: false
    t.integer "modified_by", null: false
    t.datetime "added_date", null: false
    t.integer "added_by", null: false
  end

  create_table "trait_group_traits", id: :serial, force: :cascade do |t|
    t.integer "trait_group_id"
    t.integer "trait_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "trait_groups", id: :serial, force: :cascade do |t|
    t.string "title", limit: 255
    t.string "description", limit: 255
    t.integer "parent_trait_id"
    t.integer "marketer_id"
    t.integer "user_created_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deactivated_at"
  end

  create_table "traits", id: :integer, default: -> { "nextval('\"traits_TraitId_seq\"'::regclass)" }, force: :cascade do |t|
    t.string "trait_name", limit: 256, null: false
    t.integer "active", limit: 2, null: false
    t.integer "is_taggable", limit: 2, null: false
    t.string "input_type", limit: 30, null: false
    t.integer "display_order", null: false
    t.integer "parent_trait_id"
    t.boolean "is_campaign_only", default: false, null: false
    t.boolean "is_numeric", default: false
    t.datetime "modified_date", null: false
    t.integer "modified_by", null: false
    t.datetime "added_date", null: false
    t.integer "added_by", null: false
    t.integer "trait_category_id"
    t.boolean "immutable", default: false, null: false
    t.integer "max_length"
    t.integer "max_selected"
    t.boolean "is_date", default: false
  end

  create_table "user_prefs", force: :cascade do |t|
    t.boolean "sponster_email_alerts"
    t.boolean "sponster_text_alerts"
    t.boolean "sponster_browser_alerts"
    t.boolean "sponster_push_notifications"
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "user_proxies", force: :cascade do |t|
    t.boolean "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "true_user_id"
    t.bigint "proxy_user_id"
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "username", limit: 255, null: false
    t.string "email", limit: 255, default: "", null: false
    t.string "encrypted_password", limit: 255, default: "", null: false
    t.string "reset_password_token", limit: 255
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip", limit: 255
    t.string "last_sign_in_ip", limit: 255
    t.string "confirmation_token", limit: 255
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email", limit: 255
    t.integer "failed_attempts", default: 0
    t.string "unlock_token", limit: 255
    t.datetime "locked_at"
    t.string "authentication_token", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "referrer_code", limit: 255
    t.string "role"
    t.string "passage_id"
    t.string "mobile_number"
  end

  create_table "worker_job_logs", id: :serial, force: :cascade do |t|
    t.string "job_name", limit: 255
    t.string "job_key", limit: 255
    t.string "job_value", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
end
