defmodule QlariusWeb.UserAuth do
  use QlariusWeb, :verified_routes

  import Plug.Conn

  alias Qlarius.Accounts.Scope

  @hardcoded_user_id 508

  @doc """
  Authenticates the user by looking into the session
  and remember me token.
  """
  def fetch_current_scope_for_user(conn, _opts) do
    alias Qlarius.Repo

    user =
      Qlarius.Accounts.User
      |> Repo.get!(@hardcoded_user_id)
      |> Repo.preload(me_file: :ledger_header)

    assign(conn, :current_scope, Scope.for_user(user))
  end

  def on_mount(:mount_current_scope, _params, session, socket) do
    {:cont, mount_current_scope(socket, session)}
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
      # user =
      #   if user_token = session["user_token"] do
      #     Accounts.get_user_by_session_token(user_token)
      #   end

      user =
        Qlarius.Repo.get!(Qlarius.Accounts.User, @hardcoded_user_id)
        |> Qlarius.Repo.preload(me_file: :ledger_header)

      Scope.for_user(user)
    end)
    |> Phoenix.Component.assign_new(:is_mobile, fn ->
      Map.get(session, "is_mobile", false)
    end)
  end
end
