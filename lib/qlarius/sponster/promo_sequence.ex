defmodule Qlarius.Sponster.PromoSequence do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.ApiRef

  schema "promo_sequences" do
    field :name, :string
    field :api_ref, :string
    field :global, :boolean, default: false
    field :is_default, :boolean, default: false
    field :max_height, :integer, default: 80
    field :bounce_image, :string

    has_many :slides, Qlarius.Sponster.PromoSequenceSlide

    timestamps(type: :utc_datetime)
  end

  def changeset(sequence, attrs) do
    sequence
    |> cast(attrs, [:name, :api_ref, :global, :is_default, :max_height, :bounce_image])
    |> validate_required([:name, :max_height])
    |> validate_length(:name, min: 1, max: 120)
    |> validate_number(:max_height, greater_than: 0, less_than_or_equal_to: 400)
    |> ApiRef.validate()
    |> unique_constraint(:is_default, name: :promo_sequences_one_default)
  end
end
