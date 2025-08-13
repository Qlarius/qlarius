defmodule Qlarius.Sponster.Campaigns.MediaRun do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Sponster.Campaigns.{Campaign, MediaSequence}
  alias Qlarius.Sponster.Ads.MediaPiece

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at, updated_at: :updated_at]

  schema "media_runs" do
    # field :started_at, :naive_datetime
    # field :ended_at, :naive_datetime
    field :is_active, :boolean, default: true
    # field :paused, :boolean, default: false

    belongs_to :media_piece, MediaPiece
    belongs_to :media_sequence, MediaSequence

    has_many :offers, Qlarius.Sponster.Offer
    has_many :ad_events, Qlarius.Sponster.AdEvent

    timestamps()
  end

  def changeset(media_run, attrs) do
    media_run
    |> cast(attrs, [
      # :started_at,
      # :ended_at,
      :is_active,
      :paused,
      :media_piece_id,
      :media_sequence_id
    ])
    |> validate_required([
      :media_piece_id,
      :media_sequence_id
    ])
    |> foreign_key_constraint(:media_piece_id)
    |> foreign_key_constraint(:media_sequence_id)
    |> foreign_key_constraint(:campaign_id)
  end
end
