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
    |> cast(attrs, [
      :user_id,
      :content_id,
      :tiqit_type_id,
      :purchased_at,
      :expires_at
    ])
    |> validate_required([
      :user_id,
      :content_id,
      :tiqit_type_id,
      :purchased_apurchased_at,
      :expires_at
    ])
    |> assoc_constraint(:user)
    |> assoc_constraint(:content)
    |> assoc_constraint(:tiqit_type)
  end
end
