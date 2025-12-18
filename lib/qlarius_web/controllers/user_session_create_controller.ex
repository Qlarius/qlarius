defmodule QlariusWeb.UserSessionCreateController do
  use QlariusWeb, :controller

  alias Qlarius.Accounts
  alias QlariusWeb.UserAuth

  def create(conn, %{"user_id" => user_id, "remember_me" => remember_me}) do
    user = Accounts.get_user!(user_id)
    params = %{"remember_me" => remember_me}
    UserAuth.log_in_user(conn, user, params)
  end

  def create(conn, %{"user_id" => user_id}) do
    user = Accounts.get_user!(user_id)
    UserAuth.log_in_user(conn, user, %{})
  end
end
