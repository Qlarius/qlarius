defmodule QlariusWeb.Plugs.HostAwareSession do
  @moduledoc """
  Drop-in replacement for `Plug.Session` that applies a shared cookie
  `Domain=.qadabra.app` attribute to requests served from any host
  under the Qadabra apex (e.g. `qadabra.app`, `www.qadabra.app`,
  `qlink.qadabra.app`), and leaves the cookie host-scoped (no
  `Domain` attribute) on every other host.

  ## Why

  A single shared-domain session cookie lets visitors who authenticate
  on one Qadabra host (e.g. `qlink.qadabra.app` via the "Connect your
  wallet" flow) be recognized as authenticated on sibling Qadabra
  hosts (e.g. `qadabra.app` main app, or any other future
  `*.qadabra.app` subdomain) without a second login.

  Setting `Domain=.qadabra.app` unconditionally is NOT safe, however,
  because the same Phoenix endpoint also serves the anonymous share
  surface on `qlinkin.bio`. Browsers reject `Set-Cookie` headers whose
  `Domain` attribute does not match the response's host, which would
  prevent session cookies from ever being stored on `qlinkin.bio` —
  breaking LiveView CSRF validation and any other session-backed
  behaviour on that host. This plug sidesteps that by branching on
  `conn.host` at request time:

    * `qadabra.app` and any `*.qadabra.app` -> add `:domain` option.
    * Everything else (qlinkin.bio, localhost, gigalixirapp.com, etc.)
      -> leave options alone -> cookie is host-scoped as before.

  All other options (`store`, `key`, `signing_salt`, `same_site`,
  `secure`, `http_only`, `max_age`) are read from the same
  `session_options` keyword list configured on the endpoint, so
  nothing else about session behaviour changes.

  ## Usage

  Replace `plug Plug.Session, @session_options` in the endpoint with:

      plug QlariusWeb.Plugs.HostAwareSession, @session_options

  The remember-me cookie follows the same
  "shared-on-qadabra-hosts / scoped-elsewhere" rule via
  `QlariusWeb.UserAuth`, which calls `host_under_qadabra?/1` directly.
  """

  @behaviour Plug

  @cross_subdomain_host ".qadabra.app"

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, opts) do
    effective_opts = options_for_host(opts, conn.host)
    Plug.Session.call(conn, Plug.Session.init(effective_opts))
  end

  @doc """
  Returns `true` when the given host should share a session cookie
  across the Qadabra apex. The apex itself (`qadabra.app`) and any
  subdomain (`www.qadabra.app`, `qlink.qadabra.app`, …) qualify;
  every other host — including `qlinkin.bio`, `localhost`, and
  Gigalixir app hostnames — does not.
  """
  @spec host_under_qadabra?(term()) :: boolean()
  def host_under_qadabra?("qadabra.app"), do: true

  def host_under_qadabra?(host) when is_binary(host) do
    String.ends_with?(host, ".qadabra.app")
  end

  def host_under_qadabra?(_), do: false

  @doc """
  Cross-subdomain host (leading-dot form) used as the `Domain`
  attribute on shared cookies. Exposed for reuse by other plumbing
  that writes cookies on the same apex (e.g.
  `QlariusWeb.UserAuth` for the remember-me cookie).
  """
  @spec cross_subdomain_host() :: String.t()
  def cross_subdomain_host, do: @cross_subdomain_host

  defp options_for_host(opts, host) do
    if host_under_qadabra?(host) do
      Keyword.put(opts, :domain, @cross_subdomain_host)
    else
      opts
    end
  end
end
