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
      |> join(:inner, [t], u in assoc(t, :user))
      |> where([t], t.token_hash == ^hash(raw) and is_nil(t.revoked_at))
      |> preload([_t, u], user: u)
      |> Repo.one()

    case token do
      %{user: %{role: "admin"} = user} = token ->
        touch_last_used(token)
        {:ok, user, token}

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

  # A burst of reads was updating this column on every call. Once a minute is
  # enough to see that the token is still in use, and it keeps the write off
  # the hot path.
  defp touch_last_used(%{id: id, last_used_at: last}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    if is_nil(last) or DateTime.diff(now, last, :second) >= 60 do
      Repo.update_all(from(t in AdminApiToken, where: t.id == ^id), set: [last_used_at: now])
    end

    :ok
  end

  defp hash(raw) do
    :crypto.hash(:sha256, raw) |> Base.encode16(case: :lower)
  end
end
