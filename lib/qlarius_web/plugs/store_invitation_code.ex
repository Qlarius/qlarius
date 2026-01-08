defmodule QlariusWeb.Plugs.StoreInvitationCode do
  @moduledoc """
  Stores invitation/referral code from query params in session.
  This allows the code to persist across navigation.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    ref = conn.params["ref"] || conn.params["invite"]

    if ref do
      put_session(conn, "invitation_code", ref)
    else
      conn
    end
  end
end
