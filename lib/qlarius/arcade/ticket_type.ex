defmodule Qlarius.Arcade.TicketType do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ticket_types" do
    field :name, :string
    field :duration_seconds, :integer
    field :price, :decimal
    field :is_active, :boolean, default: true

    belongs_to :content, Qlarius.Arcade.Content
    has_many :tickets, Qlarius.Arcade.Ticket

    timestamps()
  end

  def changeset(ticket_type, attrs) do
    ticket_type
    |> cast(attrs, [:content_id, :name, :duration_seconds, :price, :is_active])
    |> validate_required([:content_id, :name, :duration_seconds, :price, :is_active])
    |> validate_length(:name, max: 50)
    |> assoc_constraint(:content)
  end
end
