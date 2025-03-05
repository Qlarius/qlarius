defmodule Qlarius.Marketing.MediaRun do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Marketing.MediaPiece
  alias Qlarius.Marketing.MediaSequence

  schema "media_runs" do
    field :frequency, :integer
    field :frequency_buffer_hours, :integer
    field :maximum_banner_count, :integer
    field :banner_retry_buffer_hours, :integer

    belongs_to :media_piece, MediaPiece
    belongs_to :media_sequence, MediaSequence

    timestamps()
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
