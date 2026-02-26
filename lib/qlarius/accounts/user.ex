defmodule Qlarius.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Qlarius.Accounts.UserProxy
  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.Creators.Creator
  alias Qlarius.Creators.CreatorMembership

  @primary_key {:id, :id, autogenerate: true}

  schema "users" do
    field :alias, :string
    field :referrer_code, :string
    field :role, :string
    field :mobile_number_encrypted, Qlarius.Encrypted.Binary
    field :mobile_number_hash, :binary
    field :phone_verified_at, :utc_datetime
    field :last_sign_in_at, :utc_datetime
    field :last_sign_in_ip, :string
    field :last_sign_in_user_agent, :string
    field :pwa_installed, :boolean, default: false
    field :pwa_installed_at, :utc_datetime
    field :pwa_install_dismissed_at, :utc_datetime
    field :timezone, :string, default: "America/New_York"
    field :fleet_after_hours, :integer, default: 24

    has_one :me_file, MeFile

    has_many :proxy_users, UserProxy, foreign_key: :true_user_id
    has_many :proxied_by, UserProxy, foreign_key: :proxy_user_id

    many_to_many :creators, Creator, join_through: CreatorMembership

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:alias, :role, :timezone, :fleet_after_hours])
    |> validate_required([:alias])
    |> validate_inclusion(:timezone, Qlarius.Timezones.list() |> Enum.map(fn {_label, iana} -> iana end))
    |> validate_number(:fleet_after_hours, greater_than_or_equal_to: 0, less_than_or_equal_to: 720)
    |> unique_constraint(:alias)
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:alias, :role])
    |> validate_required([:alias])
    |> unique_constraint(:alias)
    |> unique_constraint(:mobile_number_hash)
    |> maybe_encrypt_mobile_number(attrs)
  end

  defp maybe_encrypt_mobile_number(changeset, attrs) do
    case Map.get(attrs, "mobile_number") || Map.get(attrs, :mobile_number) do
      nil ->
        changeset

      "" ->
        changeset

      phone when is_binary(phone) ->
        normalized_phone = normalize_phone(phone)

        changeset
        |> put_change(:mobile_number_encrypted, normalized_phone)
        |> put_change(:mobile_number_hash, hash_phone(normalized_phone))

      _ ->
        changeset
    end
  end

  defp normalize_phone(phone) do
    case ExPhoneNumber.parse(phone, "US") do
      {:ok, parsed_number} ->
        if ExPhoneNumber.is_valid_number?(parsed_number) do
          ExPhoneNumber.format(parsed_number, :e164)
        else
          phone
        end

      {:error, _} ->
        phone
    end
  end

  defp hash_phone(phone) do
    :crypto.hash(:sha256, phone)
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
