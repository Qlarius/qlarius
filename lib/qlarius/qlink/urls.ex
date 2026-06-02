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

  * `me_file_url_for_sponsorship/1` and
    `settings_notifications_url_for_sponsorship/1` point at the main Qadabra
    app from Qlink (e.g. Sponster drawer empty state).

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
  Canonical origin for user-facing links copied out of the app (gift/share
  invitations, public arqade URLs, referral links, etc.).

  When `:public_app_host` is set (production default `qadabra.app`; dev/test
  `localhost:4001`), links use that host regardless of the deployment host
  (e.g. `qlarius.gigalixirapp.com`). When unset, falls back to
  `QlariusWeb.Endpoint.url()`.
  """
  @spec public_app_origin() :: String.t()
  def public_app_origin do
    case Application.get_env(:qlarius, :public_app_host) do
      host when is_binary(host) and host != "" ->
        scheme = Application.get_env(:qlarius, :public_app_scheme, "https")
        "#{scheme}://#{host}"

      _ ->
        QlariusWeb.Endpoint.url()
    end
  end

  @doc "Absolute URL on the public app host for a local path (must start with `/`)."
  @spec public_app_url(String.t()) :: String.t()
  def public_app_url(path) when is_binary(path) do
    public_app_origin() <> path
  end

  @doc """
  Main-app `MeFileLive` URL (`/me_file`) from a Qlink request URI.

  Uses `public_app_origin/0` (qadabra.app in production); localhost uses the request origin.
  """
  @spec me_file_url_for_sponsorship(URI.t() | nil) :: String.t()
  def me_file_url_for_sponsorship(uri \\ nil) do
    sponsorship_app_url(uri, "/me_file", %{from: "sponster_drawer"})
  end

  @doc """
  Main-app `/settings` URL with the notifications panel opened (`setting=notifications`).
  """
  @spec settings_notifications_url_for_sponsorship(URI.t() | nil) :: String.t()
  def settings_notifications_url_for_sponsorship(uri \\ nil) do
    sponsorship_app_url(uri, "/settings", %{
      setting: "notifications",
      from: "sponster_drawer"
    })
  end

  defp sponsorship_app_url(uri, path, query) when is_binary(path) and is_map(query) do
    sponsorship_main_origin(uri) <> path <> "?" <> URI.encode_query(query)
  end

  defp sponsorship_main_origin(nil), do: public_app_origin()

  defp sponsorship_main_origin(%URI{host: host} = uri) when is_binary(host) do
    if host in ["localhost", "127.0.0.1"] do
      origin_from_request(uri)
    else
      public_app_origin()
    end
  end

  defp sponsorship_main_origin(_), do: public_app_origin()

  defp origin_from_request(%URI{} = uri) do
    scheme = uri.scheme || "https"

    authority =
      case {scheme, uri.host, uri.port} do
        {_, h, _} when not is_binary(h) ->
          "localhost"

        {"https", h, p} when p in [nil, 443] ->
          h

        {"http", h, p} when p in [nil, 80] ->
          h

        {_, h, p} when is_integer(p) ->
          "#{h}:#{p}"

        {_, h, _} ->
          h
      end

    "#{scheme}://#{authority}"
  end

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

  @doc """
  Parses an embed URL to determine whether it points at an arqade
  widget served by *this* deployment, and if so which kind.

  Returns:
    * `{:ok, {:group, group_id}}` for `/widgets/arqade/group/:id`
    * `{:ok, {:catalog, catalog_id}}` for `/widgets/arqade/catalog/:id`
    * `{:ok, {:single, piece_id}}` for `/widgets/arqade/:piece_id`
    * `{:ok, :discovery}` for `/widgets/arqade` (no id)
    * `:error` for anything else (third-party URLs, non-arqade paths,
      unparseable URLs).

  Recognizes both `arqade` and the historical `arcade` spelling.
  IDs are returned as the raw string fragment from the URL path; the
  caller is expected to validate / convert them.

  This is the ingredient `QlinkPage.Show` uses to decide whether an
  embed can be inlined as a nested `live_render/3` instead of served
  through an iframe.
  """
  @spec parse_arqade_widget_url(term()) ::
          {:ok, {:group, String.t()}}
          | {:ok, {:catalog, String.t()}}
          | {:ok, {:single, String.t()}}
          | {:ok, :discovery}
          | :error
  def parse_arqade_widget_url(url) when is_binary(url) do
    with %URI{path: path} when is_binary(path) <- URI.parse(url),
         true <- arqade_widget_path?(path) or arqade_widget_root?(path) do
      path
      |> String.trim_trailing("/")
      |> String.split("/", trim: true)
      |> classify_arqade_path_segments()
    else
      _ -> :error
    end
  end

  def parse_arqade_widget_url(_), do: :error

  # Accepts the bare root path (no trailing segment) — `/widgets/arqade`
  # and `/widgets/arcade`, with or without a trailing slash.
  defp arqade_widget_root?(path) when is_binary(path) do
    stripped = String.trim_trailing(path, "/")
    stripped == "/widgets/arqade" or stripped == "/widgets/arcade"
  end

  defp arqade_widget_root?(_), do: false

  # Path segments after trim: e.g. ["widgets","arqade","group","42"].
  # Matches the router definitions in `QlariusWeb.Router`.
  defp classify_arqade_path_segments(["widgets", kind, "group", id])
       when kind in ["arqade", "arcade"] and id != "",
       do: {:ok, {:group, id}}

  defp classify_arqade_path_segments(["widgets", kind, "catalog", id])
       when kind in ["arqade", "arcade"] and id != "",
       do: {:ok, {:catalog, id}}

  defp classify_arqade_path_segments(["widgets", kind, id])
       when kind in ["arqade", "arcade"] and id not in ["", "group", "catalog"],
       do: {:ok, {:single, id}}

  defp classify_arqade_path_segments(["widgets", kind])
       when kind in ["arqade", "arcade"],
       do: {:ok, :discovery}

  defp classify_arqade_path_segments(_), do: :error

  @doc """
  Returns `true` when the URL points at an arqade widget on a host
  that belongs to our own deployment family (qadabra.app, qlinkin.bio,
  gigalixirapp.com, localhost). These are the embeds that a Qlink
  page can safely render inline via nested `live_render/3` instead of
  through a cross-origin iframe.

  Always returns `false` for third-party hosts, even when the path
  happens to look arqade-shaped — the iframe is the correct render
  path for those because the widget isn't running in this BEAM.
  """
  @spec own_deployment_arqade_url?(term()) :: boolean()
  def own_deployment_arqade_url?(url) when is_binary(url) do
    case {URI.parse(url), parse_arqade_widget_url(url)} do
      {%URI{host: host}, {:ok, _}} when is_binary(host) ->
        own_deployment_host?(host)

      {%URI{host: nil}, {:ok, _}} ->
        # Relative path — assume same deployment.
        true

      _ ->
        false
    end
  end

  def own_deployment_arqade_url?(_), do: false

  # Kept in sync with `Qlarius.Qlink.QlinkLink.known_deployment_host?/1`.
  # Both predicates carry the same meaning ("this host belongs to us")
  # but live in different modules to avoid a circular dep; changes to
  # one should be mirrored in the other.
  defp own_deployment_host?(host) when is_binary(host) do
    host == "qadabra.app" or String.ends_with?(host, ".qadabra.app") or
      host == "qlinkin.bio" or String.ends_with?(host, ".qlinkin.bio") or
      String.ends_with?(host, ".gigalixirapp.com") or
      host == "localhost"
  end

  defp own_deployment_host?(_), do: false

  # Localhost dev uses https://localhost:4001 (see config/dev.exs); anything
  # containing "localhost" keeps the https scheme the dev server runs on. In
  # prod, public hosts are always served over https.
  defp scheme_for(_host), do: "https"
end
