defmodule Qlarius.Accounts.Proxying do
  import Ecto.Query

  alias Qlarius.Accounts.User
  alias Qlarius.Accounts.UserProxy
  alias Qlarius.Repo

  def list_proxy_users(user) do
    UserProxy
    |> where([p], p.true_user_id == ^user.id)
    |> join(:inner, [p], u in User, on: p.proxy_user_id == u.id)
    |> order_by([p, u], asc: u.username)
    |> select([p, u], p)
    |> preload(:proxy_user)
    |> Repo.all()
  end

  def get_active_proxy_user(user) do
    UserProxy
    |> where([p], p.true_user_id == ^user.id and p.active == true)
    |> preload(:proxy_user)
    |> Repo.one()
  end

  def update_user_proxy(%UserProxy{} = proxy, attrs) do
    proxy
    |> UserProxy.changeset(attrs)
    |> Repo.update()
  end

  def set_active_user_proxy(true_user, proxy_id) do
    proxies_query = from(p in UserProxy, where: p.true_user_id == ^true_user.id)

    Repo.transaction(fn ->
      Repo.update_all(proxies_query, set: [active: false])

      proxies_query
      |> where([p], p.id == ^proxy_id)
      |> preload(:proxy_user)
      |> Repo.one!()
      |> Ecto.Changeset.change(%{active: true})
      |> Repo.update!()
    end)
  end
end
