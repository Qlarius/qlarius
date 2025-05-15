defmodule Qlarius.Marketing.MediaPieceType do
  use Ecto.Schema
  import Ecto.Changeset

  schema "media_piece_types" do
    field :name, :string
    field :desc, :string
    field :ad_phase_count_to_complete, :integer

    has_many :media_piece_phases, Qlarius.Marketing.MediaPiecePhase

    timestamps(type: :utc_datetime, inserted_at_source: :created_at)
  end

  def changeset(media_piece_type, attrs) do
    media_piece_type
    |> cast(attrs, [
      :name,
      :desc,
      :ad_phase_count_to_complete
    ])
    |> validate_required([
      :name,
      :ad_phase_count_to_complete
    ])
  end
end
