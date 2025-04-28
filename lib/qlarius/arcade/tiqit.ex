defmodule Qlarius.Arcade.Tiqit do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Accounts.UserUnused, as: User
  alias Qlarius.Arcade.TiqitType

  schema "tiqits" do
    field :purchased_at, :utc_datetime
    field :expires_at, :utc_datetime

    belongs_to :user, User
    belongs_to :tiqit_type, TiqitType

    has_one :content_piece, through: [:tiqit_type, :content_piece]

    timestamps()
  end

  def changeset(tiqit, attrs) do
    tiqit
    |> cast(attrs, ~w[purchased_at expires_at]a)
    |> validate_required(~w[purchased_at]a)

    # TODO validate expires_at must be in future if present
  end
end
