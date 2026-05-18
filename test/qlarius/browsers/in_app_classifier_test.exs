defmodule Qlarius.Browsers.InAppClassifierTest do
  use ExUnit.Case, async: true

  alias Qlarius.Browsers.InAppClassifier

  test "nil for desktop Safari" do
    ua =
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    assert InAppClassifier.classify(ua) == nil
  end

  test "instagram on iOS" do
    ua =
      "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Instagram 289.0.0.15.76"

    assert %{family: :instagram, os: :ios, confidence: :high} = InAppClassifier.classify(ua)
    assert InAppClassifier.display_name(:instagram) == "Instagram"
  end

  test "threads on iOS (Barcelona codename)" do
    ua =
      "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/23E246 Barcelona 415.0.0.19.68 (iPhone16,1; iOS 26_4; en_US; en; scale=3.00; IABMV/1; 873683319)"

    assert %{family: :threads, os: :ios, confidence: :high} = InAppClassifier.classify(ua)
    assert InAppClassifier.display_name(:threads) == "Threads"
  end

  test "facebook in-app markers" do
    ua =
      "Mozilla/5.0 (Linux; Android 13; SM-S901B Build/TP1A.220624.014; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/112.0.5615.136 Mobile Safari/537.36 [FBAN/EMA;FBLC/en_US;FBAV/442.0.0.30.110;]"

    assert %{family: :facebook, os: :android, confidence: :high} = InAppClassifier.classify(ua)
  end

  test "tiktok via musical_ly" do
    ua =
      "Mozilla/5.0 (Linux; Android 12; Pixel 6) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/91.0.4472.114 Mobile Safari/537.36 musical_ly"

    assert %{family: :tiktok, os: :android} = InAppClassifier.classify(ua)
  end

  test "tiktok via BytedanceWebview on iOS" do
    ua =
      "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 trill_34.0.0 JsSdk/2.0 WKWebView/1 BytedanceWebview/d8a21c6"

    assert %{family: :tiktok, os: :ios, confidence: :high} = InAppClassifier.classify(ua)
    assert InAppClassifier.display_name(:tiktok) == "TikTok"
  end

  test "twitter for iphone" do
    ua =
      "Mozilla/5.0 (iPhone; CPU iPhone OS 15_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Twitter for iPhone/9.26"

    assert %{family: :twitter, os: :ios} = InAppClassifier.classify(ua)
    assert InAppClassifier.display_name(:twitter) == "X"
  end

  test "twitter android package marker" do
    ua =
      "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/120.0.0.0 Mobile Safari/537.36 TwitterAndroid"

    assert %{family: :twitter, os: :android, confidence: :high} = InAppClassifier.classify(ua)
  end

  test "twitter android 2025 release tag (uaparser / device-detector shape)" do
    ua =
      "Mozilla/5.0 (Linux; Android 16; Pixel 7 Build/CP1A.260305.018; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/146.0.7680.164 Mobile Safari/537.36 TwitterAndroid/11.76.0-release.0"

    assert %{family: :twitter, os: :android, confidence: :high} = InAppClassifier.classify(ua)
  end

  test "twitter ios via Twitter/ version token" do
    ua =
      "Mozilla/5.0 (iPhone; CPU iPhone OS 18_6_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/22G100 Twitter/11.37"

    assert %{family: :twitter, os: :ios, confidence: :high} = InAppClassifier.classify(ua)
  end

  test "classify_with_referer infers X from x.com referer when UA is generic mobile webkit" do
    ua =
      "Mozilla/5.0 (iPhone; CPU iPhone OS 18_6_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/22G100"

    assert %{family: :twitter, os: :ios, confidence: :medium} =
             InAppClassifier.classify_with_referer(ua, "https://x.com/some/status/123")
  end

  test "ios webkit without Safari/ is generic in_app_webview" do
    ua =
      "Mozilla/5.0 (iPhone; CPU iPhone OS 18_6_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/22G100"

    assert %{family: :in_app_webview, os: :ios, confidence: :medium} = InAppClassifier.classify(ua)
  end

  test "snapchat in-app" do
    ua =
      "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Snapchat/12.0.0"

    assert %{family: :snapchat, os: :ios, confidence: :high} = InAppClassifier.classify(ua)
    assert InAppClassifier.display_name(:snapchat) == "Snapchat"
  end

  test "linkedin in-app" do
    ua =
      "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 LinkedInApp/9.24.0"

    assert %{family: :linkedin, os: :ios, confidence: :high} = InAppClassifier.classify(ua)
    assert InAppClassifier.display_name(:linkedin) == "LinkedIn"
  end

  test "reddit ios in-app marker" do
    ua =
      "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Reddit/2024.45.0"

    assert %{family: :reddit, os: :ios, confidence: :high} = InAppClassifier.classify(ua)
  end

  test "reddit android webview package marker" do
    ua =
      "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/119.0.0.0 Mobile Safari/537.36 com.reddit.frontpage/2024.45.0"

    assert %{family: :reddit, os: :android, confidence: :high} = InAppClassifier.classify(ua)
  end

  test "generic android webview has no display name" do
    ua =
      "Mozilla/5.0 (Linux; Android 13; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/112.0.0.0 Mobile Safari/537.36"

    assert %{family: :in_app_webview, confidence: :medium} = InAppClassifier.classify(ua)
    assert InAppClassifier.display_name(:in_app_webview) == nil
  end

  test "escape_directions_style is browser_icon for X/Twitter, menu for Meta apps" do
    assert InAppClassifier.escape_directions_style(:twitter) == :browser_icon
    assert InAppClassifier.escape_directions_style(:instagram) == :menu
    assert InAppClassifier.escape_directions_style(:threads) == :menu
    assert InAppClassifier.escape_directions_style(:facebook) == :menu
    assert InAppClassifier.escape_directions_style(:tiktok) == :menu
  end
end
