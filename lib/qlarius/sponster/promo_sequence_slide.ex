defmodule Qlarius.Sponster.PromoSequenceSlide do
  use Ecto.Schema
  import Ecto.Changeset

  schema "promo_sequence_slides" do
    field :track, :string
    field :position, :integer
    field :image, :string

    belongs_to :promo_sequence, Qlarius.Sponster.PromoSequence

    timestamps(type: :utc_datetime)
  end

  def changeset(slide, attrs) do
    slide
    |> cast(attrs, [:promo_sequence_id, :track, :position, :image])
    |> validate_required([:promo_sequence_id, :track, :position, :image])
    |> validate_inclusion(:track, ["wide", "narrow"])
    |> validate_number(:position, greater_than: 0)
    |> unique_constraint([:promo_sequence_id, :track, :position])
  end
end
