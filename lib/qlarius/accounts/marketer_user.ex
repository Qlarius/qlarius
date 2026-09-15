defmodule Qlarius.Accounts.MarketerUser do
  @moduledoc """
  Membership of a user in a marketer org. The direct counterpart of
  `Qlarius.Creators.CreatorMembership` — same roles, same invite fields, same
  uniqueness rule — so authorization logic reads identically on both sides.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "marketer_users" do
    belongs_to :user, Qlarius.Accounts.User
    belongs_to :marketer, Qlarius.Accounts.Marketer

    field :role, Ecto.Enum,
      values: [:owner, :admin, :member],
      default: :owner

    field :invited_by_id, :id
    field :accepted_at, :utc_datetime

    timestamps(type: :utc_datetime, inserted_at_source: :created_at)
  end

  @doc false
  def changeset(marketer_user, attrs) do
    marketer_user
    |> cast(attrs, [:user_id, :marketer_id, :role, :invited_by_id, :accepted_at])
    |> validate_required([:user_id, :marketer_id, :role])
    |> unique_constraint([:user_id, :marketer_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:marketer_id)
  end
end
