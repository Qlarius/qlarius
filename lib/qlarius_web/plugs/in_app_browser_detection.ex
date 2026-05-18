defmodule QlariusWeb.Plugs.InAppBrowserDetection do
  @moduledoc """
  Classifies the request's `User-Agent` as an in-app webview (Instagram,
  Facebook, TikTok, Reddit, etc.) and stashes the result in both `conn.assigns`
  and the session for the Qlink LiveView `on_mount`
  (`QlariusWeb.InAppBrowserMount`) to read.

  ## Scoping (two layers, defense-in-depth)

  **This plug only does work on Qlink hosts.** The IAB-escape feature
  is only surfaced on `QlinkPage.Show` (qlinkin.bio / qlink.qadabra.app
  / dev hosts), so there is no reason to touch the session on
  `qadabra.app` or any other main-app request.

  History: the plug originally shipped in the shared `:browser` and
  `:widgets` pipelines. Every request to `qadabra.app` rewrote the
  session cookie (via `delete_session("qlarius_iab")` on non-matching
  UAs), which combined with `HostAwareSession`'s `Domain=.qadabra.app`
  attribute caused intermittent session loss / auth-flow breakage on
  the main app.

  Current wiring (post-cleanup):

    1. **Router layer.** The plug is wired *only* into the dedicated
       `:iab_detection` pipeline, which is attached exclusively to the
       two Qlink route scopes (qlinkin.bio and qlink.qadabra.app +
       dev/gigalixir aliases). Every other surface — the main app,
       widgets, admin, marketer, auth, etc. — never runs this plug.

    2. **Plug layer.** A belt-and-suspenders host guard inside `call/2`
       short-circuits to a safe no-op on any host that isn't a Qlink
       surface. If the `:iab_detection` pipeline is ever attached to a
       non-Qlink scope by mistake, the plug still refuses to touch the
       session.

  Router changes that touch either layer should keep both in sync —
  update `@qlink_hosts` here when adding a new Qlink host in the
  router, and keep the `:iab_detection` pipeline attached only to
  Qlink scopes.
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
    referer = get_req_header(conn, "referer") |> List.first()

    case InAppClassifier.classify_with_referer(user_agent, referer) do
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
