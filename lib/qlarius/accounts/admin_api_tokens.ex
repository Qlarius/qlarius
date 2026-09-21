defmodule Qlarius.Accounts.AdminApiTokens do
  @moduledoc """
  Bearer tokens for the admin catalog API.

  Only the SHA-256 hash is stored. The raw token is returned once from `issue/2`.
  """

  import Ecto.Query

  alias Qlarius.Accounts.AdminApiToken
  alias Qlarius.Accounts.User
  alias Qlarius.Repo

  def issue(%User{role: "admin"} = user, label) when is_binary(label) do
    raw = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

    case %AdminApiToken{}
         |> AdminApiToken.changeset(%{
           user_id: user.id,
           token_hash: hash(raw),
           label: String.trim(label)
         })
         |> Repo.insert() do
      {:ok, token} -> {:ok, token, raw}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def issue(%User{}, _label), do: {:error, :not_admin}

  def authenticate(raw) when is_binary(raw) do
    token =
      AdminApiToken
      |> where([t], t.token_hash == ^hash(raw) and is_nil(t.revoked_at))
      |> preload(:user)
      |> Repo.one()

    case token do
      %{user: %{role: "admin"} = user} = token ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        Repo.update_all(from(t in AdminApiToken, where: t.id == ^token.id),
          set: [last_used_at: now]
        )

        {:ok, user}

      %{user: %User{}} ->
        {:error, :forbidden}

      _ ->
        :error
    end
  end

  def authenticate(_), do: :error

  def revoke(id) do
    case Repo.get(AdminApiToken, id) do
      nil ->
        {:error, :not_found}

      token ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        token
        |> Ecto.Changeset.change(%{revoked_at: now})
        |> Repo.update()
    end
  end

  defp hash(raw) do
    :crypto.hash(:sha256, raw) |> Base.encode16(case: :lower)
  end
end
