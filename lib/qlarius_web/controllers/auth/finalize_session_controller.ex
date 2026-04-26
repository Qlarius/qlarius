defmodule QlariusWeb.Auth.FinalizeSessionController do
  @moduledoc """
  `POST /auth/finalize_session` — converts a signed, single-use
  `QlariusWeb.Auth.FinalizeToken` into an authenticated browser session
  cookie without any page navigation.

  Issued by the `AuthSheet` LiveComponent after phone verification (or
  user creation in B3+), fetched by the `AuthFinalize` JS hook. The
  client then disconnects/reconnects its LiveView socket to pick up the
  new scope in place. See `docs/qlink_auth_refactor_plan.md` §5.9.
  """

  use QlariusWeb, :controller

  alias Qlarius.Accounts
  alias Qlarius.Auth.AuditLog
  alias Qlarius.Auth.RateLimit
  alias QlariusWeb.Auth.FinalizeToken
  alias QlariusWeb.UserAuth

  plug :accepts, ["json"]

  def create(conn, %{"token" => token}) when is_binary(token) do
    # B8: per-IP gate before cryptographic verification. Cheap check,
    # and denies noisy probes without burning ETS bucket space on
    # `FinalizeTokenSweeper` `jti`s.
    ip = conn.remote_ip |> RateLimit.format_ip()

    case RateLimit.check_finalize_per_ip(ip) do
      :ok ->
        do_create(conn, token, ip)

      {:error, {:rate_limited, _retry_after_s}} ->
        AuditLog.log(:"finalize_session.denied", %{ip: ip, reason: :rate_limited})
        send_json_error(conn, 429, "rate_limited")
    end
  end

  def create(conn, _params) do
    ip = conn.remote_ip |> RateLimit.format_ip()
    AuditLog.log(:"finalize_session.denied", %{ip: ip, reason: :missing_token})
    send_json_error(conn, 422, "missing_token")
  end

  defp do_create(conn, token, ip) do
    case FinalizeToken.verify_and_consume(token) do
      {:ok, payload} ->
        case Accounts.get_user(payload.user_id) do
          nil ->
            AuditLog.log(:"finalize_session.denied", %{
              ip: ip,
              reason: :unknown_user,
              user_id: payload.user_id
            })

            send_json_error(conn, 422, "invalid_token")

          user ->
            AuditLog.log(:"finalize_session.allowed", %{
              ip: ip,
              user_id: user.id
            })

            conn
            |> UserAuth.log_in_user_from_finalize(user,
              resume: Map.get(payload, :resume),
              remember_me: true
            )
            |> send_resp(204, "")
        end

      {:error, :expired} ->
        AuditLog.log(:"finalize_session.denied", %{ip: ip, reason: :token_expired})
        send_json_error(conn, 422, "token_expired")

      {:error, :replayed} ->
        AuditLog.log(:"finalize_session.denied", %{ip: ip, reason: :token_replayed})
        send_json_error(conn, 422, "token_replayed")

      {:error, :invalid} ->
        AuditLog.log(:"finalize_session.denied", %{ip: ip, reason: :token_invalid})
        send_json_error(conn, 422, "invalid_token")
    end
  end

  defp send_json_error(conn, status, code) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(%{error: code}))
  end
end
