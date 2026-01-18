defmodule Qlarius.Sponster.Ads.MediaPieceType do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at]

  schema "media_piece_types" do
    field :name, :string
    field :desc, :string
    field :ad_phase_count_to_complete, :integer
    field :base_fee, :decimal
    field :markup_multiplier, :decimal

    has_many :media_piece_phases, Qlarius.Sponster.Ads.MediaPiecePhase

    timestamps()
  end

  def changeset(media_piece_type, attrs) do
    media_piece_type
    |> cast(attrs, [
      :name,
      :desc,
      :ad_phase_count_to_complete,
      :base_fee,
      :markup_multiplier
    ])
    |> validate_required([
      :name,
      :ad_phase_count_to_complete,
      :base_fee,
      :markup_multiplier
    ])
    |> validate_number(:base_fee, greater_than_or_equal_to: 0)
    |> validate_number(:markup_multiplier, greater_than: 0)
  end
end
