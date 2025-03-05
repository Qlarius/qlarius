defmodule Qlarius.Offer do
  use Ecto.Schema

  alias Qlarius.Accounts.User
  alias Qlarius.Campaigns.MediaPiece

  schema "offers" do
    # In the Rails app these two fields come from associated records,
    # but I'm putting them in here for now:
    field :phase_1_amount, :decimal
    field :phase_2_amount, :decimal

    field :amount, :decimal

    belongs_to :user, User
    belongs_to :media_piece, MediaPiece

    timestamps()
  end
end
