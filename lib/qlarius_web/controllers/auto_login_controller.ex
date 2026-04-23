defmodule QlariusWeb.AutoLoginController do
  use QlariusWeb, :controller

  alias Qlarius.Accounts
  alias Qlarius.Qlink.Urls
  alias QlariusWeb.UserAuth

  plug :put_secure_browser_headers
  plug :accepts, ["html"]

  def create(conn, %{"token" => token} = params) do
    case Accounts.get_user_by_login_token(token) do
      nil ->
        conn
        |> put_flash(:error, "Invalid or expired login link")
        |> redirect(to: ~p"/login")

      user ->
        conn
        |> maybe_put_return_to(params)
        |> UserAuth.log_in_user(user, %{"remember_me" => "true"})
    end
  end

  # `?return_to=<local-path>` pass-through sanitized at the controller
  # boundary. When present, overwrites any implicit `:user_return_to`
  # so the post-login redirect lands on the intended page (e.g. a
  # creator's Qlink page on the interact host after cross-domain
  # "Connect your wallet" handoff from qlinkin.bio).
  defp maybe_put_return_to(conn, %{"return_to" => path}) do
    case Urls.sanitize_return_to(path) do
      nil -> conn
      safe -> put_session(conn, :user_return_to, safe)
    end
  end

  defp maybe_put_return_to(conn, _params), do: conn
end
