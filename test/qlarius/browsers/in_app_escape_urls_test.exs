defmodule Qlarius.Browsers.InAppEscapeUrlsTest do
  use ExUnit.Case, async: true

  alias Qlarius.Browsers.InAppEscapeUrls

  test "ios_open_in_system_browser strips scheme for safari handoff" do
    assert InAppEscapeUrls.ios_open_in_system_browser("https://qlinkin.bio/@alice") ==
             "x-safari-https://qlinkin.bio/@alice"
  end

  test "android_chrome_intent includes package and fallback" do
    url = "https://qlink.qadabra.app/@bob"
    intent = InAppEscapeUrls.android_chrome_intent(url)
    assert String.starts_with?(intent, "intent://qlink.qadabra.app/@bob#Intent;")
    assert String.contains?(intent, "package=com.android.chrome")
    assert String.contains?(intent, "S.browser_fallback_url=")
  end
end
