defmodule Qlarius.Sponster.AdEvent do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Sponster.Offer
  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.Sponster.Campaigns.Campaign
  alias Qlarius.Sponster.Campaigns.MediaRun
  alias Qlarius.Sponster.Ads.MediaPiece

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at, updated_at: :updated_at]

  schema "ad_events" do
    field :offer_bid_amt, :decimal
    field :is_throttled, :boolean, default: false
    field :is_offer_complete, :boolean, default: false
    field :ip_address, :string
    field :url, :string
    field :media_piece_phase_id, :integer
    field :target_id, :integer
    field :target_band_id, :integer
    field :is_payable, :boolean
    field :is_demo, :boolean
    field :offer_marketer_cost_amt, :decimal
    field :event_marketer_cost_amt, :decimal
    field :event_me_file_collect_amt, :decimal
    field :referral_credit_id, :integer
    field :recipient_id, :integer
    field :event_recipient_split_pct, :integer
    field :event_recipient_collect_amt, :decimal
    field :event_sponster_collect_amt, :decimal
    field :event_sponster_to_recipient_amt, :decimal
    field :event_split_code, :string
    field :adget_id_string, :string
    field :session_id_string, :string
    field :matching_tags_snapshot, :string

    belongs_to :offer, Offer
    belongs_to :me_file, MeFile
    belongs_to :campaign, Campaign
    belongs_to :media_run, MediaRun
    belongs_to :media_piece, MediaPiece

    timestamps()
  end

  def changeset(ad_event, attrs) do
    ad_event
    |> cast(attrs, [
      :offer_bid_amt,
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
      :offer_marketer_cost_amt,
      :event_marketer_cost_amt,
      :event_me_file_collect_amt,
      :referral_credit_id,
      :recipient_id,
      :event_recipient_split_pct,
      :event_recipient_collect_amt,
      :event_sponster_collect_amt,
      :event_sponster_to_recipient_amt,
      :event_split_code,
      :adget_id_string,
      :session_id_string,
      :matching_tags_snapshot
    ])
    |> validate_required([
      :offer_bid_amt,
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
      :offer_marketer_cost_amt,
      :event_marketer_cost_amt,
      :event_me_file_collect_amt,
      :event_sponster_collect_amt
    ])
    |> foreign_key_constraint(:offer_id)
    |> foreign_key_constraint(:me_file_id)
    |> foreign_key_constraint(:campaign_id)
    |> foreign_key_constraint(:media_run_id)
    |> foreign_key_constraint(:media_piece_id)
  end
end
