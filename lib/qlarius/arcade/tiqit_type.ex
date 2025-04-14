defmodule Qlarius.Arcade.TiqitType do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Arcade.ContentPiece
  alias Qlarius.Arcade.Tiqit

  schema "tiqit_types" do
    field :name, :string
    # if duration_hours is null then tiqit doesn't expire
    field :duration_hours, :integer
    field :price, :decimal
    field :active, :boolean, default: true

    belongs_to :content_piece, ContentPiece
    has_many :tiqits, Tiqit

    timestamps()
  end

  def changeset(tt, params) do
    tt
    |> cast(params, ~w[name duration_hours price]a)
    |> validate_required([:name, :price])
    |> validate_number(:duration_hours, greater_than: 0)
    |> validate_number(:price, greater_than: 0)
  end
end
