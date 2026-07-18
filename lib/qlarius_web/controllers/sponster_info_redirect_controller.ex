defmodule QlariusWeb.SponsterInfoRedirectController do
  @moduledoc """
  Public hop on the Qadabra app host that stamps a referral code, then
  sends the visitor to the marketing site (`qadabra.co/sponster`).

  Used by the unauthenticated Sponster drawer "More Sponster Info →"
  CTA so publisher/recipient attribution lands in the same
  `qadabra_referral_code` cookie / session that registration already reads.
  """
  use QlariusWeb, :controller

  @destination "https://qadabra.co/sponster"
  @cookie_name "qadabra_referral_code"
  # Match the 30-day client-side cookie in `assets/js/app.js`.
  @cookie_max_age 30 * 24 * 60 * 60

  def go(conn, params) do
    ref =
      case params["ref"] || params["invite"] do
        code when is_binary(code) -> String.trim(code)
        _ -> ""
      end

    conn =
      if ref != "" do
        conn
        |> put_session("referral_code", ref)
        |> put_resp_cookie(@cookie_name, ref,
          max_age: @cookie_max_age,
          path: "/",
          http_only: false,
          same_site: "Lax",
          secure: conn.scheme == :https
        )
      else
        conn
      end

    redirect(conn, external: @destination)
  end
end
