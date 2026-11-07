defmodule Qlarius.Accounts.Users do
  @moduledoc """
  Lookups for users, proxies, and MeFiles.
  """

  import Ecto.Query

  alias Qlarius.Repo
  alias Qlarius.Accounts.{User, UserProxy}
  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.Sponster.Recipient

  def get_user(id) do
    Repo.get(User, id)
  end

  def get_user!(_id) do
    Repo.get!(User, 508)
  end

  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
  end

  def list_users do
    Repo.all(User)
  end

  def get_me_file(id) do
    Repo.get(MeFile, id)
    |> Repo.preload([:user, :ledger_header])
  end

  def get_user_me_file(user_id) do
    MeFile
    |> where([m], m.user_id == ^user_id)
    |> Repo.one()
    |> Repo.preload([:ledger_header])
  end

  def list_me_files do
    Repo.all(MeFile)
    |> Repo.preload([:user])
  end

  # Proxy user functions
  def list_proxy_users(user) do
    UserProxy
    |> where([p], p.true_user_id == ^user.id)
    |> join(:inner, [p], u in User, on: p.proxy_user_id == u.id)
    |> order_by([p, u], asc: u.alias)
    |> select([p, u], p)
    |> Repo.all()
  end

  def preload_proxy_users(proxies) do
    Repo.preload(proxies, [:proxy_user])
  end

  def get_active_proxy_user(user) do
    UserProxy
    |> where([p], p.true_user_id == ^user.id and p.active == true)
    |> Repo.one()
    |> Repo.preload([:proxy_user])
  end

  def update_user_proxy(%UserProxy{} = proxy, attrs) do
    proxy
    |> UserProxy.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Every proxy across all true users, ordered by proxy alias.
  """
  def list_all_proxies do
    UserProxy
    |> join(:inner, [p], u in assoc(p, :proxy_user), as: :proxy_user)
    |> order_by([proxy_user: u], asc: u.alias)
    |> preload([:true_user, proxy_user: :me_file])
    |> Repo.all()
  end

  def get_proxy!(id) do
    UserProxy
    |> Repo.get!(id)
    |> Repo.preload([:true_user, proxy_user: :me_file])
  end

  @doc """
  Saves a proxy's alias and its MeFile throttle together.
  """
  def update_proxy_details(%UserProxy{proxy_user: %User{me_file: %MeFile{}} = user}, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(
      :user,
      user
      |> User.changeset(Map.take(attrs, ["alias"]))
      |> Ecto.Changeset.unsafe_validate_unique(:alias, Repo)
    )
    |> Ecto.Multi.update(
      :me_file,
      MeFile.throttle_changeset(
        user.me_file,
        Map.take(attrs, ["throttle_ad_count", "throttle_days"])
      )
    )
    |> Repo.transaction()
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, _step, changeset, _changes} -> {:error, changeset}
    end
  end

  @doc """
  Retrieves a recipient by its split_code.
  """
  def get_recipient_by_split_code(nil), do: nil

  def get_recipient_by_split_code(split_code) do
    Repo.get_by(Recipient, split_code: split_code)
  end

  @doc """
  Retrieves a recipient by its ID.
  """
  def get_recipient_by_id(id) do
    Repo.get(Recipient, id)
  end
end
