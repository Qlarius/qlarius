defmodule Qlarius.Arcade.TiqitType do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ticket_types" do
    field :name, :string
    field :duration_seconds, :integer
    field :price, :decimal
    field :is_active, :boolean, default: true

    belongs_to :content, Qlarius.Arcade.Content
    has_many :tiqits, Qlarius.Arcade.Tiqit

    timestamps()
  end

  def changeset(tiqit_type, attrs) do
    tiqit_type
    |> cast(attrs, [:content_id, :name, :duration_seconds, :price, :is_active])
    |> validate_required([:content_id, :name, :duration_seconds, :price, :is_active])
    |> validate_length(:name, max: 50)
    |> assoc_constraint(:content)
  end
end
