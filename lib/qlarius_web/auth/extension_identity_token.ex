defmodule QlariusWeb.Auth.ExtensionIdentityToken do
  @moduledoc """
  Long-lived, device-bound `Phoenix.Token` stored in the browser extension
  vault and redeemed via `POST /auth/extension_exchange` into a normal
  Phoenix session (`UserAuth.log_in_user_from_finalize/3`).

  Unlike `FinalizeToken`, these tokens are multi-use until expiry (or
  explicit invalidation on global logout). They are never a second
  session system — only a signed handoff into the standard cookie path.
  """

  alias QlariusWeb.Endpoint

  @salt "qadabra extension identity v1"
  # 7 days
  @max_age_seconds 7 * 24 * 60 * 60
  @jti_table :qadabra_extension_identity_jti

  @type payload :: %{
          required(:user_id) => integer(),
          required(:device_id) => String.t(),
          optional(:surface) => String.t() | nil
        }

  @doc """
  Sign an identity token for the extension vault.
  """
  @spec sign(payload()) :: String.t()
  def sign(%{user_id: user_id, device_id: device_id} = fields)
      when is_integer(user_id) and is_binary(device_id) and device_id != "" do
    payload = %{
      user_id: user_id,
      device_id: device_id,
      surface: Map.get(fields, :surface),
      jti: generate_jti(),
      iat: System.system_time(:second)
    }

    Phoenix.Token.sign(Endpoint, @salt, payload)
  end

  @doc """
  Verify a vault token without consuming it.

  Returns `{:error, :invalidated}` when the `jti` was revoked via
  `invalidate/1`.
  """
  @spec verify(String.t()) ::
          {:ok, map()} | {:error, :invalid | :expired | :invalidated}
  def verify(token) when is_binary(token) do
    case Phoenix.Token.verify(Endpoint, @salt, token, max_age: @max_age_seconds) do
      {:ok, %{jti: jti, user_id: user_id, device_id: device_id} = payload}
      when is_binary(jti) and is_integer(user_id) and is_binary(device_id) ->
        if invalidated?(jti) do
          {:error, :invalidated}
        else
          {:ok, payload}
        end

      {:ok, _malformed} ->
        {:error, :invalid}

      {:error, :expired} ->
        {:error, :expired}

      {:error, _} ->
        {:error, :invalid}
    end
  end

  def verify(_), do: {:error, :invalid}

  @doc """
  Revoke a token by `jti` until its natural expiry window elapses.
  """
  @spec invalidate(String.t()) :: :ok
  def invalidate(jti) when is_binary(jti) and jti != "" do
    ensure_table()
    expires_at = System.system_time(:second) + @max_age_seconds
    :ets.insert(@jti_table, {jti, expires_at})
    :ok
  end

  def invalidate(_), do: :ok

  @doc """
  Invalidate from a full token string (verify first, then revoke `jti`).
  """
  @spec invalidate_token(String.t()) :: :ok | {:error, :invalid | :expired | :invalidated}
  def invalidate_token(token) when is_binary(token) do
    case verify(token) do
      {:ok, %{jti: jti}} ->
        invalidate(jti)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  def invalidate_token(_), do: {:error, :invalid}

  @doc false
  @spec jti_table() :: atom()
  def jti_table, do: @jti_table

  @doc false
  @spec max_age_seconds() :: pos_integer()
  def max_age_seconds, do: @max_age_seconds

  defp invalidated?(jti) do
    ensure_table()

    case :ets.lookup(@jti_table, jti) do
      [{^jti, _expires_at}] -> true
      [] -> false
    end
  end

  defp generate_jti do
    16 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end

  defp ensure_table do
    case :ets.whereis(@jti_table) do
      :undefined ->
        :ets.new(@jti_table, [:set, :public, :named_table, read_concurrency: true])

      _ref ->
        :ok
    end
  rescue
    ArgumentError -> :ok
  end
end
