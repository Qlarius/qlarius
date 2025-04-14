defmodule Qlarius.Legacy do
  @moduledoc """
  Context for interacting with the legacy Rails database.
  """

  import Ecto.Query

  alias Qlarius.LegacyRepo
  alias Qlarius.Legacy.{User, MeFile, UserProxy}

  def get_user(id) do
    LegacyRepo.get(User, id)
  end

  def get_user!(_id) do
    LegacyRepo.get!(User, 508)
  end

  def get_user_by_email(email) do
    LegacyRepo.get_by(User, email: email)
  end

  def list_users do
    LegacyRepo.all(User)
  end

  def get_me_file(id) do
    LegacyRepo.get(MeFile, id)
    |> LegacyRepo.preload([:user, :ledger_header])
  end

  def get_user_me_file(user_id) do
    MeFile
    |> where([m], m.user_id == ^user_id)
    |> LegacyRepo.one()
    |> LegacyRepo.preload([:ledger_header])
  end

  def list_me_files do
    LegacyRepo.all(MeFile)
    |> LegacyRepo.preload([:user])
  end

  # Proxy user functions
  def list_proxy_users(user) do
    UserProxy
    |> where([p], p.true_user_id == ^user.id)
    |> join(:inner, [p], u in User, on: p.proxy_user_id == u.id)
    |> order_by([p, u], asc: u.username)
    |> select([p, u], p)
    |> LegacyRepo.all()
  end

  def preload_proxy_users(proxies) do
    LegacyRepo.preload(proxies, [:proxy_user])
  end

  def get_active_proxy_user(user) do
    UserProxy
    |> where([p], p.true_user_id == ^user.id and p.active == true)
    |> LegacyRepo.one()
    |> LegacyRepo.preload([:proxy_user])
  end

  def update_user_proxy(%UserProxy{} = proxy, attrs) do
    proxy
    |> UserProxy.changeset(attrs)
    |> LegacyRepo.update()
  end
end
