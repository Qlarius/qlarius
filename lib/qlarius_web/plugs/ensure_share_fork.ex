defmodule QlariusWeb.Plugs.EnsureShareFork do
  @moduledoc """
  Materializes a per-session share fork before the share LiveView mounts.

  Canonical share links stay reusable in the copied URL; each browser session
  gets its own child `share_invitations` row (new token) for attribution.
  Gifts are untouched.
  """

  import Plug.Conn

  alias Qlarius.ContentSharing

  def init(opts), do: opts

  def call(%Plug.Conn{path_info: ["tiqit", "share", token]} = conn, _opts)
      when is_binary(token) do
    conn = fetch_session(conn)

    case ContentSharing.resolve_share_visit(conn, token) do
      {:ok, _token, conn} ->
        conn

      {:redirect, fork_token, conn} ->
        redirect(conn, fork_token)

      {:pass, conn} ->
        conn
    end
  end

  def call(conn, _opts), do: conn

  defp redirect(conn, fork_token) do
    conn
    |> Phoenix.Controller.redirect(to: "/tiqit/share/#{fork_token}")
    |> halt()
  end
end
