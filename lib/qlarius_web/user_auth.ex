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
    user = Qlarius.Repo.get!(Qlarius.Accounts.User, @hardcoded_user_id)
    assign(conn, :current_scope, Scope.for_user(user))
  end

  def on_mount(:mount_current_scope, _params, session, socket) do
    {:cont, mount_current_scope(socket, session)}
  end

  defp mount_current_scope(socket, _session) do
    Phoenix.Component.assign_new(socket, :current_scope, fn ->
      # user =
      #   if user_token = session["user_token"] do
      #     Accounts.get_user_by_session_token(user_token)
      #   end

      user = Qlarius.Repo.get!(Qlarius.Accounts.User, @hardcoded_user_id)
      Scope.for_user(user)
    end)
  end
end
