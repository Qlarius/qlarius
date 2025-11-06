defmodule Qlarius.Sponster.Campaigns.MediaRun do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Sponster.Campaigns.MediaSequence
  alias Qlarius.Sponster.Ads.MediaPiece
  alias Qlarius.Sponster.Marketer

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at, updated_at: :updated_at]

  schema "media_runs" do
    field :sequence_start_phase, :integer
    field :sequence_end_phase, :integer
    field :frequency, :integer
    field :frequency_buffer_hours, :integer
    field :maximum_banner_count, :integer
    field :banner_retry_buffer_hours, :integer
    field :is_active, :boolean

    belongs_to :marketer, Marketer
    belongs_to :media_piece, MediaPiece
    belongs_to :media_sequence, MediaSequence

    has_many :offers, Qlarius.Sponster.Offer
    has_many :ad_events, Qlarius.Sponster.AdEvent

    timestamps()
  end

  def changeset(media_run, attrs) do
    media_run
    |> cast(attrs, [
      :sequence_start_phase,
      :sequence_end_phase,
      :frequency,
      :frequency_buffer_hours,
      :maximum_banner_count,
      :banner_retry_buffer_hours,
      :is_active,
      :marketer_id,
      :media_piece_id,
      :media_sequence_id
    ])
    |> validate_required([
      :media_piece_id,
      :media_sequence_id,
      :marketer_id
    ])
    |> foreign_key_constraint(:marketer_id)
    |> foreign_key_constraint(:media_piece_id)
    |> foreign_key_constraint(:media_sequence_id)
  end
end
