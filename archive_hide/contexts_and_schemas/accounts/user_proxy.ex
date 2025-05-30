defmodule Qlarius.Accounts.UserProxy do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Accounts.User

  schema "user_proxies" do
    field :active, :boolean, default: false
    belongs_to :true_user, User
    belongs_to :proxy_user, User

    timestamps(type: :utc_datetime_usec, inserted_at_source: :created_at)
  end

  def changeset(user_proxy, attrs) do
    user_proxy
    |> cast(attrs, [:active])
    |> validate_required([:active])
  end
end
