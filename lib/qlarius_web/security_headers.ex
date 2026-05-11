defmodule QlariusWeb.SecurityHeaders do
  @moduledoc """
  Single source of truth for the app's Content-Security-Policy string.

  The CSP is applied from two places in the request pipeline:

    * `QlariusWeb.Endpoint.set_csp/2` – runs on every request so even
      static/asset responses and error pages carry a policy.
    * `QlariusWeb.Router.allow_iframe/2` – runs after `put_secure_browser_headers`
      on iframe-allowing pipelines (`:browser`, `:browser_anon`, `:widgets`)
      and also strips `x-frame-options`.

  Historically the CSP string was duplicated in both spots and drifted out
  of sync. Keep **all** CSP edits here; the plugs are thin wrappers.

  ## Adding a new iframe embed source

  Append the origin (as `https://host`) to `@frame_src_hosts`. Don't forget
  to include any subdomain variants (`www.`, etc.) since CSP host-matching
  is literal unless you use a wildcard (`https://*.example.com`).

  ## Adding a new CORS origin

  That's separate – see `QlariusWeb.Endpoint.cors_origins/0`.
  """

  # Hosts allowed in `frame-src`. Broken out to make additions
  # reviewable diff-by-diff.
  @frame_src_hosts [
    "'self'",
    # Our own hosts (Qlink/main-app cross-host embeds, e.g. Tiqit arqade
    # rendered inside a Qlink page on qlinkin.bio)
    "https://qadabra.app",
    "https://*.qadabra.app",
    "https://qadabra.co",
    "https://*.qadabra.co",
    "https://qlinkin.bio",
    "https://*.qlinkin.bio",
    "https://qlarius.gigalixirapp.com",
    # Third-party embed providers used by
    # QlariusWeb.QlinkPage.Show.render_embed/1
    "https://www.youtube.com",
    "https://youtube.com",
    "https://www.youtube-nocookie.com",
    "https://open.spotify.com",
    "https://www.tiktok.com",
    "https://tiktok.com"
  ]

  @directives [
    {"base-uri", "'self'"},
    {"default-src", "'self'"},
    {"img-src", "'self' data: http: https: blob:"},
    {"media-src",
     "'self' http://localhost:4000 https://localhost:4001 https://*.s3.us-east-1.amazonaws.com https://*.s3.amazonaws.com"},
    {"style-src", "'self' 'unsafe-inline'"},
    {"script-src", "'self' 'unsafe-inline' 'unsafe-eval'"},
    {"connect-src", "'self' ws: wss: http: https:"},
    {"frame-src", Enum.join(@frame_src_hosts, " ")},
    {"frame-ancestors", "* chrome-extension:"}
  ]

  @csp @directives
       |> Enum.map_join("; ", fn {k, v} -> "#{k} #{v}" end)
       |> Kernel.<>(";")

  @doc """
  Returns the full CSP header value as a string.

  Evaluated at compile time; no per-request cost.
  """
  @spec content_security_policy() :: String.t()
  def content_security_policy, do: @csp
end
