defmodule Qlarius.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Qlarius.Accounts.UserProxy
  alias Qlarius.YouData.MeFiles.MeFile

  @primary_key {:id, :id, autogenerate: true}

  schema "users" do
    field :username, :string
    field :alias, :string
    field :referrer_code, :string
    field :role, :string
    field :auth_provider_id, :string
    field :mobile_number, :string

    has_one :me_file, MeFile

    has_many :proxy_users, UserProxy, foreign_key: :true_user_id
    has_many :proxied_by, UserProxy, foreign_key: :proxy_user_id

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :alias, :mobile_number, :auth_provider_id, :role])
    |> validate_required([:alias])
    |> unique_constraint(:alias)
    |> unique_constraint(:username)
  end

  @doc """
  Returns either the active proxy user for this user, or the user themselves if no active proxy exists.
  """
  def active_proxy_user_or_self(%__MODULE__{} = user) do
    query =
      from up in UserProxy,
        where: up.true_user_id == ^user.id and up.active == true,
        join: proxy in assoc(up, :proxy_user),
        limit: 1,
        select: proxy

    case Qlarius.Repo.one(query) do
      nil -> user
      proxy_user -> proxy_user
    end
  end
end
