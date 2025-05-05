defmodule Qlarius.Offer do
  use Ecto.Schema

  alias Qlarius.Accounts.User
  alias Qlarius.Marketing.MediaRun

  schema "offers" do
    field :amount, :decimal, source: :offer_amt
    field :marketer_cost_amt, :decimal
    field :pending_until, :naive_datetime
    field :is_payable, :boolean, default: false
    field :is_throttled, :boolean, default: false
    field :is_demo, :boolean, default: false
    field :is_current, :boolean, default: false
    field :is_jobbed, :boolean, default: false
    field :matching_tags_snapshot, :string
    field :ad_phase_count_to_complete, :integer

    belongs_to :campaign, Qlarius.Campaigns.Campaign
    belongs_to :me_file, Qlarius.Accounts.MeFile
    belongs_to :media_run, Qlarius.Marketing.MediaRun
    belongs_to :media_piece, Qlarius.Marketing.MediaPiece
    belongs_to :target_band, Qlarius.Legacy.TargetBand

    has_one :user, through: [:me_file, :user]

    has_one :ad_category, through: [:media_piece, :ad_category]

    has_many :ad_events, Qlarius.AdEvent

    timestamps(type: :utc_datetime, inserted_at_source: :created_at)
  end
end
