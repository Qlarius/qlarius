defmodule Qlarius.DatabaseConfig do
  use GenServer
  require Logger

  # Client API

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def child_spec(_args) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [[]]},
      restart: :permanent,
      type: :worker
    }
  end

  def get_current_mode do
    GenServer.call(__MODULE__, :get_mode)
  end

  def use_remote do
    GenServer.call(__MODULE__, :use_remote)
  end

  def use_local do
    GenServer.call(__MODULE__, :use_local)
  end

  def toggle_mode do
    Logger.debug("Attempting to toggle database mode")
    GenServer.call(__MODULE__, :toggle)
  end

  # Server callbacks

  @impl true
  def init(_init_arg) do
    # Start with local mode by default
    {:ok, %{mode: :local}}
  end

  @impl true
  def handle_call(:get_mode, _from, state) do
    {:reply, state.mode, state}
  end

  @impl true
  def handle_call(:use_remote, _from, state) do
    Logger.debug("Attempting to switch to remote database")
    case switch_to_remote() do
      :ok ->
        Logger.debug("Successfully switched to remote database")
        {:reply, :ok, %{state | mode: :remote}}
      {:error, reason} ->
        Logger.error("Failed to switch to remote database: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:use_local, _from, state) do
    Logger.debug("Attempting to switch to local database")
    switch_to_local()
    Logger.debug("Successfully switched to local database")
    {:reply, :ok, %{state | mode: :local}}
  end

  @impl true
  def handle_call(:toggle, _from, %{mode: current_mode} = state) do
    Logger.debug("Current mode: #{inspect(current_mode)}")
    new_mode = case current_mode do
      :local ->
        Logger.debug("Toggling from local to remote")
        case switch_to_remote() do
          :ok ->
            Logger.debug("Successfully switched to remote")
            :remote
          {:error, reason} ->
            Logger.error("Failed to switch to remote: #{inspect(reason)}")
            :local
        end
      :remote ->
        Logger.debug("Toggling from remote to local")
        switch_to_local()
        Logger.debug("Successfully switched to local")
        :local
    end

    Logger.debug("New mode: #{inspect(new_mode)}")
    {:reply, new_mode, %{state | mode: new_mode}}
  end

  # Private functions

  defp switch_to_remote do
    case get_remote_database_url() do
      {:ok, url} ->
        legacy_config = [
          url: url,
          ssl: true,
          ssl_opts: [verify: :verify_none],
          pool_size: 10
        ]

        restart_repo(Qlarius.LegacyRepo, legacy_config)
        :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp switch_to_local do
    legacy_config = [
      username: System.get_env("LOCAL_DB_USER") || "postgres",
      password: System.get_env("LOCAL_DB_PASS") || "postgres",
      hostname: System.get_env("LOCAL_DB_HOST") || "localhost",
      database: System.get_env("LOCAL_DB_NAME") || "qlarius_dev_rails",
      pool_size: 10
    ]

    restart_repo(Qlarius.LegacyRepo, legacy_config)
  end

  defp restart_repo(repo, config) do
    Logger.debug("Restarting repo with config: #{inspect(config, pretty: true)}")

    # Apply new configuration
    Application.put_env(:qlarius, repo, config)

    # Stop the repo
    case repo.stop() do
      :ok ->
        # Wait a brief moment to ensure clean shutdown
        Process.sleep(100)

        # Start the repo with new config
        case repo.start_link(config) do
          {:ok, _pid} ->
            Logger.debug("Successfully restarted #{inspect(repo)}")
            :ok
          {:error, {:already_started, _pid}} ->
            Logger.debug("#{inspect(repo)} was already started")
            :ok
          {:error, reason} ->
            Logger.error("Failed to start #{inspect(repo)}: #{inspect(reason)}")
            {:error, reason}
        end
      {:error, reason} ->
        Logger.error("Failed to stop #{inspect(repo)}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp get_remote_database_url do
    case Application.get_env(:qlarius, :remote_database_url) do
      nil ->
        Logger.error("Remote database URL is not configured")
        {:error, "Remote database URL is not configured"}
      url ->
        Logger.debug("Found remote database URL configuration")
        {:ok, url}
    end
  end
end
