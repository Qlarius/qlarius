defmodule Qlarius.Qlink.Urls do
  @moduledoc """
  URL builders for Qlink pages across their two public surfaces.

  * `share_url/1` returns the vanity URL (qlinkin.bio) intended for
    creators to share in social profiles, link-in-bio, and marketing.
    This surface is anonymous-only and edge-cacheable.

  * `interact_url/1` returns the URL of the same Qlink page on the
    authed/interactive host (qlink.qadabra.app). This surface reads
    the shared `.qadabra.app` session cookie and serves the
    interactive UI (tips, ad-engage, purchases, etc.).

  The underlying hosts come from application config keys
  `:qlink_share_host` and `:qlink_interact_host`, which are
  overridden in `config/dev.exs` to point at `localhost:4001` so the
  same route works in local development.
  """

  @doc """
  Public share URL for a creator's Qlink page. Always anonymous,
  cacheable, intended to be rendered in "Copy my link" UIs and shared
  externally.
  """
  @spec share_url(String.t()) :: String.t()
  def share_url(alias_) when is_binary(alias_) do
    "#{scheme_for(share_host())}://#{share_host()}/@#{alias_}"
  end

  @doc """
  Interactive URL for a creator's Qlink page. Reads the qadabra
  session cookie so logged-in visitors see the full UI. Used as the
  destination of the "Connect your wallet" / sign-in CTAs from the
  anonymous share surface.
  """
  @spec interact_url(String.t()) :: String.t()
  def interact_url(alias_) when is_binary(alias_) do
    "#{scheme_for(interact_host())}://#{interact_host()}/@#{alias_}"
  end

  @doc """
  Host that serves the anonymous share surface. Reads from app config
  so dev/test can override to localhost.
  """
  @spec share_host() :: String.t()
  def share_host, do: Application.fetch_env!(:qlarius, :qlink_share_host)

  @doc """
  Host that serves the authed interactive surface. Reads from app
  config so dev/test can override to localhost.
  """
  @spec interact_host() :: String.t()
  def interact_host, do: Application.fetch_env!(:qlarius, :qlink_interact_host)

  @doc """
  Login URL on the interact host. Used as the destination for
  "Connect your wallet" CTAs from anonymous widget surfaces (e.g. the
  Tiqit arqade iframe rendered inside a Qlink page on the anon share
  host). Intended to be used with `target="_top"` so the browser
  breaks out of the iframe and lands on the authed surface.
  """
  @spec interact_login_url() :: String.t()
  def interact_login_url do
    "#{scheme_for(interact_host())}://#{interact_host()}/login"
  end

  # Localhost dev uses https://localhost:4001 (see config/dev.exs); anything
  # containing "localhost" keeps the https scheme the dev server runs on. In
  # prod, public hosts are always served over https.
  defp scheme_for(_host), do: "https"
end
