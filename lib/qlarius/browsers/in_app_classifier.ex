defmodule Qlarius.Browsers.InAppClassifier do
  @moduledoc false

  @type family ::
          :instagram
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

  @type result :: %{
          family: family(),
          confidence: :high | :medium,
          os: os()
        }

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

  defp match_family(ua) do
    cond do
      reddit_in_app?(ua) -> {:reddit, :high}
      String.contains?(ua, "instagram") -> {:instagram, :high}
      String.contains?(ua, "tiktok") or String.contains?(ua, "musical.ly") -> {:tiktok, :high}
      String.contains?(ua, "snapchat") -> {:snapchat, :high}
      String.contains?(ua, "linkedinapp") -> {:linkedin, :high}
      String.contains?(ua, "pinterest") -> {:pinterest, :high}
      String.contains?(ua, " line/") or String.starts_with?(ua, "line/") -> {:line, :high}
      String.contains?(ua, "kakaotalk") -> {:kakao, :high}
      String.contains?(ua, "fban") or String.contains?(ua, "fbav") -> {:facebook, :high}
      String.contains?(ua, "messenger") and String.contains?(ua, "fb") -> {:messenger, :medium}
      twitter_in_app?(ua) -> {:twitter, :high}
      generic_android_webview?(ua) -> {:in_app_webview, :medium}
      true -> nil
    end
  end

  # Official Reddit apps append `Reddit/<version>`; Android builds may
  # also mention the front-end package in the WebView UA.
  defp reddit_in_app?(ua) do
    String.contains?(ua, "reddit/") or String.contains?(ua, "com.reddit.frontpage")
  end

  defp twitter_in_app?(ua) do
    String.contains?(ua, "twitter for iphone") or String.contains?(ua, "twitter for android")
  end

  defp generic_android_webview?(ua) do
    String.contains?(ua, "android") and String.contains?(ua, "; wv)")
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
