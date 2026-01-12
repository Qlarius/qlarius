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
       {"0 0 * * 5", Qlarius.Jobs.ProcessReferralPayoutsWorker}
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
  frame_ancestors: ["'self'", "chrome-extension://ambaojidcamjpjbfcnefhobgljmafgen"]

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
