defmodule QlariusWeb.InAppBrowserMount do
  @moduledoc false

  import Phoenix.Component, only: [assign: 3]

  def on_mount(:assign_in_app_browser, _params, session, socket) do
    iab = parse_iab_session(Map.get(session, "qlarius_iab"))

    {:cont,
     socket
     |> assign(:in_app_browser, iab)
     |> assign(:in_app_escape_dismissed, false)}
  end

  defp parse_iab_session(nil), do: nil

  defp parse_iab_session(%{"family" => f, "confidence" => c, "os" => o}) do
    with {:ok, family} <- to_family(f),
         {:ok, confidence} <- to_confidence(c),
         {:ok, os} <- to_os(o) do
      %{family: family, confidence: confidence, os: os}
    else
      _ -> nil
    end
  end

  defp parse_iab_session(_), do: nil

  defp to_family(s) do
    case s do
      "instagram" -> {:ok, :instagram}
      "threads" -> {:ok, :threads}
      "facebook" -> {:ok, :facebook}
      "tiktok" -> {:ok, :tiktok}
      "snapchat" -> {:ok, :snapchat}
      "linkedin" -> {:ok, :linkedin}
      "twitter" -> {:ok, :twitter}
      "line" -> {:ok, :line}
      "pinterest" -> {:ok, :pinterest}
      "messenger" -> {:ok, :messenger}
      "kakao" -> {:ok, :kakao}
      "reddit" -> {:ok, :reddit}
      "in_app_webview" -> {:ok, :in_app_webview}
      _ -> :error
    end
  end

  defp to_confidence(s) do
    case s do
      "high" -> {:ok, :high}
      "medium" -> {:ok, :medium}
      _ -> :error
    end
  end

  defp to_os(s) do
    case s do
      "ios" -> {:ok, :ios}
      "android" -> {:ok, :android}
      "other" -> {:ok, :other}
      _ -> :error
    end
  end
end
