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

  With a `return_to` path, the login form is pre-loaded to redirect
  back to that path after successful sign-in (and, if the visitor is
  already authenticated on the interact host via the shared
  `.qadabra.app` cookie, `redirect_if_user_is_authenticated` honors
  the same `return_to` and skips the login form entirely). The
  `return_to` must be a local path starting with `/` — callers should
  sanitize before passing (see `sanitize_return_to/1`).
  """
  @spec interact_login_url(String.t() | nil) :: String.t()
  def interact_login_url(return_to \\ nil)

  def interact_login_url(nil) do
    "#{scheme_for(interact_host())}://#{interact_host()}/login"
  end

  def interact_login_url(return_to) when is_binary(return_to) do
    case sanitize_return_to(return_to) do
      nil -> interact_login_url(nil)
      safe -> interact_login_url(nil) <> "?" <> URI.encode_query(return_to: safe)
    end
  end

  @doc """
  Validates a `return_to` path. Accepts only local paths that begin
  with a single `/` (not `//` — which browsers treat as
  protocol-relative). Returns the path verbatim when valid, `nil`
  otherwise. Used at every `return_to` boundary (URL builder, login
  param, auto-login param) to close open-redirect attack surface.
  """
  @spec sanitize_return_to(term()) :: String.t() | nil
  def sanitize_return_to(path) when is_binary(path) do
    cond do
      String.starts_with?(path, "//") -> nil
      String.starts_with?(path, "/") -> path
      true -> nil
    end
  end

  def sanitize_return_to(_), do: nil

  @doc """
  Rewrites the host/port/scheme of an arqade **widget** iframe URL to
  match the parent page's request URI, so the shared
  `.qadabra.app` session cookie is sent along with the iframe's
  requests.

  Creators historically embedded arqade widgets with URLs baked to
  whichever host was canonical at save time (e.g.
  `https://qlarius.gigalixirapp.com/widgets/arqade/group/13`). Those
  URLs continue to work at the network level but sit on a different
  registrable domain than the current parent page, so the browser
  does NOT send the `Domain=.qadabra.app` session cookie on iframe
  requests — making the widget LV inside the iframe see an anonymous
  visitor even when the outer page is authenticated. This normalizer
  fixes that in-place, without a data migration: each render
  substitutes the parent's live request host (and port + scheme) into
  the stored URL.

  Only URLs whose path begins with `/widgets/arqade/` or
  `/widgets/arcade/` are rewritten. Third-party embeds
  (`https://example.com/something`) pass through unchanged, because
  rewriting their host would break the embed.

  `parent_uri` is expected to be the `%URI{}` returned by
  `Phoenix.LiveView.get_connect_info(socket, :uri)`. When the LV is
  in its "dead" HTTP render the connect info isn't yet available;
  callers pass `nil` and the URL is returned verbatim. The iframe
  reloads automatically once the LV connects and a proper
  normalization takes effect.
  """
  @spec normalize_widget_iframe_url(String.t(), URI.t() | nil) :: String.t()
  def normalize_widget_iframe_url(iframe_url, parent_uri)

  def normalize_widget_iframe_url(iframe_url, nil) when is_binary(iframe_url) do
    iframe_url
  end

  def normalize_widget_iframe_url(iframe_url, %URI{host: host} = parent_uri)
      when is_binary(iframe_url) and is_binary(host) do
    uri = URI.parse(iframe_url)

    if arqade_widget_path?(uri.path) do
      %URI{
        uri
        | scheme: parent_uri.scheme || uri.scheme,
          host: parent_uri.host,
          port: parent_uri.port,
          # Drop userinfo/authority cruft that URI.to_string/1 would preserve
          # from the original URL — not expected in practice, but defensive.
          userinfo: nil
      }
      |> URI.to_string()
    else
      iframe_url
    end
  end

  def normalize_widget_iframe_url(iframe_url, _), do: iframe_url

  defp arqade_widget_path?(path) when is_binary(path) do
    String.starts_with?(path, "/widgets/arqade/") or
      String.starts_with?(path, "/widgets/arcade/")
  end

  defp arqade_widget_path?(_), do: false

  # Localhost dev uses https://localhost:4001 (see config/dev.exs); anything
  # containing "localhost" keeps the https scheme the dev server runs on. In
  # prod, public hosts are always served over https.
  defp scheme_for(_host), do: "https"
end
