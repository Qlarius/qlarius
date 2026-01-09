defmodule QlariusWeb.Plugs.StoreReferralCode do
  @moduledoc """
  Stores referral code from query params in session.
  This allows the code to persist across navigation.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    ref = conn.params["ref"] || conn.params["invite"]

    if ref do
      put_session(conn, "referral_code", ref)
    else
      conn
    end
  end
end
