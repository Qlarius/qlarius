defmodule Qlarius.Arcade.TiqitType do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tiqit_types" do
    field :name, :string
    field :duration_seconds, :integer
    field :price, :decimal
    field :active, :boolean, default: true

    belongs_to :content, Qlarius.Arcade.Content
    has_many :tiqits, Qlarius.Arcade.Tiqit

    timestamps()
  end

  def changeset(tiqit_type, attrs) do
    tiqit_type
    |> cast(attrs, [:content_id, :name, :duration_seconds, :price, :active])
    |> validate_required([:content_id, :name, :duration_seconds, :price, :active])
    |> validate_length(:name, max: 50)
    |> assoc_constraint(:content)
  end
end
