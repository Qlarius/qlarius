defmodule Qlarius.Auth.PhoneCarrierRejections do
  @moduledoc """
  Durable append-only log of Twilio Lookup / carrier-filter rejections for
  analytics, threat review, and skipping repeat Lookup calls while
  `blocked_until` is in the future.

  Phone numbers are stored in full E.164 form (`+1…`) for operational use;
  callers are not customers at rejection time. See retention policy in
  ops docs when added.
  """

  import Ecto.Query

  alias Qlarius.Auth.PhoneCarrierRejection
  alias Qlarius.Repo

  @default_block_days 30

  defp block_days do
    Application.get_env(:qlarius, :phone_carrier_rejection_block_days, @default_block_days)
  end

  @doc """
  NANP area code (first three digits of the national number) from `+1` E.164,
  or `nil` if not parseable.
  """
  def extract_nanp_area_code(phone_e164) when is_binary(phone_e164) do
    d = String.replace(phone_e164, ~r/\D/, "")

    cond do
      String.starts_with?(d, "1") and byte_size(d) == 11 ->
        String.slice(d, 1, 3)

      byte_size(d) == 10 ->
        String.slice(d, 0, 3)

      true ->
        nil
    end
  end

  def extract_nanp_area_code(_), do: nil

  @doc """
  Builds `blocked_until` as now + configured days (default #{@default_block_days}).
  """
  def default_blocked_until do
    DateTime.utc_now()
    |> DateTime.add(block_days() * 86_400, :second)
    |> DateTime.truncate(:microsecond)
  end

  @doc """
  Inserts a rejection row. Sets `blocked_until` if omitted.
  Accepts optional Twilio-shaped `lookup_snapshot` map for drill-down.
  """
  def record_rejection(attrs) when is_map(attrs) do
    attrs =
      attrs
      |> Map.put_new_lazy(:blocked_until, &default_blocked_until/0)
      |> normalize_phone_and_area()

    %PhoneCarrierRejection{}
    |> PhoneCarrierRejection.changeset(attrs)
    |> Repo.insert()
  end

  defp normalize_phone_and_area(%{phone_number: phone} = attrs) when is_binary(phone) do
    area = extract_nanp_area_code(phone)

    attrs
    |> Map.put(:area_code, Map.get(attrs, :area_code) || area)
  end

  defp normalize_phone_and_area(attrs), do: attrs

  @doc """
  Returns the most recent rejection for this E.164 number that is still
  active (`blocked_until > now`), or `nil`. Use to skip Twilio Lookup
  and replay messaging.
  """
  def active_block_for_phone(phone_e164) when is_binary(phone_e164) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    PhoneCarrierRejection
    |> where([r], r.phone_number == ^phone_e164)
    |> where([r], r.blocked_until > ^now)
    |> order_by([r], desc: r.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  def active_block_for_phone(_), do: nil

  @doc """
  Whether an active block exists for the phone (same as `active_block_for_phone/1` != nil).
  """
  def blocked?(phone_e164), do: active_block_for_phone(phone_e164) != nil
end
