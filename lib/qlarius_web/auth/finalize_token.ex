defmodule QlariusWeb.Auth.FinalizeToken do
  @moduledoc """
  Single-use, short-lived exchange token used by the `AuthSheet` flow to
  convert an authenticated LiveView session into a browser session cookie
  without a page navigation.

  See `docs/qlink_auth_refactor_plan.md` §5.9.

  ## Design

    * Signed by `Phoenix.Token.sign/3` using the endpoint's
      `secret_key_base` (keyed by the `@salt` constant below). No separate
      Vault-managed key is required — the salt scopes the token so a leaked
      token can't be replayed against any other `Phoenix.Token` consumer in
      the app.
    * TTL: 60 seconds. Short enough to narrow the replay window, long
      enough to survive a slow browser `fetch` + socket reconnect.
    * Single-use: every token carries a random `jti`. The first successful
      redemption stores the `jti` in an ETS table; subsequent redemptions
      of the same `jti` are rejected. Expired entries are swept out
      periodically by a companion GenServer so the table doesn't grow
      unbounded.

  ## Token shape

      %{
        user_id: integer(),
        resume: String.t() | nil,   # opaque resume intent (e.g. "tip:42")
        surface: String.t() | nil,  # emitting surface label for audit
        jti: String.t(),            # 16 bytes hex, single-use guard
        iat: integer()              # issued-at unix seconds
      }
  """

  alias QlariusWeb.Endpoint

  @salt "qadabra auth finalize v1"
  @max_age_seconds 60
  @jti_table :qadabra_finalize_jti

  @type payload :: %{
          required(:user_id) => integer(),
          optional(:resume) => String.t() | nil,
          optional(:surface) => String.t() | nil
        }

  @doc """
  Create a signed, single-use finalize token for the given user.

  Accepts `:resume` and `:surface` as optional keys.
  """
  @spec sign(payload()) :: String.t()
  def sign(%{user_id: user_id} = fields) when is_integer(user_id) do
    payload = %{
      user_id: user_id,
      resume: Map.get(fields, :resume),
      surface: Map.get(fields, :surface),
      jti: generate_jti(),
      iat: System.system_time(:second)
    }

    Phoenix.Token.sign(Endpoint, @salt, payload)
  end

  @doc """
  Verify and consume a finalize token.

  On success returns `{:ok, payload}` and records the token's `jti` so it
  cannot be reused. On failure returns one of:

    * `{:error, :invalid}` — signature or format failure
    * `{:error, :expired}` — older than the TTL
    * `{:error, :replayed}` — `jti` already seen
  """
  @spec verify_and_consume(String.t()) ::
          {:ok, payload :: map()} | {:error, :invalid | :expired | :replayed}
  def verify_and_consume(token) when is_binary(token) do
    case Phoenix.Token.verify(Endpoint, @salt, token, max_age: @max_age_seconds) do
      {:ok, %{jti: jti} = payload} when is_binary(jti) ->
        if claim_jti(jti, payload) do
          {:ok, payload}
        else
          {:error, :replayed}
        end

      {:ok, _malformed} ->
        {:error, :invalid}

      {:error, :expired} ->
        {:error, :expired}

      {:error, _reason} ->
        {:error, :invalid}
    end
  end

  def verify_and_consume(_), do: {:error, :invalid}

  @doc false
  @spec jti_table() :: atom()
  def jti_table, do: @jti_table

  @doc false
  @spec max_age_seconds() :: pos_integer()
  def max_age_seconds, do: @max_age_seconds

  defp generate_jti do
    16 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end

  # Inserts the jti into the ETS table iff it is not already there. Returns
  # `true` when the insertion succeeded (first use), `false` when a prior
  # redemption already claimed the jti.
  defp claim_jti(jti, _payload) do
    ensure_table()
    expires_at = System.system_time(:second) + @max_age_seconds
    :ets.insert_new(@jti_table, {jti, expires_at})
  end

  # Defensive fallback — the Sweeper GenServer creates the table on boot,
  # but we guard in case the helper is invoked before the supervision tree
  # is running (e.g. in isolated unit tests).
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
