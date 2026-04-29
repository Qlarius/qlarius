defmodule Qlarius.Browsers.InAppEscapeUrls do
  @moduledoc false

  @doc """
  iOS WebView → Safari handoff for the same URL.
  """
  @spec ios_open_in_system_browser(String.t()) :: String.t()
  def ios_open_in_system_browser(url) when is_binary(url) do
    case url do
      "https://" <> rest -> "x-safari-https://" <> rest
      "http://" <> rest -> "x-safari-http://" <> rest
      _ -> url
    end
  end

  @doc """
  Android intent targeting Chrome with HTTPS fallback to the same URL.
  """
  @spec android_chrome_intent(String.t()) :: String.t() | nil
  def android_chrome_intent(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host} = uri
      when scheme in ["http", "https"] and is_binary(host) ->
        port = uri.port || URI.default_port(scheme)
        hostport = host_with_port(host, scheme, port)
        path = path_qs(uri)
        fallback = URI.encode(url, &URI.char_unreserved?/1)

        "intent://#{hostport}#{path}#Intent;scheme=#{scheme};package=com.android.chrome;S.browser_fallback_url=#{fallback};end"

      _ ->
        nil
    end
  end

  defp host_with_port(host, "http", 80), do: host
  defp host_with_port(host, "https", 443), do: host
  defp host_with_port(host, _, port) when is_integer(port), do: "#{host}:#{port}"
  defp host_with_port(host, _, _), do: host

  defp path_qs(%URI{path: path, query: q}) do
    p =
      case path do
        nil -> "/"
        "" -> "/"
        other -> other
      end

    case q do
      nil -> p
      "" -> p
      q when is_binary(q) -> p <> "?" <> q
      q -> p <> "?" <> to_string(q)
    end
  end
end
