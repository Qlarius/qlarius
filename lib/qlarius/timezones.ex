defmodule Qlarius.Timezones do
  @moduledoc """
  US timezone definitions and helpers.
  """

  @us_timezones %{
    "Eastern" => "America/New_York",
    "Central" => "America/Chicago",
    "Mountain" => "America/Denver",
    "Mountain (Arizona)" => "America/Phoenix",
    "Pacific" => "America/Los_Angeles",
    "Alaska" => "America/Anchorage",
    "Hawaii" => "America/Honolulu",
    "Puerto Rico" => "America/Puerto_Rico"
  }

  @default_timezone "America/New_York"

  def list do
    # Return in chronological order (east to west across US)
    [
      {"Puerto Rico", "America/Puerto_Rico"},
      {"Eastern", "America/New_York"},
      {"Central", "America/Chicago"},
      {"Mountain", "America/Denver"},
      {"Mountain (Arizona)", "America/Phoenix"},
      {"Pacific", "America/Los_Angeles"},
      {"Alaska", "America/Anchorage"},
      {"Hawaii", "America/Honolulu"}
    ]
  end

  def get_label(iana_timezone) do
    @us_timezones
    |> Enum.find(fn {_label, iana} -> iana == iana_timezone end)
    |> case do
      {label, _iana} -> label
      nil -> iana_timezone
    end
  end

  def default do
    @default_timezone
  end

  def valid?(timezone) do
    timezone in Map.values(@us_timezones)
  end

  def detect_from_browser(browser_timezone) do
    cond do
      browser_timezone in Map.values(@us_timezones) ->
        browser_timezone

      String.starts_with?(browser_timezone, "America/") ->
        case browser_timezone do
          "America/New_York" <> _ -> "America/New_York"
          "America/Chicago" <> _ -> "America/Chicago"
          "America/Denver" <> _ -> "America/Denver"
          "America/Phoenix" <> _ -> "America/Phoenix"
          "America/Los_Angeles" <> _ -> "America/Los_Angeles"
          "America/Anchorage" <> _ -> "America/Anchorage"
          "America/Honolulu" <> _ -> "America/Honolulu"
          "America/Puerto_Rico" <> _ -> "America/Puerto_Rico"
          _ -> @default_timezone
        end

      true ->
        @default_timezone
    end
  end
end
