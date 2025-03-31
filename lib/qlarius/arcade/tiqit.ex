defmodule Qlarius.Arcade.Tiqit do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tickets" do
    field :purchase_timestamp, :utc_datetime
    field :expiration_timestamp, :utc_datetime
    field :is_active, :boolean, default: true

    belongs_to :user, Qlarius.Accounts.User
    belongs_to :content, Qlarius.Arcade.Content
    belongs_to :tiqit_type, Qlarius.Arcade.TiqitType

    timestamps()
  end

  def changeset(tiqit, attrs) do
    tiqit
    |> cast(attrs, [
      :user_id,
      :content_id,
      :tiqit_type_id,
      :purchase_timestamp,
      :expiration_timestamp,
      :is_active
    ])
    |> validate_required([
      :user_id,
      :content_id,
      :tiqit_type_id,
      :purchase_timestamp,
      :expiration_timestamp,
      :is_active
    ])
    |> assoc_constraint(:user)
    |> assoc_constraint(:content)
    |> assoc_constraint(:tiqit_type)
  end
end
