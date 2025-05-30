defmodule Qlarius.Sponster.Ads.MediaPiecePhase do
  use Ecto.Schema
  import Ecto.Changeset

  schema "media_piece_phases" do
    field :phase, :integer
    field :name, :string
    field :desc, :string
    field :is_final_phase, :boolean, default: false
    field :pay_to_me_file_fixed, :decimal
    field :pay_to_me_file_percent, :decimal
    field :pay_to_sponster_fixed, :decimal
    field :pay_to_sponster_percent, :decimal
    field :pay_to_recipient_from_sponster_fixed, :decimal
    field :pay_to_recipient_from_sponster_percent, :decimal
    field :pay_to_recipient_from_me_file_fixed, :decimal
    field :pay_to_recipient_from_me_file_percent, :decimal

    belongs_to :media_piece_type, Qlarius.Sponster.Ads.MediaPieceType

    timestamps(type: :utc_datetime, inserted_at_source: :created_at)
  end

  def changeset(media_piece_phase, attrs) do
    media_piece_phase
    |> cast(attrs, [
      :media_piece_type_id,
      :phase,
      :name,
      :desc,
      :is_final_phase,
      :pay_to_me_file_fixed,
      :pay_to_me_file_percent,
      :pay_to_sponster_fixed,
      :pay_to_sponster_percent,
      :pay_to_recipient_from_sponster_fixed,
      :pay_to_recipient_from_sponster_percent,
      :pay_to_recipient_from_me_file_fixed,
      :pay_to_recipient_from_me_file_percent
    ])
    |> validate_required([
      :media_piece_type_id,
      :phase,
      :name
    ])
  end
end
