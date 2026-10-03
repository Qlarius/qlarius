defmodule Qlarius.AdminApi.PtpDefaults do
  @moduledoc """
  Frequency settings for a PTP media sequence.

  A caller can override any of them. Otherwise the value comes from a Global
  Variable, and from the number here when that variable has not been set.
  """

  alias Qlarius.System

  @settings [
    {"frequency", "PTP_SEQUENCE_FREQUENCY", 3},
    {"frequency_buffer_hours", "PTP_SEQUENCE_FREQUENCY_BUFFER_HOURS", 96},
    {"maximum_banner_count", "PTP_SEQUENCE_MAX_BANNER_COUNT", 3},
    {"banner_retry_buffer_hours", "PTP_SEQUENCE_BANNER_RETRY_BUFFER_HOURS", 48}
  ]

  def resolve(params) do
    Enum.reduce(@settings, {%{}, []}, fn {key, var, fallback}, {values, from_defaults} ->
      case params[key] do
        value when value in [nil, ""] ->
          {Map.put(values, key, System.get_global_variable_int(var, fallback)),
           [key | from_defaults]}

        value ->
          {Map.put(values, key, value), from_defaults}
      end
    end)
    |> then(fn {values, from_defaults} -> {values, Enum.reverse(from_defaults)} end)
  end
end
