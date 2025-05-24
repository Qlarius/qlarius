defmodule Qlarius.Sponster.Campaigns.MediaRun do
  use Ecto.Schema
  import Ecto.Changeset

  schema "media_runs" do
    # belongs_to :marketer_id

    field :sequence_start_phase, :integer
    field :sequence_end_phase, :integer
    field :frequency, :integer
    field :frequency_buffer_hours, :integer
    field :maximum_banner_count, :integer
    field :banner_retry_buffer_hours, :integer
    field :is_active, :boolean

    belongs_to :media_piece, Qlarius.Sponster.Ads.MediaPiece
    belongs_to :media_sequence, Qlarius.Sponster.Campaigns.MediaSequence

    timestamps(type: :utc_datetime, inserted_at_source: :created_at)
  end

  @doc false
  def changeset(media_run, attrs) do
    media_run
    |> cast(attrs, [
      :frequency,
      :frequency_buffer_hours,
      :maximum_banner_count,
      :banner_retry_buffer_hours,
      :media_piece_id
    ])
    |> validate_required([
      :frequency,
      :frequency_buffer_hours,
      :maximum_banner_count,
      :banner_retry_buffer_hours,
      :media_piece_id
    ])
    |> validate_number(:frequency, greater_than: 0)
    |> validate_number(:frequency_buffer_hours, greater_than_or_equal_to: 0)
    |> validate_number(:maximum_banner_count, greater_than: 0)
    |> validate_number(:banner_retry_buffer_hours, greater_than_or_equal_to: 0)
  end
end
