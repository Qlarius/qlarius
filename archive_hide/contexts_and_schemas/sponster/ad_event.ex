defmodule Qlarius.Sponster.AdEvent do
  use Ecto.Schema

  import Ecto.Changeset

  schema "ad_events" do
    field :offer_bid_amount, :decimal, source: :offer_bid_amt
    field :is_payable, :boolean
    field :is_throttled, :boolean
    field :is_demo, :boolean
    field :is_offer_complete, :boolean, default: false
    field :ip_address, :string
    field :url, :string

    field :offer_marketer_cost_amount, :decimal, source: :offer_marketer_cost_amt
    field :event_marketer_cost_amount, :decimal, source: :event_marketer_cost_amt
    field :event_me_file_collect_amount, :decimal, source: :event_me_file_collect_amt
    field :referral_credit_id, :integer
    field :recipient_id, :integer
    field :event_recipient_split_pct, :integer
    field :event_recipient_collect_amount, :decimal, source: :event_recipient_collect_amt
    field :event_sponster_collect_amount, :decimal, source: :event_sponster_collect_amt
    field :event_sponster_to_recipient_amount, :decimal, source: :event_sponster_to_recipient_amt
    field :event_split_code, :string
    field :adget_id_string, :string
    field :session_id_string, :string
    field :matching_tags_snapshot, :string

    belongs_to :offer, Qlarius.Sponster.Offer
    belongs_to :me_file, Qlarius.YouData.MeFile
    belongs_to :campaign, Qlarius.Sponster.Campaigns.Campaign
    belongs_to :media_run, Qlarius.Sponster.Campaigns.MediaRun
    belongs_to :media_piece, Qlarius.Sponster.Ads.MediaPiece
    belongs_to :media_piece_phase, Qlarius.Sponster.Ads.MediaPiecePhase
    belongs_to :target, Qlarius.Sponster.Campaigns.Target
    belongs_to :target_band, Qlarius.Sponster.Campaigns.TargetBand

    timestamps(type: :utc_datetime, inserted_at_source: :created_at)
  end

  def changeset(ad_event, attrs) do
    ad_event
    |> cast(attrs, [
      :offer_bid_amount,
      :is_throttled,
      :is_offer_complete,
      :ip_address,
      :url,
      :offer_id,
      :me_file_id,
      :campaign_id,
      :media_run_id,
      :media_piece_id,
      :media_piece_phase_id,
      :target_id,
      :target_band_id,
      :is_payable,
      :is_demo,
      :offer_marketer_cost_amount,
      :event_marketer_cost_amount,
      :event_me_file_collect_amount,
      :referral_credit_id,
      :recipient_id,
      :event_recipient_split_pct,
      :event_recipient_collect_amount,
      :event_sponster_collect_amount,
      :event_sponster_to_recipient_amount,
      :event_split_code,
      :adget_id_string,
      :session_id_string,
      :matching_tags_snapshot
    ])
    |> validate_required([
      :offer_bid_amount,
      :is_throttled,
      :is_offer_complete,
      :ip_address,
      :url,
      :offer_id,
      :me_file_id,
      :campaign_id,
      :media_run_id,
      :media_piece_id,
      :media_piece_phase_id,
      :target_band_id,
      :is_payable,
      :offer_marketer_cost_amount,
      :event_marketer_cost_amount,
      :event_me_file_collect_amount,
      :event_sponster_collect_amount
    ])
    |> foreign_key_constraint(:offer_id)
    |> foreign_key_constraint(:me_file_id)
    |> foreign_key_constraint(:campaign_id)
    |> foreign_key_constraint(:media_run_id)
  end
end
