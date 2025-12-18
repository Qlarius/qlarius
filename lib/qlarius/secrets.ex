defmodule Qlarius.Secrets do
  @moduledoc """
  Fetches secrets from AWS Systems Manager Parameter Store.

  In production, secrets are fetched from AWS SSM.
  In development, falls back to environment variables.

  Secrets are cached in memory to avoid repeated AWS API calls.
  """

  require Logger

  @cache_table :secrets_cache

  def init do
    :ets.new(@cache_table, [:set, :public, :named_table, read_concurrency: true])
  end

  @doc """
  Fetches Twilio configuration from Parameter Store or environment variables.

  Returns a map with keys: account_sid, auth_token, verify_service_sid
  """
  def fetch_twilio_config do
    case get_from_cache(:twilio_config) do
      {:ok, config} ->
        config

      :miss ->
        config = fetch_twilio_config_from_source()
        put_in_cache(:twilio_config, config, ttl_seconds: 300)
        config
    end
  end

  @doc """
  Fetches the encryption key (CLOAK_KEY) from Parameter Store or environment.
  """
  def fetch_cloak_key do
    case get_from_cache(:cloak_key) do
      {:ok, key} ->
        key

      :miss ->
        key = fetch_cloak_key_from_source()
        put_in_cache(:cloak_key, key, ttl_seconds: 3600)
        key
    end
  end

  defp fetch_twilio_config_from_source do
    if Mix.env() == :prod do
      fetch_from_aws_ssm()
    else
      fetch_from_env_vars()
    end
  end

  defp fetch_cloak_key_from_source do
    if Mix.env() == :prod do
      case fetch_parameter("/qlarius/cloak-key") do
        {:ok, key} ->
          Base.decode64!(key)
        {:error, _} ->
          raise "CLOAK_KEY not found in AWS Parameter Store"
      end
    else
      case System.get_env("CLOAK_KEY") do
        nil -> raise "CLOAK_KEY environment variable not set"
        key -> Base.decode64!(key)
      end
    end
  end

  defp fetch_from_aws_ssm do
    Logger.info("Fetching Twilio credentials from AWS Parameter Store")

    with {:ok, account_sid} <- fetch_parameter("/qlarius/twilio/account-sid"),
         {:ok, auth_token} <- fetch_parameter("/qlarius/twilio/auth-token"),
         {:ok, verify_sid} <- fetch_parameter("/qlarius/twilio/verify-service-sid") do
      %{
        account_sid: account_sid,
        auth_token: auth_token,
        verify_service_sid: verify_sid
      }
    else
      {:error, reason} ->
        Logger.error("Failed to fetch Twilio config from AWS: #{inspect(reason)}")
        raise "Failed to fetch Twilio credentials from AWS Parameter Store"
    end
  end

  defp fetch_from_env_vars do
    Logger.info("Fetching Twilio credentials from environment variables")

    %{
      account_sid: System.get_env("TWILIO_ACCOUNT_SID", ""),
      auth_token: System.get_env("TWILIO_AUTH_TOKEN", ""),
      verify_service_sid: System.get_env("TWILIO_VERIFY_SERVICE_SID", "")
    }
  end

  defp fetch_parameter(name) do
    try do
      result =
        ExAws.SSM.get_parameter(name, with_decryption: true)
        |> ExAws.request()

      case result do
        {:ok, %{"Parameter" => %{"Value" => value}}} ->
          {:ok, value}

        {:error, {:http_error, 400, %{body: body}}} ->
          Logger.error("Parameter #{name} not found: #{body}")
          {:error, :not_found}

        {:error, reason} ->
          Logger.error("Failed to fetch parameter #{name}: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Exception fetching parameter #{name}: #{inspect(e)}")
        {:error, :exception}
    end
  end

  defp get_from_cache(key) do
    case :ets.lookup(@cache_table, key) do
      [{^key, value, expires_at}] ->
        if System.system_time(:second) < expires_at do
          {:ok, value}
        else
          :ets.delete(@cache_table, key)
          :miss
        end

      [] ->
        :miss
    end
  end

  defp put_in_cache(key, value, opts) do
    ttl = Keyword.get(opts, :ttl_seconds, 300)
    expires_at = System.system_time(:second) + ttl
    :ets.insert(@cache_table, {key, value, expires_at})
  end
end
