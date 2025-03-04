defmodule Qlarius.Offer do
  use Ecto.Schema

  schema "offers" do
    # In the Rails app these two fields come from associated records,
    # but I'm putting them in here for now:
    field :phase_1_amount, :decimal
    field :phase_2_amount, :decimal

    field :amount, :decimal

    belongs_to :user, Qlarius.Accounts.User
    belongs_to :media_piece, Qlarius.MediaPiece

    timestamps()
  end
end
