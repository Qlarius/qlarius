defmodule Qlarius.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      QlariusWeb.Telemetry,
      Qlarius.Repo,
      {DNSCluster, query: Application.get_env(:qlarius, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Qlarius.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Qlarius.Finch},
      # Start a worker by calling: Qlarius.Worker.start_link(arg)
      # {Qlarius.Worker, arg},
      # Start to serve requests, typically the last entry
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
