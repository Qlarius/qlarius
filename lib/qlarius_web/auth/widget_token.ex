defmodule QlariusWeb.Auth.WidgetToken do
  @moduledoc """
  Signed tokens that stand in for the `_qlarius_key` cookie inside
  publisher widget iframes, where browsers that block third-party cookies
  never send it.

  Three kinds:

    * `:anon` — carries only the `session_sync_id`. Minted on every widget
      HTML render so sibling iframes on one page share a sync topic.
    * `:authed` — a hand-off. Carries the user session token, is minted
      only by the extension exchange and the Connect popup, lives two
      minutes, and is accepted once.
    * `:session` — a continuation. Same payload as `:authed` but
      multi-use and a day long. `QlariusWeb.WidgetSessionHooks` pushes one
      to the client after a token-backed authed mount so socket reconnects
      (network blips, longpoll fallback) do not drop the user back to
      anonymous. It is only as good as the DB session token inside it:
      logout deletes that token and every mount using it becomes anonymous.

  `QlariusWeb.WidgetSocket` verifies these on connect and turns them into
  the session map the cookie would have held.
  """

  alias QlariusWeb.Endpoint

  @salt "qadabra widget socket v1"
  @anon_max_age_seconds 24 * 60 * 60
  @session_max_age_seconds 24 * 60 * 60
  @authed_max_age_seconds 120
  @jti_table :qadabra_widget_token_jti

  @type kind :: :anon | :authed | :session

  @spec sign_anon(String.t() | nil) :: String.t()
  def sign_anon(sync_id) do
    Phoenix.Token.sign(Endpoint, @salt, %{kind: :anon, sync_id: sync_id})
  end

  @spec sign_authed(String.t(), String.t() | nil) :: String.t()
  def sign_authed(user_token, sync_id) when is_binary(user_token) do
    Phoenix.Token.sign(Endpoint, @salt, %{
      kind: :authed,
      user_token: user_token,
      sync_id: sync_id,
      jti: generate_jti()
    })
  end

  @spec sign_session(String.t(), String.t() | nil) :: String.t()
  def sign_session(user_token, sync_id) when is_binary(user_token) do
    Phoenix.Token.sign(Endpoint, @salt, %{
      kind: :session,
      user_token: user_token,
      sync_id: sync_id
    })
  end

  @doc """
  Verifies a token. An authed token is consumed on first success and
  refused afterwards.
  """
  @spec verify(term()) ::
          {:ok, %{kind: kind(), sync_id: String.t() | nil, user_token: String.t() | nil}}
          | {:error, :invalid | :expired | :used}
  def verify(token) when is_binary(token) and token != "" do
    case Phoenix.Token.verify(Endpoint, @salt, token, max_age: @anon_max_age_seconds) do
      {:ok, %{kind: :anon} = payload} ->
        {:ok, %{kind: :anon, sync_id: string_or_nil(payload[:sync_id]), user_token: nil}}

      {:ok, %{kind: :session, user_token: user_token} = payload} when is_binary(user_token) ->
        {:ok,
         %{kind: :session, sync_id: string_or_nil(payload[:sync_id]), user_token: user_token}}

      {:ok, %{kind: :authed, user_token: user_token, jti: jti} = payload}
      when is_binary(user_token) and is_binary(jti) ->
        verify_authed(token, user_token, jti, payload)

      {:ok, _other} ->
        {:error, :invalid}

      {:error, :expired} ->
        {:error, :expired}

      {:error, _} ->
        {:error, :invalid}
    end
  end

  def verify(_), do: {:error, :invalid}

  @doc """
  Session map for `Phoenix.LiveView.Socket` connect_info, mirroring the
  keys `QlariusWeb.UserAuth` writes into the cookie session. The
  `"widget_token_session"` marker tells `QlariusWeb.WidgetSessionHooks`
  the session did not come from a cookie.
  """
  @spec session_for(map()) :: map()
  def session_for(%{kind: kind, user_token: user_token, sync_id: sync_id})
      when kind in [:authed, :session] do
    %{
      "session_sync_id" => sync_id,
      "user_token" => user_token,
      "live_socket_id" => "users_sessions:#{Base.url_encode64(user_token)}",
      "widget_token_session" => true,
      "widget_token_kind" => Atom.to_string(kind)
    }
    |> drop_nil()
  end

  def session_for(%{kind: :anon, sync_id: sync_id}) do
    drop_nil(%{
      "session_sync_id" => sync_id,
      "widget_token_session" => true,
      "widget_token_kind" => "anon"
    })
  end

  @doc false
  def authed_max_age_seconds, do: @authed_max_age_seconds

  @doc false
  def session_max_age_seconds, do: @session_max_age_seconds

  @doc false
  def jti_table, do: @jti_table

  defp verify_authed(token, user_token, jti, payload) do
    case Phoenix.Token.verify(Endpoint, @salt, token, max_age: @authed_max_age_seconds) do
      {:ok, _} ->
        if mark_used(jti) do
          {:ok,
           %{kind: :authed, sync_id: string_or_nil(payload[:sync_id]), user_token: user_token}}
        else
          {:error, :used}
        end

      {:error, :expired} ->
        {:error, :expired}

      {:error, _} ->
        {:error, :invalid}
    end
  end

  # Returns true the first time a jti is seen.
  defp mark_used(jti) do
    ensure_table()
    sweep()
    expires_at = System.system_time(:second) + @authed_max_age_seconds
    :ets.insert_new(@jti_table, {jti, expires_at})
  end

  defp sweep do
    now = System.system_time(:second)
    :ets.select_delete(@jti_table, [{{:_, :"$1"}, [{:<, :"$1", now}], [true]}])
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

  defp generate_jti do
    16 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end

  defp string_or_nil(value) when is_binary(value) and value != "", do: value
  defp string_or_nil(_), do: nil

  defp drop_nil(map), do: map |> Enum.reject(fn {_k, v} -> is_nil(v) end) |> Map.new()
end
