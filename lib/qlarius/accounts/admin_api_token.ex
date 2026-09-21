defmodule Qlarius.Accounts.AdminApiToken do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Accounts.User

  schema "admin_api_tokens" do
    field :token_hash, :string
    field :label, :string
    field :last_used_at, :utc_datetime
    field :revoked_at, :utc_datetime

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  def changeset(token, attrs) do
    token
    |> cast(attrs, [:user_id, :token_hash, :label])
    |> validate_required([:user_id, :token_hash, :label])
    |> unique_constraint(:token_hash)
    |> foreign_key_constraint(:user_id)
  end
end
