defmodule Qlarius.Legacy.Offer do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at, updated_at: :updated_at]

  schema "offers" do
    field :offer_amt, :decimal
    field :marketer_cost_amt, :decimal
    field :pending_until, :naive_datetime
    field :is_payable, :boolean, default: false
    field :is_throttled, :boolean, default: false
    field :is_demo, :boolean, default: false
    field :is_current, :boolean, default: false
    field :is_jobbed, :boolean, default: false
    field :matching_tags_snapshot, :string
    field :ad_phase_count_to_complete, :integer

    belongs_to :campaign, Qlarius.Legacy.Campaign
    belongs_to :me_file, Qlarius.Legacy.MeFile
    belongs_to :media_run, Qlarius.Legacy.MediaRun
    belongs_to :media_piece, Qlarius.Legacy.MediaPiece
    belongs_to :target_band, Qlarius.Legacy.TargetBand

    has_many :ad_events, Qlarius.Legacy.AdEvent

    timestamps()
  end

  def changeset(offer, attrs) do
    offer
    |> cast(attrs, [
      :campaign_id,
      :me_file_id,
      :media_run_id,
      :media_piece_id,
      :target_band_id,
      :offer_amt,
      :marketer_cost_amt,
      :pending_until,
      :is_payable,
      :is_throttled,
      :is_demo,
      :is_current,
      :is_jobbed,
      :matching_tags_snapshot,
      :ad_phase_count_to_complete
    ])
    |> validate_required([
      :campaign_id,
      :me_file_id,
      :media_run_id,
      :media_piece_id,
      :target_band_id,
      :offer_amt,
      :marketer_cost_amt,
      :ad_phase_count_to_complete
    ])
  end
end
