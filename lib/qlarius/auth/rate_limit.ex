defmodule Qlarius.Auth.RateLimit do
  @moduledoc """
  Rate-limit gates for AuthSheet + finalize-session surfaces. B8 slice.

  Three gates, each backed by Hammer's ETS backend:

    * `check_send_code_per_phone/1` — 3 attempts per 10 minutes, keyed
      by the formatted phone number. Primary defense against Twilio
      bill abuse: every allowed attempt triggers one outbound SMS.

    * `check_send_code_per_ip/1` — 10 attempts per hour, keyed by IP.
      Caps mass phone-number enumeration from a single client even
      when the attacker rotates numbers faster than the per-phone
      window.

    * `check_finalize_per_ip/1` — 20 attempts per hour, keyed by IP.
      Caps `POST /auth/finalize_session` token brute-force (the
      endpoint already fails replayed or expired tokens with a 422,
      but a loud attacker can still probe signed-token space; this
      is belt-and-suspenders).

  All functions return `:ok` when allowed, or
  `{:error, {:rate_limited, retry_after_seconds}}` when denied. The
  retry-after is a conservative ceiling (full window) — Hammer's
  ETS bucket doesn't give us a precise "next slot" time, but a
  window-length hint keeps the user guidance actionable without
  over-engineering.

  ## Disabling

  Controlled by a single master flag (no per-gate toggles — if any
  one gate is off the protections aren't meaningful):

      config :qlarius, :auth_rate_limit, enabled?: true

  When disabled all three functions short-circuit to `:ok`. Default
  off in `config/test.exs` (so test suites don't trip over
  shared-window counters between runs); on everywhere else.

  ## IP handling

  IPs arrive from `GetUserIP` (LiveView) or `conn.remote_ip` (Plug).
  `skip_ip?/1` treats the default `"0.0.0.0"` / `nil` / `""` as
  "unknown" — when an IP can't be resolved (e.g. misconfigured
  proxy headers in dev), we skip the per-IP gate rather than
  lump all unknown-IP traffic into a single bucket and
  inadvertently lock out all users.
  """

  @per_phone_window_ms 10 * 60 * 1_000
  @per_phone_limit 3

  @per_ip_send_code_window_ms 60 * 60 * 1_000
  @per_ip_send_code_limit 10

  @per_ip_finalize_window_ms 60 * 60 * 1_000
  @per_ip_finalize_limit 20

  @type result :: :ok | {:error, {:rate_limited, non_neg_integer()}}

  @spec check_send_code_per_phone(String.t() | nil) :: result()
  def check_send_code_per_phone(phone) when is_binary(phone) and phone != "" do
    check("auth_sheet:send_code:phone:#{phone}", @per_phone_window_ms, @per_phone_limit)
  end

  def check_send_code_per_phone(_), do: :ok

  @spec check_send_code_per_ip(String.t() | nil) :: result()
  def check_send_code_per_ip(ip) do
    if skip_ip?(ip) do
      :ok
    else
      check(
        "auth_sheet:send_code:ip:#{ip}",
        @per_ip_send_code_window_ms,
        @per_ip_send_code_limit
      )
    end
  end

  @spec check_finalize_per_ip(String.t() | nil) :: result()
  def check_finalize_per_ip(ip) do
    if skip_ip?(ip) do
      :ok
    else
      check(
        "auth:finalize:ip:#{ip}",
        @per_ip_finalize_window_ms,
        @per_ip_finalize_limit
      )
    end
  end

  @doc """
  True when the rate-limit subsystem is considered unavailable or
  intentionally disabled. Callers usually don't need this — the
  `check_*` functions already respect the flag — but it's exported
  so diagnostic endpoints can report status without duplicating the
  config read.
  """
  @spec enabled?() :: boolean()
  def enabled? do
    Application.get_env(:qlarius, :auth_rate_limit, [])
    |> Keyword.get(:enabled?, true)
  end

  @doc """
  Formats a `:inet.ip_address/0` tuple (as from `conn.remote_ip`) into
  the string form we use as a bucket key. Accepts strings passthrough
  for callers that already have string IPs (LiveView's `:user_ip`).
  """
  @spec format_ip(:inet.ip_address() | String.t() | nil) :: String.t() | nil
  def format_ip(nil), do: nil
  def format_ip(ip) when is_binary(ip), do: ip

  def format_ip(ip) when is_tuple(ip) do
    case :inet.ntoa(ip) do
      {:error, _} -> nil
      charlist -> List.to_string(charlist)
    end
  end

  # --- internal -------------------------------------------------------

  defp check(key, window_ms, limit) do
    if enabled?() do
      case Hammer.check_rate(key, window_ms, limit) do
        {:allow, _count} ->
          :ok

        {:deny, _count} ->
          {:error, {:rate_limited, div(window_ms, 1_000)}}
      end
    else
      :ok
    end
  end

  defp skip_ip?(nil), do: true
  defp skip_ip?(""), do: true
  defp skip_ip?("0.0.0.0"), do: true
  defp skip_ip?(_), do: false
end
