defmodule Qlarius.Sponster.WidgetServeLogs.UserAgent do
  @moduledoc """
  Coarse user-agent classification for widget serve reports. Good enough to
  group loads and spot automation; not a full parser.
  """

  # Plain alternation so the same source works as a Postgres `~*` pattern.
  @bot_source "bot|crawl|spider|slurp|headless|curl|wget|python-requests|python-urllib|httpclient|okhttp|go-http-client|axios|node-fetch|puppeteer|playwright|selenium|phantom|lighthouse|scrapy"
  @bot Regex.compile!(@bot_source, "i")

  def bot_pattern_sql, do: @bot_source

  def bot?(nil), do: true

  def bot?(ua) when is_binary(ua) do
    String.trim(ua) == "" or Regex.match?(@bot, ua)
  end

  def classify(ua) do
    %{browser: browser(ua), device: device(ua), platform: platform(ua)}
  end

  def browser(nil), do: nil

  def browser(ua) do
    cond do
      bot?(ua) -> "Bot"
      ua =~ ~r/Edg\//i -> "Edge"
      ua =~ ~r/OPR\/|Opera/i -> "Opera"
      ua =~ ~r/SamsungBrowser/i -> "Samsung Internet"
      ua =~ ~r/Firefox|FxiOS/i -> "Firefox"
      ua =~ ~r/Chrome|CriOS/i -> "Chrome"
      ua =~ ~r/Safari/i -> "Safari"
      true -> "Other"
    end
  end

  def device(nil), do: nil

  def device(ua) do
    cond do
      bot?(ua) -> "Bot"
      ua =~ ~r/iPad|Tablet/i -> "Tablet"
      ua =~ ~r/Android/i and not (ua =~ ~r/Mobile/i) -> "Tablet"
      ua =~ ~r/Mobi|iPhone|Android/i -> "Mobile"
      true -> "Desktop"
    end
  end

  def platform(nil), do: nil

  def platform(ua) do
    cond do
      ua =~ ~r/iPhone|iPad|iPod/i -> "iOS"
      ua =~ ~r/Android/i -> "Android"
      ua =~ ~r/Windows/i -> "Windows"
      ua =~ ~r/Mac OS X|Macintosh/i -> "macOS"
      ua =~ ~r/CrOS/i -> "ChromeOS"
      ua =~ ~r/Linux/i -> "Linux"
      true -> "Other"
    end
  end
end
