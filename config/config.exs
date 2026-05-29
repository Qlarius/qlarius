# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :qlarius, Oban,
  engine: Oban.Engines.Basic,
  notifier: Oban.Notifiers.Postgres,
  queues: [default: 10, targets: 5, offers: 10, activations: 3, maintenance: 3],
  repo: Qlarius.Repo,
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(30)},
    {Oban.Plugins.Cron,
     crontab: [
       {"*/5 * * * *", Qlarius.Jobs.ActivatePendingOffersWorker},
       {"0 0 * * *", Qlarius.Jobs.UpdateAgeTagsWorker},
       {"0 2 * * *", Qlarius.Jobs.CleanupInvalidOffersWorker},
       {"0 * * * *", Qlarius.Jobs.BackfillMissingSnapshotsWorker},
       {"0 * * * *", Qlarius.Jobs.SendHourlyAdNotificationsWorker},
       {"0 0 * * 5", Qlarius.Jobs.ProcessReferralPayoutsWorker},
       {"*/15 * * * *", Qlarius.Jobs.AutoFleetTiqitsWorker},
       {"*/10 * * * *", Qlarius.Jobs.ExpireWillCallGiftsWorker}
     ]}
  ]

config :qlarius, :scopes,
  user: [
    default: true,
    module: Qlarius.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: Qlarius.AccountsFixtures,
    test_login_helper: :register_and_log_in_user
  ]

config :qlarius,
  ecto_repos: [Qlarius.Repo],
  generators: [timestamp_type: :utc_datetime]

# Qlink page hosts: qlinkin.bio is the public vanity/share surface (anonymous
# only, edge-cacheable). qlink.qadabra.app is the interactive/authed mirror
# served by the same Phoenix app. Overridden per-env in dev.exs / test.exs.
config :qlarius,
  qlink_share_host: "qlinkin.bio",
  qlink_interact_host: "qlink.qadabra.app",
  qlink_landing_redirect_url: "https://qadabra.co/qlink"

# AuthSheet (and ProxyUserSheet) rollout flags. Each surface is gated
# independently so we can enable in-place auth one surface at a time.
# See docs/qlink_auth_refactor_plan.md §5.5 for semantics. Overridden
# per-env in dev.exs / runtime.exs.
config :qlarius, :in_app_browser_escape, enabled: false, auto_attempt: false

# Twilio: after SMS verification, optionally enforce US mobile + carrier whitelist
# (see Qlarius.Services.Twilio). Default false — flip to true in runtime.exs / prod when ready.
config :qlarius, :twilio_filter_us_carriers, false

# Lookup rejection rows: `blocked_until = inserted_at + N days` (default 30).
config :qlarius, :phone_carrier_rejection_block_days, 30

# 3-tap ad jump page (`/jump/:id`): after successful POST `/jump/collect`,
# navigate with `location.replace` when enabled so the jump page does not stay
# in history (better IAB back UX). `replace_strategy: :iab_only` uses replace only
# when session `qlarius_iab` is set (see InAppBrowserDetection on Qlink hosts).
# QA: desktop new tab Back from advertiser; Reddit/IG IAB one fewer hop; block
# `/jump/collect` in DevTools — expect error UI, no silent redirect to advertiser.
config :qlarius, :ad_jump,
  use_location_replace: true,
  replace_strategy: :universal

# Tiqit player frame override. `:auto` (default) lets
# `QlariusWeb.Components.TiqitPlayer.play_frame_for/1` pick by context:
# `:modal` for inline Qlink embeds, `:page` for `/widgets/...` standalone,
# and `:side_panel` for in-app `/arqade/...` mobile-shell pages. Pin to
# `:page`, `:modal`, or `:side_panel` to force a single frame everywhere
# (kill switch / debugging). Per-env overrides go in runtime.exs.
config :qlarius, :tiqit_player_frame, :auto

config :qlarius, :auth_sheet,
  on_qlink_page: false,
  on_qlinkin_bio: false,
  on_landing_pages: false,
  on_widget_standalone: false,
  on_authed_consumer: false,
  on_admin_proxy: false,
  extension_token_emit: false,
  extension_exchange_enabled: false

# Allowlisted browser extension IDs for CORS. Production ID only in base config;
# dev.exs adds the pinned dev extension ID alongside.
config :qlarius,
  cors_extension_ids: [
    "chrome-extension://mhedmgbdabpgflgijpkabcdnkpncbdgp"
  ]

# Configures the endpoint
config :qlarius, QlariusWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: QlariusWeb.ErrorHTML, json: QlariusWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Qlarius.PubSub,
  live_view: [signing_salt: "kK/+rxZ2"],
  session_options: [
    store: :cookie,
    key: "_qlarius_key",
    signing_salt: "Tvun6ICt",
    same_site: "Lax",
    secure: false
  ]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :qlarius, Qlarius.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  qlarius: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  qlarius: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# In prod this is overridden to store on S3
config :waffle,
  storage: Waffle.Storage.Local,
  storage_dir_prefix: "priv/static",
  asset_host: "http://localhost:4000"

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

# In config/config.exs or wherever CSP is set
config :qlarius, :content_security_policy,
  frame_ancestors: ["'self'", "chrome-extension://mhedmgbdabpgflgijpkabcdnkpncbdgp"]

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :qlarius, Qlarius.Vault,
  ciphers: [
    default: {
      Cloak.Ciphers.AES.GCM,
      tag: "AES.GCM.V1",
      key: Base.decode64!("ulNA++mxH5RjtFP8zWra8/qgvCUkQ8kUO88HyygvSeo="),
      iv_length: 12
    }
  ]

config :qlarius, Qlarius.Services.Twilio,
  account_sid: System.get_env("TWILIO_ACCOUNT_SID", ""),
  auth_token: System.get_env("TWILIO_AUTH_TOKEN", ""),
  verify_service_sid: System.get_env("TWILIO_VERIFY_SERVICE_SID", "")

config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 60_000 * 60 * 4, cleanup_interval_ms: 60_000 * 10]}

# AuthSheet + finalize-session rate-limit master switch. See
# `Qlarius.Auth.RateLimit` and `docs/qlink_auth_refactor_plan.md` §B8.
# Overridden to `false` in `config/test.exs` so suites don't share
# buckets across runs.
config :qlarius, :auth_rate_limit, enabled?: true
