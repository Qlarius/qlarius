defmodule Qlarius.Arcade.Tiqit do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Accounts.User
  alias Qlarius.Arcade.TiqitType

  schema "tiqits" do
    field :purchased_at, :utc_datetime
    field :expires_at, :utc_datetime

    belongs_to :user, User
    belongs_to :tiqit_type, TiqitType

    has_one :content, through: [:tiqit_type, :content]

    timestamps()
  end

  def changeset(tiqit, attrs) do
    tiqit
    |> cast(attrs, ~w[purchased_at expires_at]a)
    |> validate_required(~w[purchased_at expires_at]a)
  end
end
