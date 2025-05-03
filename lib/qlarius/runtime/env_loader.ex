defmodule Qlarius.Runtime.EnvLoader do
  require Logger

  def load do
    Logger.debug("EnvLoader starting...")
    config = Application.get_env(:qlarius, __MODULE__)
    Logger.debug("EnvLoader config: #{inspect(config)}")

    if config do
      env_file = config[:env_file]
      Logger.debug("Attempting to load env file: #{env_file}")

      if Code.ensure_loaded?(Dotenvy) do
        Logger.debug("Dotenvy is loaded")
        case Dotenvy.source([env_file]) do
          {:ok, envs} when is_map(envs) ->
            Logger.debug("Successfully loaded environment variables: #{inspect(Map.keys(envs))}")
            # Apply environment variables and log them
            for {key, value} <- envs do
              System.put_env(key, value)
              if key in ["DATABASE_URL", "LEGACY_DATABASE_URL"] do
                Logger.info("Loaded #{key}: #{String.slice(value, 0, 10)}...")
              end
            end

            # Log all current environment variables related to the database
            Logger.debug("Current environment state:")
            Logger.debug("DATABASE_URL=#{inspect(System.get_env("DATABASE_URL"))}")
            Logger.debug("LEGACY_DATABASE_URL=#{inspect(System.get_env("LEGACY_DATABASE_URL"))}")
            Logger.debug("DB_USER=#{inspect(System.get_env("DB_USER"))}")
            Logger.debug("DB_HOST=#{inspect(System.get_env("DB_HOST"))}")

            # Verify critical environment variables
            unless System.get_env("DATABASE_URL") || System.get_env("LEGACY_DATABASE_URL") do
              Logger.warning("""
              Neither DATABASE_URL nor LEGACY_DATABASE_URL is set in #{env_file}.
              This may cause the application to fall back to local database configuration.
              """)
            end

          {:error, reason} ->
            Logger.warning("""
            Failed to load #{env_file}: #{inspect(reason)}
            This may cause the application to fall back to local database configuration.
            """)
        end
      else
        Logger.warning("Dotenvy not available")
      end
    else
      Logger.warning("No configuration found for EnvLoader")
    end
  end
end
