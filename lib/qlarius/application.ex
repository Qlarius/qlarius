defmodule Qlarius.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Oban.Telemetry.attach_default_logger()

    # Attach a telemetry handler to filter out Oban plugin info logs
    # This ignores events like [:oban, :plugin, :stop] without affecting other logs
    :telemetry.attach(
      "ignore-oban-plugin-logs",
      [:oban, :plugin, :stop],
      # Drop the event (no logging)
      fn _event, _measurements, _metadata, _config -> :ok end,
      nil
    )

    children = [
      QlariusWeb.Telemetry,
      Qlarius.Repo,
      {DNSCluster, query: Application.get_env(:qlarius, :dns_cluster_query) || :ignore},
      {Oban, Application.fetch_env!(:qlarius, Oban)},
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
