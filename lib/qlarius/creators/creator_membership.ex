defmodule Qlarius.Creators.CreatorMembership do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Accounts.User
  alias Qlarius.Creators.Creator

  schema "creator_memberships" do
    belongs_to :user, User
    belongs_to :creator, Creator

    field :role, Ecto.Enum,
      values: [:owner, :admin, :member],
      default: :owner

    field :invited_by_id, :id
    field :accepted_at, :utc_datetime

    timestamps()
  end

  @doc false
  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:user_id, :creator_id, :role, :invited_by_id, :accepted_at])
    |> validate_required([:user_id, :creator_id, :role])
    |> unique_constraint([:user_id, :creator_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:creator_id)
  end
end
