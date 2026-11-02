defmodule Qlarius.Tiqit.PlaybackPosition do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Tiqit.Arcade.ContentPiece
  alias Qlarius.Tiqit.Arcade.Tiqit

  schema "content_playback_positions" do
    field :position_seconds, :integer, default: 0
    field :duration_seconds, :integer
    field :completed_at, :utc_datetime

    belongs_to :tiqit, Tiqit
    belongs_to :content_piece, ContentPiece

    timestamps(type: :utc_datetime)
  end

  def changeset(position, attrs) do
    position
    |> cast(attrs, [
      :tiqit_id,
      :content_piece_id,
      :position_seconds,
      :duration_seconds,
      :completed_at
    ])
    |> validate_required([:tiqit_id, :content_piece_id, :position_seconds])
    |> validate_number(:position_seconds, greater_than_or_equal_to: 0)
    |> unique_constraint([:tiqit_id, :content_piece_id])
    |> foreign_key_constraint(:tiqit_id)
    |> foreign_key_constraint(:content_piece_id)
  end
end
