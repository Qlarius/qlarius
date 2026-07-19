defmodule QlariusWeb.Auth.ExtensionExchangeController do
  @moduledoc """
  Thin extension ↔ Phoenix session bridge.

  * `POST /auth/extension_exchange` — redeem a vault `ExtensionIdentityToken`
    into a normal browser session via `UserAuth.log_in_user_from_finalize/3`.
  * `POST /auth/extension_token` — mint a vault token for the current
    session user (echo login into the extension).
  * `POST /auth/invalidate_extension_token` — revoke a vault token on
    global logout.
  * `GET /auth/session_status` — `{authed: boolean}` for the JS bridge.
  """

  use QlariusWeb, :controller

  alias Qlarius.Accounts
  alias Qlarius.Auth.AuditLog
  alias Qlarius.Auth.RateLimit
  alias QlariusWeb.Auth.ExtensionIdentityToken
  alias QlariusWeb.UserAuth

  plug :accepts, ["json"]

  def session_status(conn, _params) do
    authed? =
      case conn.assigns[:current_scope] do
        %{true_user: %{id: _}} -> true
        _ -> false
      end

    json(conn, %{authed: authed?})
  end

  def create(conn, %{"token" => token} = params) when is_binary(token) do
    unless exchange_enabled?() do
      send_json_error(conn, 503, "exchange_disabled")
    else
      ip = conn.remote_ip |> RateLimit.format_ip()

      case RateLimit.check_extension_exchange_per_ip(ip) do
        :ok ->
          do_exchange(conn, token, Map.get(params, "device_id"), ip)

        {:error, {:rate_limited, _}} ->
          AuditLog.log(:"extension_exchange.denied", %{ip: ip, reason: :rate_limited})
          send_json_error(conn, 429, "rate_limited")
      end
    end
  end

  def create(conn, _params) do
    ip = conn.remote_ip |> RateLimit.format_ip()
    AuditLog.log(:"extension_exchange.denied", %{ip: ip, reason: :missing_token})
    send_json_error(conn, 422, "missing_token")
  end

  def mint(conn, %{"device_id" => device_id})
      when is_binary(device_id) and device_id != "" do
    unless emit_enabled?() do
      send_json_error(conn, 503, "emit_disabled")
    else
      case current_user(conn) do
        nil ->
          send_json_error(conn, 401, "unauthenticated")

        user ->
          token =
            ExtensionIdentityToken.sign(%{
              user_id: user.id,
              device_id: device_id,
              surface: "extension_mint"
            })

          AuditLog.log(:"extension_token.minted", %{
            ip: RateLimit.format_ip(conn.remote_ip),
            user_id: user.id
          })

          json(conn, %{token: token})
      end
    end
  end

  def mint(conn, _params) do
    send_json_error(conn, 422, "missing_device_id")
  end

  def invalidate(conn, %{"token" => token}) when is_binary(token) do
    ip = conn.remote_ip |> RateLimit.format_ip()

    case ExtensionIdentityToken.invalidate_token(token) do
      :ok ->
        AuditLog.log(:"extension_token.invalidated", %{ip: ip})
        send_resp(conn, 204, "")

      {:error, :expired} ->
        # Already unusable — treat as success so logout is idempotent.
        send_resp(conn, 204, "")

      {:error, :invalidated} ->
        send_resp(conn, 204, "")

      {:error, :invalid} ->
        AuditLog.log(:"extension_token.invalidate_denied", %{ip: ip, reason: :token_invalid})
        send_json_error(conn, 422, "invalid_token")
    end
  end

  def invalidate(conn, _params) do
    send_json_error(conn, 422, "missing_token")
  end

  @doc """
  CSRF-free logout for the extension service worker fan-out.

  Verifies the vault token, invalidates it, and clears the session
  cookie on this host via `UserAuth.clear_user_session/1`.
  """
  def remote_logout(conn, %{"token" => token}) when is_binary(token) do
    ip = conn.remote_ip |> RateLimit.format_ip()

    case ExtensionIdentityToken.verify(token) do
      {:ok, payload} ->
        ExtensionIdentityToken.invalidate(payload.jti)
        AuditLog.log(:"extension_token.invalidated", %{ip: ip, user_id: payload.user_id})

        conn
        |> UserAuth.clear_user_session()
        |> send_resp(204, "")

      {:error, :expired} ->
        send_resp(conn, 204, "")

      {:error, :invalidated} ->
        send_resp(conn, 204, "")

      {:error, :invalid} ->
        send_json_error(conn, 422, "invalid_token")
    end
  end

  def remote_logout(conn, _params) do
    send_json_error(conn, 422, "missing_token")
  end

  defp do_exchange(conn, token, device_id, ip) do
    case ExtensionIdentityToken.verify(token) do
      {:ok, payload} ->
        if device_id_mismatch?(payload, device_id) do
          AuditLog.log(:"extension_exchange.denied", %{
            ip: ip,
            reason: :device_mismatch,
            user_id: payload.user_id
          })

          send_json_error(conn, 422, "device_mismatch")
        else
          case Accounts.get_user(payload.user_id) do
            nil ->
              AuditLog.log(:"extension_exchange.denied", %{
                ip: ip,
                reason: :unknown_user,
                user_id: payload.user_id
              })

              send_json_error(conn, 422, "invalid_token")

            user ->
              AuditLog.log(:"extension_exchange.allowed", %{ip: ip, user_id: user.id})

              conn
              |> UserAuth.log_in_user_from_finalize(user, remember_me: true)
              |> send_resp(204, "")
          end
        end

      {:error, :expired} ->
        AuditLog.log(:"extension_exchange.denied", %{ip: ip, reason: :token_expired})
        send_json_error(conn, 422, "token_expired")

      {:error, :invalidated} ->
        AuditLog.log(:"extension_exchange.denied", %{ip: ip, reason: :token_invalidated})
        send_json_error(conn, 422, "token_invalidated")

      {:error, :invalid} ->
        AuditLog.log(:"extension_exchange.denied", %{ip: ip, reason: :token_invalid})
        send_json_error(conn, 422, "invalid_token")
    end
  end

  defp device_id_mismatch?(%{device_id: expected}, provided)
       when is_binary(provided) and provided != "" do
    expected != provided
  end

  # Older clients may omit device_id; still accept if token verifies.
  defp device_id_mismatch?(_payload, _provided), do: false

  defp current_user(conn) do
    case conn.assigns[:current_scope] do
      %{true_user: user} when not is_nil(user) -> user
      _ -> nil
    end
  end

  defp exchange_enabled? do
    Application.get_env(:qlarius, :auth_sheet, [])
    |> Keyword.get(:extension_exchange_enabled, false)
  end

  defp emit_enabled? do
    Application.get_env(:qlarius, :auth_sheet, [])
    |> Keyword.get(:extension_token_emit, false)
  end

  defp send_json_error(conn, status, code) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(%{error: code}))
  end
end
