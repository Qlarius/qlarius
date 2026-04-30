defmodule QlariusWeb.Plugs.InAppBrowserDetection do
  @moduledoc """
  Classifies the request's `User-Agent` as an in-app webview (Instagram,
  Facebook, TikTok, etc.) and stashes the result in both `conn.assigns`
  and the session for the Qlink LiveView `on_mount`
  (`QlariusWeb.InAppBrowserMount`) to read.

  ## Scoping

  **This plug only does work on Qlink hosts.** The IAB-escape feature
  is only surfaced on `QlinkPage.Show` (qlinkin.bio / qlink.qadabra.app
  / dev hosts), so there is no reason to touch the session on
  `qadabra.app` requests. Running it in the shared `:browser` pipeline
  for every request to the main app marked the session cookie for
  rewrite on every hit, which interacted badly with
  `HostAwareSession`'s `Domain=.qadabra.app` attribute and produced
  intermittent session loss on `qadabra.app` auth flows.

  The fix is a host guard that short-circuits the plug on every host
  that isn't a Qlink surface. The plug stays wired in the shared
  `:browser` pipeline (no router changes) but is effectively a no-op
  everywhere except where the feature actually renders.
  """

  import Plug.Conn

  alias Qlarius.Browsers.InAppClassifier

  @session_key "qlarius_iab"

  # Hosts where Qlink pages are served. Kept in sync with the router's
  # `host:` clauses for `QlinkPage.Show` (see `router.ex` —
  # `:public_qlinkin_bio` and `:public_qlink_authed` live_sessions).
  @qlink_hosts ~w(
    qlinkin.bio
    www.qlinkin.bio
    qlink.qadabra.app
    localhost
    127.0.0.1
    qlarius.gigalixirapp.com
  )

  def init(opts), do: opts

  def call(conn, _opts) do
    if qlink_host?(conn.host) do
      run_on_qlink_host(conn)
    else
      # Non-Qlink host (qadabra.app, *.qadabra.app main app, etc.).
      # Do NOT touch the session here. `conn.assigns[:in_app_browser]`
      # still gets set so downstream templates/helpers that read it
      # don't hit a `KeyError`, but we intentionally skip
      # `put_session`/`delete_session` so the auth session cookie
      # isn't rewritten on every request.
      assign(conn, :in_app_browser, nil)
    end
  end

  defp run_on_qlink_host(conn) do
    cfg = Application.get_env(:qlarius, :in_app_browser_escape, [])

    if Keyword.get(cfg, :enabled, false) do
      run_detection(conn)
    else
      conn
      |> assign(:in_app_browser, nil)
      |> delete_session(@session_key)
    end
  end

  defp run_detection(conn) do
    user_agent = get_req_header(conn, "user-agent") |> List.first() || ""

    case InAppClassifier.classify(user_agent) do
      nil ->
        conn
        |> assign(:in_app_browser, nil)
        |> delete_session(@session_key)

      %{family: family, confidence: confidence, os: os} = result ->
        session_payload = %{
          "family" => Atom.to_string(family),
          "confidence" => Atom.to_string(confidence),
          "os" => Atom.to_string(os)
        }

        conn
        |> assign(:in_app_browser, result)
        |> put_session(@session_key, session_payload)
    end
  end

  defp qlink_host?(host) when is_binary(host), do: host in @qlink_hosts
  defp qlink_host?(_), do: false
end
