defmodule Qlarius.Accounts.UserProxy do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Accounts.User

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at, updated_at: :updated_at]

  schema "user_proxies" do
    field :active, :boolean, default: false
    belongs_to :true_user, User
    belongs_to :proxy_user, User

    timestamps()
  end

  def changeset(user_proxy, attrs) do
    user_proxy
    |> cast(attrs, [:active])
    |> validate_required([:active])
  end
end
