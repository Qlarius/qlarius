defmodule QlariusWeb.UserAuth do
  use QlariusWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias Qlarius.Accounts
  alias Qlarius.Accounts.Scope

  @remember_me_cookie "_qlarius_web_user_remember_me"
  @remember_me_options [sign: true, max_age: 60 * 60 * 24 * 60, same_site: "Lax"]

  def log_in_user(conn, user, params \\ %{}) do
    token = Accounts.generate_user_session_token(user)
    user_return_to = get_session(conn, :user_return_to)

    conn =
      conn
      |> renew_session()
      |> put_token_in_session(token)
      |> maybe_write_remember_me_cookie(token, params)
      |> track_sign_in(user)

    if user_return_to do
      redirect(conn, to: user_return_to)
    else
      redirect(conn, to: ~p"/")
    end
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}) do
    put_resp_cookie(conn, @remember_me_cookie, token, @remember_me_options)
  end

  defp maybe_write_remember_me_cookie(conn, _token, _params) do
    conn
  end

  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  defp track_sign_in(conn, user) do
    ip = get_peer_data(conn).address |> :inet.ntoa() |> to_string()
    user_agent = get_req_header(conn, "user-agent") |> List.first()

    Accounts.update_user_sign_in_tracking(user, %{
      last_sign_in_at: DateTime.utc_now() |> DateTime.truncate(:second),
      last_sign_in_ip: ip,
      last_sign_in_user_agent: user_agent
    })

    conn
  end

  def log_out_user(conn) do
    user_token = get_session(conn, :user_token)
    user_token && Accounts.delete_user_session_token(user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      QlariusWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: ~p"/login")
  end

  def fetch_current_scope_for_user(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)
    user = user_token && Accounts.get_user_by_session_token(user_token)

    scope = if user, do: Scope.for_user(user), else: nil

    assign(conn, :current_scope, scope)
  end

  defp ensure_user_token(conn) do
    if token = get_session(conn, :user_token) do
      {token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if token = conn.cookies[@remember_me_cookie] do
        {token, put_token_in_session(conn, token)}
      else
        {nil, conn}
      end
    end
  end

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
  end

  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_scope] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_scope] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/login")
      |> halt()
    end
  end

  def require_admin_user(conn, _opts) do
    scope = conn.assigns[:current_scope]

    if scope && scope.true_user && scope.true_user.role == "admin" do
      conn
    else
      conn
      |> put_flash(:error, "You must be an admin to access this page.")
      |> redirect(to: ~p"/")
      |> halt()
    end
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp signed_in_path(_conn), do: ~p"/"

  def on_mount(:mount_current_scope, _params, session, socket) do
    {:cont, mount_current_scope(socket, session)}
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if socket.assigns.current_scope && socket.assigns.current_scope.true_user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/login")

      {:halt, socket}
    end
  end

  def on_mount(:ensure_admin, _params, session, socket) do
    socket = mount_current_scope(socket, session)
    scope = socket.assigns[:current_scope]

    if scope && scope.true_user && scope.true_user.role == "admin" do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must be an admin to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/")

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if socket.assigns.current_scope && socket.assigns.current_scope.true_user do
      {:halt, Phoenix.LiveView.redirect(socket, to: signed_in_path(socket))}
    else
      {:cont, socket}
    end
  end

  def on_mount(:require_initialized_mefile, _params, _session, socket) do
    user = socket.assigns.current_scope.user
    me_file = user.me_file

    if is_nil(me_file) || !Qlarius.YouData.MeFiles.is_initialized?(me_file) do
      {:halt,
       socket
       |> Phoenix.LiveView.put_flash(:info, "Please complete your registration")
       |> Phoenix.LiveView.push_navigate(to: ~p"/register")}
    else
      {:cont, socket}
    end
  end

  def on_mount(:require_admin_or_proxy, _params, _session, socket) do
    scope = socket.assigns.current_scope

    if scope.true_user.role == "admin" || scope.proxy? do
      {:cont, socket}
    else
      {:halt,
       socket
       |> Phoenix.LiveView.put_flash(:error, "Unauthorized access")
       |> Phoenix.LiveView.push_navigate(to: ~p"/")}
    end
  end

  defp mount_current_scope(socket, session) do
    socket
    |> Phoenix.Component.assign_new(:current_scope, fn ->
      user_token = session["user_token"]
      user = user_token && Accounts.get_user_by_session_token(user_token)

      if user do
        Scope.for_user(user)
      else
        nil
      end
    end)
    |> Phoenix.Component.assign_new(:is_mobile, fn ->
      Map.get(session, "is_mobile", false)
    end)
  end
end
