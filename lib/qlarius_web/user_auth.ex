defmodule QlariusWeb.UserAuth do
  use QlariusWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias Qlarius.Accounts
  alias Qlarius.Accounts.Scope
  alias QlariusWeb.Plugs.HostAwareSession

  @remember_me_cookie "_qlarius_web_user_remember_me"
  @remember_me_base_options [
    sign: true,
    max_age: 60 * 60 * 24 * 60,
    http_only: true
  ]

  # Remember-me cookie parity with the shared session cookie
  # (see `QlariusWeb.Plugs.HostAwareSession`): when the request is
  # served from a Qadabra-apex host the cookie is written with
  # `Domain=.qadabra.app` and `SameSite=None; Secure`, so a user who
  # checks "remember me" on `qlink.qadabra.app` stays signed in on
  # `qadabra.app` as well. On any other host (qlinkin.bio, localhost,
  # gigalixirapp.com, etc.) the cookie is host-scoped with
  # `SameSite=Lax`, matching the legacy behaviour.
  defp remember_me_options(conn) do
    if HostAwareSession.host_under_qadabra?(conn.host) do
      [
        domain: HostAwareSession.cross_subdomain_host(),
        same_site: "None",
        secure: true
      ] ++ @remember_me_base_options
    else
      [same_site: "Lax"] ++ @remember_me_base_options
    end
  end

  def log_in_user(conn, user, params \\ %{}) do
    user_return_to = get_session(conn, :user_return_to)

    conn = establish_user_session(conn, user, params)

    # Honor any `:user_return_to` in session. The implicit-store path
    # (`maybe_store_return_to/1`, below) still avoids stashing Qlink
    # `/@alias` paths so stale sessions don't redirect creators to
    # their own pages; but explicit return_to values — set by the
    # `AutoLoginController` from the sanitized `?return_to=` query
    # param — ARE trusted here, so cross-domain "Connect your wallet"
    # handoffs from `qlinkin.bio/@alias` land back on
    # `qlink.qadabra.app/@alias` after sign-in.
    if user_return_to do
      redirect(conn, to: user_return_to)
    else
      redirect(conn, to: ~p"/")
    end
  end

  @doc """
  Establishes an authenticated session for `user` *without* redirecting.

  This is the AuthSheet in-place sign-in path (see
  `docs/qlink_auth_refactor_plan.md` §5.9). After this call the conn has
  a fresh session cookie attached; the client then disconnects and
  reconnects its LiveView socket to pick up the new scope.

  Supported opts:

    * `:resume` — opaque resume intent string (e.g. `"tip:42"`). When
      provided, stashed in the session under `:qadabra_resume` so the
      post-reconnect LV mount can consume it.
    * `:remember_me` — boolean, writes the remember-me cookie (same
      semantics as `log_in_user/3`'s `"remember_me" => "true"` param).
  """
  def log_in_user_from_finalize(conn, user, opts \\ []) do
    remember_me_params =
      if Keyword.get(opts, :remember_me, true),
        do: %{"remember_me" => "true"},
        else: %{}

    conn = establish_user_session(conn, user, remember_me_params)

    case Keyword.get(opts, :resume) do
      nil -> conn
      "" -> conn
      resume when is_binary(resume) -> put_session(conn, :qadabra_resume, resume)
      _ -> conn
    end
  end

  # Shared session-establishment steps used by both the classic
  # `log_in_user/3` redirect path and the finalize/in-place path. Kept
  # private so callers can't skip `track_sign_in/2` or the remember-me
  # cookie wiring.
  defp establish_user_session(conn, user, params) do
    token = Accounts.generate_user_session_token(user)
    sync_id = persistent_session_sync_id(conn)

    conn
    |> renew_session()
    |> put_session(:session_sync_id, sync_id)
    |> put_token_in_session(token)
    |> maybe_write_remember_me_cookie(token, params)
    |> track_sign_in(user)
    |> tap(fn _conn -> QlariusWeb.SessionSync.broadcast(sync_id, :authed) end)
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}) do
    put_resp_cookie(conn, @remember_me_cookie, token, remember_me_options(conn))
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

  @doc """
  Clears the user's session (DB token, session cookie, remember-me
  cookie) and redirects to `/login` by default.

  Pass `to: "/some/path"` to redirect somewhere else after logout —
  used by the Qlink-page "Log out" surface to drop the visitor back on
  the same Qlink page as an anonymous viewer rather than bouncing
  them to the generic `/login` screen.
  """
  def log_out_user(conn, opts \\ []) do
    redirect_to = Keyword.get(opts, :to, ~p"/login")

    conn
    |> clear_user_session()
    |> redirect(to: redirect_to)
  end

  @doc """
  Clears the Phoenix session / remember-me cookies and DB session token
  without redirecting. Used by the extension remote-logout path so the
  service worker can fan out a global disconnect as `204`.
  """
  def clear_user_session(conn) do
    user_token = get_session(conn, :user_token)
    sync_id = persistent_session_sync_id(conn)
    live_socket_id = get_session(conn, :live_socket_id)

    # Invalidate the DB token first so any early sibling reconnect cannot
    # restore the user from a still-present cookie value.
    user_token && Accounts.delete_user_session_token(user_token)

    # PubSub WHILE sibling LiveViews are still alive. They push_event a
    # client reconnect. Broadcasting `live_socket_id` disconnect *before*
    # this kills those processes and the tipjar/ads_ext siblings never
    # learn about logout.
    QlariusWeb.SessionSync.broadcast(sync_id, :anonymous)

    conn =
      conn
      |> renew_session()
      |> put_session(:session_sync_id, sync_id)
      |> delete_resp_cookie(@remember_me_cookie, delete_remember_me_options(conn))

    # Backstop for stray tabs after SessionSync push_event has had time
    # to flush over the socket.
    if live_socket_id do
      Task.start(fn ->
        Process.sleep(400)
        QlariusWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
      end)
    end

    conn
  end

  # Survives `renew_session/1` (which clears the session) so sibling
  # widget iframes stay on the same PubSub auth bus across login/logout.
  defp persistent_session_sync_id(conn) do
    case get_session(conn, :session_sync_id) do
      id when is_binary(id) and id != "" -> id
      _ -> Ecto.UUID.generate()
    end
  end

  # `delete_resp_cookie` only evicts a cookie whose `Domain`, `Path`,
  # and `Secure` attributes match the original `Set-Cookie`. On a
  # Qadabra-apex host the remember-me cookie was written with
  # `Domain=.qadabra.app`, so the deletion header must mirror that —
  # otherwise the browser treats the clear-cookie directive as
  # targeting a different (host-scoped) cookie and leaves the real
  # cross-subdomain cookie intact, silently keeping the user signed
  # in after logout.
  defp delete_remember_me_options(conn) do
    if HostAwareSession.host_under_qadabra?(conn.host) do
      [domain: HostAwareSession.cross_subdomain_host(), secure: true]
    else
      []
    end
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
    mode = conn.params["mode"]

    if conn.assigns[:current_scope] && mode != "proxy" do
      conn
      |> redirect(to: already_signed_in_redirect_path(conn.params))
      |> halt()
    else
      conn
    end
  end

  # Honors `?return_to=` on the login entry point so already-logged-in
  # visitors arriving via a cross-domain CTA still land on the page
  # they were headed for, not the generic signed-in home page.
  defp already_signed_in_redirect_path(params) do
    case Qlarius.Qlink.Urls.sanitize_return_to(Map.get(params, "return_to")) do
      nil -> ~p"/home"
      path -> path
    end
  end

  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_scope] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/connect")
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
    path = current_path(conn)

    # Don't store public pages like Qlink pages as return destinations
    if String.starts_with?(path, "/@") do
      conn
    else
      put_session(conn, :user_return_to, path)
    end
  end

  defp maybe_store_return_to(conn), do: conn

  def on_mount(:mount_current_scope, _params, session, socket) do
    {:cont, mount_current_scope(socket, session)}
  end

  @doc """
  Forces `current_scope` to `nil` regardless of session contents. Used on the
  public vanity host (qlinkin.bio) so that Qlink pages there are provably
  anonymous — no branch of the UI can render authed state even if a stray
  session token somehow reached the host. Pair this with the :browser_anon
  router pipeline which omits `:fetch_current_scope_for_user`.
  """
  def on_mount(:mount_anonymous_scope, _params, _session, socket) do
    {:cont, Phoenix.Component.assign(socket, :current_scope, nil)}
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = mount_current_scope(socket, session)
    has_scope = !!socket.assigns.current_scope
    has_user = has_scope && !!socket.assigns.current_scope.true_user

    if has_user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/connect")

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

  def on_mount(:redirect_if_user_is_authenticated, params, session, socket) do
    socket = mount_current_scope(socket, session)
    mode = Map.get(params, "mode")

    if socket.assigns.current_scope && socket.assigns.current_scope.true_user && mode != "proxy" do
      {:halt, Phoenix.LiveView.redirect(socket, to: already_signed_in_redirect_path(params))}
    else
      {:cont, socket}
    end
  end

  def on_mount(:require_initialized_mefile, _params, _session, socket) do
    user = socket.assigns.current_scope.user
    me_file = user.me_file
    needs_redirect = is_nil(me_file) || !Qlarius.YouData.MeFiles.is_initialized?(me_file)

    if needs_redirect do
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
