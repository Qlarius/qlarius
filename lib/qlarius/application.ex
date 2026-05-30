defmodule Qlarius.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Oban.Telemetry.attach_default_logger()
    QlariusWeb.LiveViewDebug.attach!()

    children =
      [
        QlariusWeb.Telemetry,
        Qlarius.Repo,
        Qlarius.Vault,
        Qlarius.Secrets,
        {DNSCluster, query: Application.get_env(:qlarius, :dns_cluster_query) || :ignore},
        {Oban, Application.fetch_env!(:qlarius, Oban)},
        {Phoenix.PubSub, name: Qlarius.PubSub},
        {Finch, name: Qlarius.Finch},
        Qlarius.YouData.TagTeaseAgent,
        Qlarius.Accounts.AliasGenerator,
        QlariusWeb.Auth.FinalizeTokenSweeper,
        QlariusWeb.Endpoint
      ] ++ QlariusWeb.LiveViewDebug.children()

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
