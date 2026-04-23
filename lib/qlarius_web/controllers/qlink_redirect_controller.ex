defmodule QlariusWeb.QlinkRedirectController do
  @moduledoc """
  Handles non-Qlink paths on the vanity share host (qlinkin.bio).

  The share host is deliberately single-purpose: it serves the public
  anonymous view of a creator's Qlink page at `/@:alias` and nothing
  else. Everything else — the bare root, typos, stale links — gets
  redirected to the Qadabra marketing site's Qlink explainer page so
  visitors always land somewhere useful rather than a dead 404.

  The redirect destination is configured via `:qlink_landing_redirect_url`
  so dev/test environments can point it at a local URL if needed.
  """
  use QlariusWeb, :controller

  @doc "Bare `qlinkin.bio/` — redirect to Qadabra marketing's Qlink explainer."
  def landing(conn, _params) do
    redirect(conn, external: landing_url())
  end

  @doc "Catch-all for any non-`/@:alias` path on qlinkin.bio."
  def not_found(conn, _params) do
    conn
    |> put_status(:moved_permanently)
    |> redirect(external: landing_url())
  end

  @doc """
  `qadabra.app/@:alias` → canonical Qlink interact host.

  The apex host is reserved for the main app; Qlink pages live on the
  dedicated `qlink.qadabra.app` subdomain. If a visitor lands on the
  apex with a `/@:alias` path (typo, old shared link, etc.), we 301 them
  to the canonical interact URL so they don't hit a 404. The query
  string is preserved so referral params (`?ref=...`) survive the hop.
  """
  def to_interact(conn, %{"alias" => alias_}) do
    target = Qlarius.Qlink.Urls.interact_url(alias_)

    target_with_qs =
      case conn.query_string do
        "" -> target
        qs -> target <> "?" <> qs
      end

    conn
    |> put_status(:moved_permanently)
    |> redirect(external: target_with_qs)
  end

  defp landing_url, do: Application.fetch_env!(:qlarius, :qlink_landing_redirect_url)
end
