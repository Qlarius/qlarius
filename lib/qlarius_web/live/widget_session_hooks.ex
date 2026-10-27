defmodule QlariusWeb.WidgetSessionHooks do
  @moduledoc """
  Companion to `QlariusWeb.WidgetSocket` for the `/widgets` live_session.

  When the socket built the session from a `widget_token` instead of the
  cookie (`session["widget_token_session"]`), the browser is withholding
  the widget cookie. For an authed mount this hook pushes a renewable
  `:session` widget token so the client can reconnect without losing the
  user. `clear_widget_session/1` lets a widget log out in that mode, since
  `POST /logout` cannot pass CSRF without a session cookie.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [connected?: 1, push_event: 3]

  alias Qlarius.Accounts
  alias QlariusWeb.Auth.WidgetToken
  alias QlariusWeb.SessionSync

  def on_mount(:default, _params, session, socket) do
    token_session? = session["widget_token_session"] == true
    user_token = session["user_token"]
    sync_id = session["session_sync_id"]

    socket =
      socket
      |> assign(:widget_token_session?, token_session?)
      |> assign(:widget_session_user_token, if(token_session?, do: user_token, else: nil))

    socket =
      if connected?(socket) and token_session? and is_binary(user_token) and
           socket.assigns[:current_scope] do
        push_event(socket, "qadabra:widget-session-token", %{
          token: WidgetToken.sign_session(user_token, sync_id)
        })
      else
        socket
      end

    {:cont, socket}
  end

  @doc """
  Server-side logout for a token-backed widget session: deletes the DB
  session token (which also invalidates every widget token carrying it)
  and tells sibling widgets to remount. Returns `true` when it handled the
  logout; `false` means the session came from a cookie and the normal
  `/logout` fetch should run.
  """
  @spec clear_widget_session(Phoenix.LiveView.Socket.t()) :: boolean()
  def clear_widget_session(%{assigns: %{widget_token_session?: true} = assigns}) do
    case assigns[:widget_session_user_token] do
      token when is_binary(token) -> Accounts.delete_user_session_token(token)
      _ -> :ok
    end

    if is_binary(assigns[:session_sync_id]) do
      SessionSync.broadcast(assigns.session_sync_id, :anonymous)
    end

    true
  end

  def clear_widget_session(_socket), do: false
end
