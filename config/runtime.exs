import Config

IO.puts("Current working directory: #{File.cwd!()}")
IO.puts("Looking for .env at: #{Path.expand(".env")}")
IO.inspect(File.read!(".env"), label: ".env file contents")

IO.inspect(File.exists?(".env"), label: ".env exists?")

IO.inspect(System.get_env("DATABASE_URL"), label: "DATABASE_URL before Dotenvy")
vars = Dotenvy.source!(".env")

Enum.each(vars, fn {k, v} ->
  require Logger
  Logger.debug("Setting env var #{k} to #{v}")
  System.put_env(k, v)
end)

IO.inspect(System.get_env("DATABASE_URL"), label: "DATABASE_URL after Dotenvy")

System.put_env("FOO", "bar")
IO.inspect(System.get_env("FOO"), label: "FOO after System.put_env")

# Print debug info for all relevant environment variables
for var <-
      ~w(DATABASE_URL LEGACY_DATABASE_URL SECRET_KEY_BASE PHX_HOST PORT USE_S3_STORAGE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_REGION AWS_BUCKET_NAME MIX_ENV) do
  IO.puts("#{var}=#{inspect(System.get_env(var))}")
end

# Load environment variables first if in dev environment
if config_env() == :dev do
  require Logger
  Logger.debug("Loading environment in runtime.exs")

  # Load environment variables
  if Code.ensure_loaded?(Qlarius.Runtime.EnvLoader) do
    Qlarius.Runtime.EnvLoader.load()
  end
end

# Log current environment state
require Logger
Logger.debug("Runtime config - environment state:")
Logger.debug("DATABASE_URL=#{inspect(System.get_env("DATABASE_URL"))}")
Logger.debug("LEGACY_DATABASE_URL=#{inspect(System.get_env("LEGACY_DATABASE_URL"))}")

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# Configure remote database URL for switching - this needs to be available in all environments
remote_database_url = System.get_env("REMOTE_DATABASE_URL")

if remote_database_url do
  config :qlarius, :remote_database_url, remote_database_url
end

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/qlarius start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :qlarius, QlariusWeb.Endpoint, server: true
end

# Configure database URLs
legacy_database_url = System.get_env("LEGACY_DATABASE_URL")
database_url = System.get_env("DATABASE_URL")

if legacy_database_url do
  Logger.debug("Configuring LegacyRepo with URL")

  config :qlarius, Qlarius.LegacyRepo,
    url: legacy_database_url,
    ssl:
      String.contains?(legacy_database_url, "amazonaws.com") or
        String.contains?(legacy_database_url, "render.com"),
    ssl_opts: [verify: :verify_none],
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    migration_timestamps: [type: :naive_datetime],
    migration_primary_key: [type: :bigserial]
end

if database_url do
  Logger.debug("Configuring Repo with URL")

  config :qlarius, Qlarius.Repo,
    url: database_url,
    ssl:
      String.contains?(database_url, "amazonaws.com") or
        String.contains?(database_url, "render.com"),
    ssl_opts: [verify: :verify_none],
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
end

if config_env() == :prod do
  database_url =
    database_url ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :qlarius, Qlarius.Repo, socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :qlarius, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :qlarius, QlariusWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :qlarius, QlariusWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :qlarius, QlariusWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  #     config :qlarius, Qlarius.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end

# Configure Waffle storage based on environment
if System.get_env("USE_S3_STORAGE") == "true" do
  bucket = System.get_env("AWS_BUCKET_NAME")
  region = System.get_env("AWS_REGION")

  config :waffle,
    storage: Waffle.Storage.S3,
    bucket: bucket,
    asset_host: "https://#{bucket}.s3.#{region}.amazonaws.com"

  config :ex_aws,
    access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
    secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY"),
    region: region,
    s3: [
      scheme: "https://",
      host: "s3.#{region}.amazonaws.com",
      region: region,
      bucket: bucket
    ]
else
  if config_env() == :dev do
    config :waffle,
      storage: Waffle.Storage.Local,
      storage_dir_prefix: "priv/static",
      asset_host: "http://localhost:4000"
  end
end
