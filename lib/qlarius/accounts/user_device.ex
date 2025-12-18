defmodule Qlarius.Accounts.UserDevice do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Accounts.User

  schema "user_devices" do
    field :credential_id, :binary
    field :public_key, :binary
    field :sign_count, :integer, default: 0
    field :device_name, :string
    field :device_type, :string
    field :last_used_at, :utc_datetime
    field :trusted, :boolean, default: false

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  def changeset(device, attrs) do
    device
    |> cast(attrs, [:user_id, :credential_id, :public_key, :sign_count, :device_name, :device_type, :last_used_at, :trusted])
    |> validate_required([:user_id, :credential_id, :public_key])
    |> unique_constraint(:credential_id)
    |> foreign_key_constraint(:user_id)
  end

  def update_usage_changeset(device) do
    device
    |> change()
    |> put_change(:last_used_at, DateTime.utc_now())
    |> update_change(:sign_count, &(&1 + 1))
  end
end
