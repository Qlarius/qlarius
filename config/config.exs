# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Load environment variables first, before any other configuration
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

# Database configuration
config :qlarius, Qlarius.Repo,
  migration_primary_key: [type: :bigserial],
  migration_timestamps: [type: :naive_datetime],
  migration_foreign_key: [type: :bigint],
  start_apps_before_migration: [:ssl]

# Configures the endpoint
config :qlarius, QlariusWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: QlariusWeb.ErrorHTML, json: QlariusWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Qlarius.PubSub,
  live_view: [signing_salt: "kK/+rxZ2"]

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
  version: "0.17.11",
  qlarius: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  qlarius: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# # Configure Waffle for file uploads
# config :waffle,
#   storage: Waffle.Storage.Local,
#   storage_dir_prefix: "priv/static",
#   asset_host: "http://localhost:4000"

# # Configure ExAws base settings
# config :ex_aws,
#   json_codec: Jason

# # Configure env loading for development
# if Mix.env() == :dev do
#   config :qlarius, Qlarius.Runtime.EnvLoader, env_file: ".env"
# end

# # Waffle storage switching
# if System.get_env("USE_S3_STORAGE") == "true" do
#   bucket = System.get_env("AWS_BUCKET_NAME")
#   region = System.get_env("AWS_REGION")

#   config :waffle,
#     storage: Waffle.Storage.S3,
#     bucket: bucket,
#     asset_host: "https://#{bucket}.s3.#{region}.amazonaws.com"

#   config :ex_aws,
#     json_codec: Jason,
#     access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
#     secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY"),
#     region: region,
#     s3: [
#       scheme: "https://",
#       host: "s3.#{region}.amazonaws.com",
#       region: region,
#       bucket: bucket
#     ]
# end

# Database URL from env
if System.get_env("DATABASE_URL") do
  config :qlarius, Qlarius.Repo, url: System.get_env("DATABASE_URL")
end

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
