defmodule Qlarius.Auth.AuditLog do
  @moduledoc """
  Structured audit log for AuthSheet + finalize-session decision
  points. B8b slice (see `docs/qlink_auth_refactor_plan.md` §B8).

  All output goes through `Logger.info/2` with `auth_event` +
  `auth_meta` metadata fields — queryable in whatever log aggregator
  the env terminates into (Fly, AppSignal, Logflare, etc.). No DB
  table by design; if queryable history becomes necessary we'll add
  an append-only table and dual-emit, but the immediate goal is
  operational visibility for the rate-limit + AuthSheet flows we
  just shipped (so we can tell *whether* a captcha follow-up is
  warranted, and give support a traceback for "what happened on
  this phone/IP in the last hour").

  ## Event taxonomy

  Each `log/2` call emits exactly one structured line. Event names
  are dotted to keep the hierarchy obvious in grep / log-agg filters:

      send_code.allowed        %{phone_masked, ip, surface}
      send_code.denied         %{phone_masked, ip, surface, reason,
                                  retry_after_s?}
         reasons: :phone_limit | :ip_limit | :invalid_phone
                | :twilio_error

      verify_code.allowed      %{phone_masked, ip, surface, outcome}
         outcomes: :signed_in | :new_user_branch
      verify_code.denied       %{phone_masked, ip, surface, reason}
         reasons: :incorrect_code | :not_mobile_carrier | :twilio_error

      register_new_user.allowed %{user_id, alias, ip, surface,
                                   referral_source}
      register_new_user.denied  %{phone_masked, ip, surface,
                                   failed_step}

      finalize_session.allowed  %{user_id, ip}
      finalize_session.denied   %{ip, reason}
         reasons: :rate_limited | :token_expired | :token_replayed
                | :token_invalid | :unknown_user | :missing_token

      extension_exchange.allowed %{user_id, ip}
      extension_exchange.denied  %{ip, reason, user_id?}
      extension_token.minted     %{user_id, ip}
      extension_token.invalidated %{ip}
      extension_token.invalidate_denied %{ip, reason}

  ## PII policy

    * **Phone numbers** are always masked via `mask_phone/1` — last
      four digits preserved, rest replaced with `*`. Never log the
      full number.
    * **OTP codes** are never logged.
    * **IPs** are logged raw. Operational value is high and
      sensitivity is low (IPs are already in access logs upstream).
    * **User IDs + aliases** are logged. They're internal identifiers,
      no different from what lands in Ecto query logs.

  ## Unknown-field safety

  Extra fields in the metadata map are passed through untouched;
  call sites should prefer specific named fields over dumping
  changesets or socket assigns to avoid accidentally leaking PII.
  """

  require Logger

  @type event ::
          :"send_code.allowed"
          | :"send_code.denied"
          | :"verify_code.allowed"
          | :"verify_code.denied"
          | :"register_new_user.allowed"
          | :"register_new_user.denied"
          | :"finalize_session.allowed"
          | :"finalize_session.denied"
          | :"extension_exchange.allowed"
          | :"extension_exchange.denied"
          | :"extension_token.minted"
          | :"extension_token.invalidated"
          | :"extension_token.invalidate_denied"

  @doc """
  Emit a single structured audit line.

  Applies PII masking to any `:phone` / `:mobile_number` key in
  `metadata` before logging — call sites don't need to pre-mask.
  """
  @spec log(event(), map()) :: :ok
  def log(event, metadata) when is_atom(event) and is_map(metadata) do
    masked = sanitize(metadata)
    message = "auth_event #{event} #{format_meta(masked)}"

    Logger.info(message, auth_event: event, auth_meta: masked)
    :ok
  end

  @doc """
  Mask a phone number to its last four digits.

  Exported so call sites that still need to log a masked phone
  outside the structured path (e.g. the existing rate-limit warning
  in AuthSheet) can reuse the same masking rule.
  """
  @spec mask_phone(String.t() | nil) :: String.t()
  def mask_phone(nil), do: "****"

  def mask_phone("+" <> rest), do: "+" <> mask_phone(rest)

  def mask_phone(phone) when is_binary(phone) do
    digits = String.replace(phone, ~r/\D/, "")

    case String.length(digits) do
      n when n >= 4 -> String.duplicate("*", n - 4) <> String.slice(digits, -4, 4)
      _ -> String.duplicate("*", String.length(digits))
    end
  end

  def mask_phone(_), do: "****"

  # --- internals ------------------------------------------------------

  # Walks the metadata once:
  # * `:phone` / `:mobile_number` → `:phone_masked` (original key dropped)
  # * everything else passed through
  defp sanitize(metadata) do
    Enum.reduce(metadata, %{}, fn
      {key, value}, acc when key in [:phone, :mobile_number] ->
        Map.put(acc, :phone_masked, mask_phone(value))

      {key, value}, acc ->
        Map.put(acc, key, value)
    end)
  end

  # Stable key order for human-readable grepping. Any keys not in
  # the preferred list trail the known ones in natural sort order —
  # this keeps log lines consistent across events of the same type
  # while remaining forgiving of ad-hoc extra fields.
  @preferred_key_order [
    :phone_masked,
    :ip,
    :surface,
    :reason,
    :outcome,
    :user_id,
    :alias,
    :referral_source,
    :failed_step,
    :retry_after_s
  ]

  defp format_meta(meta) do
    preferred =
      @preferred_key_order
      |> Enum.flat_map(fn key ->
        case Map.fetch(meta, key) do
          {:ok, value} -> [{key, value}]
          :error -> []
        end
      end)

    rest =
      meta
      |> Map.drop(@preferred_key_order)
      |> Enum.sort()

    (preferred ++ rest)
    |> Enum.map_join(" ", fn {k, v} -> "#{k}=#{format_value(v)}" end)
  end

  defp format_value(v) when is_binary(v), do: v
  defp format_value(v) when is_atom(v), do: Atom.to_string(v)
  defp format_value(v), do: inspect(v)
end
