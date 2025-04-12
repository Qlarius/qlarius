defmodule Qlarius.Legacy.User do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Qlarius.Legacy.UserProxy
  alias Qlarius.Repo

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at, updated_at: :updated_at]

  schema "users" do
    field :username, :string
    field :email, :string
    field :encrypted_password, :string
    field :reset_password_token, :string
    field :reset_password_sent_at, :naive_datetime
    field :remember_created_at, :naive_datetime
    field :sign_in_count, :integer, default: 0
    field :current_sign_in_at, :naive_datetime
    field :last_sign_in_at, :naive_datetime
    field :current_sign_in_ip, :string
    field :last_sign_in_ip, :string
    field :confirmation_token, :string
    field :confirmed_at, :naive_datetime
    field :confirmation_sent_at, :naive_datetime
    field :unconfirmed_email, :string
    field :failed_attempts, :integer, default: 0
    field :unlock_token, :string
    field :locked_at, :naive_datetime
    field :authentication_token, :string
    field :referrer_code, :string
    field :role, :string
    field :passage_id, :string
    field :mobile_number, :string

    has_many :me_files, Qlarius.Legacy.MeFile
    has_many :marketer_users, Qlarius.Legacy.MarketerUser
    has_many :marketers, through: [:marketer_users, :marketer]
    has_one :user_pref, Qlarius.Legacy.UserPref

    # Proxy associations matching Rails model
    has_many :proxy_users, UserProxy, foreign_key: :true_user_id
    has_many :proxied_by, UserProxy, foreign_key: :proxy_user_id

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :email, :encrypted_password, :role, :mobile_number])
    |> validate_required([:username, :email, :encrypted_password])
    |> unique_constraint(:email)
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

    case Qlarius.LegacyRepo.one(query) do
      nil -> user
      proxy_user -> proxy_user
    end
  end
end
