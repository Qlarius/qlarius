defmodule Qlarius.X.Accounts.UserProxy do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_proxies" do
    field :active, :boolean, default: false
    belongs_to :true_user, Qlarius.Accounts.User
    belongs_to :proxy_user, Qlarius.Accounts.User

    timestamps()
  end

  @doc """
  Changeset for user_proxy.
  """
  def changeset(user_proxy, attrs) do
    user_proxy
    |> cast(attrs, [:active, :true_user_id, :proxy_user_id])
    |> validate_required([:active, :true_user_id, :proxy_user_id])
    |> foreign_key_constraint(:true_user_id)
    |> foreign_key_constraint(:proxy_user_id)
    |> unique_constraint([:true_user_id, :proxy_user_id])
  end
end
