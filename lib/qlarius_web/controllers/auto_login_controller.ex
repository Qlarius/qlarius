defmodule QlariusWeb.AutoLoginController do
  use QlariusWeb, :controller

  alias Qlarius.Accounts
  alias QlariusWeb.UserAuth

  plug :put_secure_browser_headers
  plug :accepts, ["html"]

  def create(conn, %{"token" => token}) do
    case Accounts.get_user_by_login_token(token) do
      nil ->
        conn
        |> put_flash(:error, "Invalid or expired login link")
        |> redirect(to: ~p"/login")

      user ->
        UserAuth.log_in_user(conn, user)
    end
  end
end
