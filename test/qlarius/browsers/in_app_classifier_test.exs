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
  end

  test "facebook in-app markers" do
    ua =
      "Mozilla/5.0 (Linux; Android 13; SM-S901B Build/TP1A.220624.014; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/112.0.5615.136 Mobile Safari/537.36 [FBAN/EMA;FBLC/en_US;FBAV/442.0.0.30.110;]"

    assert %{family: :facebook, os: :android, confidence: :high} = InAppClassifier.classify(ua)
  end

  test "tiktok" do
    ua =
      "Mozilla/5.0 (Linux; Android 12; Pixel 6) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/91.0.4472.114 Mobile Safari/537.36 musical_ly"

    assert %{family: :tiktok, os: :android} = InAppClassifier.classify(ua)
  end

  test "twitter for iphone" do
    ua =
      "Mozilla/5.0 (iPhone; CPU iPhone OS 15_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Twitter for iPhone/9.26"

    assert %{family: :twitter, os: :ios} = InAppClassifier.classify(ua)
  end
end
