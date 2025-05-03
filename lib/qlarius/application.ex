defmodule Qlarius.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    # Load environment variables first
    Qlarius.Runtime.EnvLoader.load()

    # Debug log to check environment variables and config
    Logger.debug("Environment variables loaded:")
    Logger.debug("LEGACY_DATABASE_URL: #{inspect(System.get_env("LEGACY_DATABASE_URL"))}")
    Logger.debug("DATABASE_URL: #{inspect(System.get_env("DATABASE_URL"))}")

    # Debug log full repo configurations
    Logger.debug("Full Qlarius.Repo config:")
    Logger.debug(inspect(Application.get_env(:qlarius, Qlarius.Repo), pretty: true))

    Logger.debug("Full Qlarius.LegacyRepo config:")
    Logger.debug(inspect(Application.get_env(:qlarius, Qlarius.LegacyRepo), pretty: true))

    children = [
      # Start Telemetry supervisor
      QlariusWeb.Telemetry,

      # Start the Ecto repositories
      {Qlarius.Repo, []},
      {Qlarius.LegacyRepo, []},

      # Start the remaining services
      {DNSCluster, query: Application.get_env(:qlarius, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Qlarius.PubSub},
      {Finch, name: Qlarius.Finch},
      QlariusWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Qlarius.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    QlariusWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
