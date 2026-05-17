defmodule Qlarius.Browsers.InAppClassifier do
  @moduledoc """
  Classifies mobile in-app webview user agents (Instagram, Threads, X, etc.)
  and provides human-readable platform labels for the Qlink escape popover.
  """

  @type family ::
          :instagram
          | :threads
          | :facebook
          | :tiktok
          | :snapchat
          | :linkedin
          | :twitter
          | :line
          | :pinterest
          | :messenger
          | :kakao
          | :reddit
          | :in_app_webview

  @type os :: :ios | :android | :other

  @type confidence :: :high | :medium

  @type result :: %{
          family: family(),
          confidence: confidence(),
          os: os()
        }

  @display_names %{
    instagram: "Instagram",
    threads: "Threads",
    facebook: "Facebook",
    messenger: "Messenger",
    tiktok: "TikTok",
    snapchat: "Snapchat",
    linkedin: "LinkedIn",
    twitter: "X",
    line: "LINE",
    pinterest: "Pinterest",
    kakao: "KakaoTalk",
    reddit: "Reddit"
  }

  @doc """
  Returns a user-facing platform name for the popover copy, or `nil` when the
  family is unknown or too generic to name (e.g. `:in_app_webview`).
  """
  @spec display_name(family()) :: String.t() | nil
  def display_name(family) when is_atom(family), do: Map.get(@display_names, family)

  @spec classify(String.t()) :: result() | nil
  def classify(user_agent) when is_binary(user_agent) do
    ua = String.downcase(user_agent)

    case match_family(ua) do
      {family, confidence} ->
        %{family: family, confidence: confidence, os: infer_os(ua)}

      nil ->
        nil
    end
  end

  def classify(_), do: nil

  # Order matters: more specific markers before broader ones (e.g. Threads
  # "Barcelona" before Instagram; TikTok Bytedance before generic Android WV).
  defp match_family(ua) do
    cond do
      reddit_in_app?(ua) -> {:reddit, :high}
      threads_in_app?(ua) -> {:threads, :high}
      String.contains?(ua, "instagram") -> {:instagram, :high}
      tiktok_in_app?(ua) -> {:tiktok, :high}
      snapchat_in_app?(ua) -> {:snapchat, :high}
      linkedin_in_app?(ua) -> {:linkedin, :high}
      String.contains?(ua, "pinterest") -> {:pinterest, :high}
      line_in_app?(ua) -> {:line, :high}
      String.contains?(ua, "kakaotalk") -> {:kakao, :high}
      messenger_in_app?(ua) -> {:messenger, :medium}
      facebook_in_app?(ua) -> {:facebook, :high}
      twitter_in_app?(ua) -> {:twitter, :high}
      generic_android_webview?(ua) -> {:in_app_webview, :medium}
      true -> nil
    end
  end

  defp reddit_in_app?(ua) do
    String.contains?(ua, "reddit/") or String.contains?(ua, "com.reddit.frontpage")
  end

  # Meta Threads (codename Barcelona); IABMV = in-app browser marker on iOS.
  defp threads_in_app?(ua) do
    String.contains?(ua, "barcelona") or
      String.contains?(ua, "threads/") or
      (String.contains?(ua, "threads") and String.contains?(ua, "iabmv/"))
  end

  defp tiktok_in_app?(ua) do
    String.contains?(ua, "tiktok") or
      String.contains?(ua, "musical_ly") or
      String.contains?(ua, "musical.ly") or
      String.contains?(ua, "bytedancewebview") or
      String.contains?(ua, "trill/") or
      String.contains?(ua, "trill_") or
      String.contains?(ua, "aweme")
  end

  defp snapchat_in_app?(ua) do
    String.contains?(ua, "snapchat") or
      (String.contains?(ua, "snap/") and mobile_ua?(ua))
  end

  defp linkedin_in_app?(ua) do
    String.contains?(ua, "linkedinapp") or
      (String.contains?(ua, "linkedin") and mobile_ua?(ua))
  end

  defp line_in_app?(ua) do
    String.contains?(ua, " line/") or String.starts_with?(ua, "line/")
  end

  defp messenger_in_app?(ua) do
    String.contains?(ua, "messenger") and
      (String.contains?(ua, "fb") or String.contains?(ua, "fban") or String.contains?(ua, "fbav"))
  end

  defp facebook_in_app?(ua) do
    String.contains?(ua, "fban") or String.contains?(ua, "fbav") or
      String.contains?(ua, "fb_iab") or String.contains?(ua, "fbios")
  end

  defp twitter_in_app?(ua) do
    String.contains?(ua, "twitter for iphone") or
      String.contains?(ua, "twitter for android") or
      String.contains?(ua, "twitterandroid") or
      String.contains?(ua, "com.twitter.android") or
      String.contains?(ua, "twitter/") or
      (String.contains?(ua, "twitter") and mobile_ua?(ua))
  end

  defp generic_android_webview?(ua) do
    String.contains?(ua, "android") and String.contains?(ua, "; wv)")
  end

  defp mobile_ua?(ua) do
    String.contains?(ua, "mobile") or String.contains?(ua, "iphone") or
      String.contains?(ua, "ipad") or String.contains?(ua, "android")
  end

  defp infer_os(ua) do
    cond do
      String.contains?(ua, "iphone") or String.contains?(ua, "ipad") or
          String.contains?(ua, "ipod") ->
        :ios

      String.contains?(ua, "android") ->
        :android

      true ->
        :other
    end
  end
end
