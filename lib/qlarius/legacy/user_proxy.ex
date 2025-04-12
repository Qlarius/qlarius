defmodule Qlarius.Legacy.UserProxy do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Legacy.User

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at, updated_at: :updated_at]

  schema "user_proxies" do
    field :active, :boolean, default: false
    belongs_to :true_user, User, foreign_key: :true_user_id
    belongs_to :proxy_user, User, foreign_key: :proxy_user_id

    timestamps()
  end

  def changeset(user_proxy, attrs) do
    user_proxy
    |> cast(attrs, [:true_user_id, :proxy_user_id, :active])
    |> validate_required([:true_user_id, :proxy_user_id])
    |> foreign_key_constraint(:true_user_id)
    |> foreign_key_constraint(:proxy_user_id)
    |> unique_constraint([:true_user_id, :proxy_user_id])
  end
end
