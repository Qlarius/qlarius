defmodule Qlarius.Auth do
  import Ecto.Query
  alias Qlarius.Repo
  alias Qlarius.Accounts.{User, UserDevice}

  def get_user_by_phone(phone_number) do
    normalized = normalize_phone(phone_number)
    hash = hash_phone(normalized)

    Repo.get_by(User, mobile_number_hash: hash)
  end

  def create_user_with_phone(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def register_webauthn_credential(user, attrs) do
    %UserDevice{}
    |> UserDevice.changeset(Map.put(attrs, :user_id, user.id))
    |> Repo.insert()
  end

  def get_user_devices(user) do
    from(d in UserDevice,
      where: d.user_id == ^user.id,
      order_by: [desc: d.last_used_at]
    )
    |> Repo.all()
  end

  def get_device_by_credential_id(credential_id) do
    Repo.get_by(UserDevice, credential_id: credential_id)
  end

  def update_device_usage(device) do
    device
    |> UserDevice.update_usage_changeset()
    |> Repo.update()
  end

  def normalize_phone(phone) do
    case ExPhoneNumber.parse(phone, "US") do
      {:ok, parsed} -> ExPhoneNumber.format(parsed, :e164)
      {:error, _} -> phone
    end
  end

  defp hash_phone(phone) do
    :crypto.hash(:sha256, phone)
  end
end
