defmodule Qlarius.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    # Load environment variables from .env file
    load_env_file()

    # Debug log to check environment variables and config
    Logger.debug("REMOTE_DATABASE_URL env: #{inspect(System.get_env("REMOTE_DATABASE_URL"))}")
    Logger.debug("Remote database config: #{inspect(Application.get_env(:qlarius, :remote_database_url))}")

    children = [
      # Start Telemetry supervisor
      QlariusWeb.Telemetry,

      # Start the Ecto repositories
      {Qlarius.Repo, []},
      {Qlarius.LegacyRepo, []},

      # Start the database config manager after repos
      {Qlarius.DatabaseConfig, []},

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

  defp load_env_file do
    case File.read(".env") do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.each(fn line ->
          case String.split(String.trim(line), "=") do
            [key, value] when byte_size(key) > 0 ->
              System.put_env(String.trim(key), String.trim(value))
            _ -> :ok
          end
        end)
        Logger.debug("Loaded environment variables from .env file")

        # Set application config after loading environment variables
        if remote_url = System.get_env("REMOTE_DATABASE_URL") do
          Application.put_env(:qlarius, :remote_database_url, remote_url)
          Logger.debug("Set remote database URL in application config")
        end

      {:error, _} ->
        Logger.warning("No .env file found")
    end
  end
end
