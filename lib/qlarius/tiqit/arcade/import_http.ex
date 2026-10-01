defmodule Qlarius.Tiqit.Arcade.ImportHttp do
  @moduledoc """
  Bounded HTTP GET for content imports (RSS feeds and artwork).

  Only public http(s) URLs are fetched, redirects are capped, and bodies
  larger than `:max_bytes` are refused so a bad URL cannot stall or bloat
  an import.
  """

  @default_timeout 10_000
  @default_max_bytes 5 * 1024 * 1024

  @doc """
  Options: `:max_bytes`, `:timeout`, `:schemes` (default `["http", "https"]`).

  Returns `{:ok, %{body: binary, content_type: string | nil}}` or
  `{:error, message}`.
  """
  def get(url, opts \\ []) do
    max_bytes = Keyword.get(opts, :max_bytes, @default_max_bytes)
    schemes = Keyword.get(opts, :schemes, ["http", "https"])

    with :ok <- check_url(url, schemes),
         {:ok, response} <- request(url, Keyword.get(opts, :timeout, @default_timeout)),
         :ok <- check_status(response),
         {:ok, body} <- check_size(response.body, max_bytes) do
      {:ok, %{body: body, content_type: content_type(response)}}
    end
  end

  def public_url?(url, schemes \\ ["http", "https"]), do: check_url(url, schemes) == :ok

  defp request(url, timeout) do
    [
      url: url,
      receive_timeout: timeout,
      connect_options: [timeout: timeout],
      max_redirects: 5,
      decode_body: false,
      headers: [{"user-agent", "Qadabra content import"}]
    ]
    |> Keyword.merge(Keyword.get(config(), :req_options, []))
    |> Req.get()
    |> case do
      {:ok, response} -> {:ok, response}
      {:error, exception} -> {:error, "Request failed: #{Exception.message(exception)}"}
    end
  end

  defp check_url(url, schemes) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host} when is_binary(host) and host != "" ->
        cond do
          scheme not in schemes -> {:error, "URL must use #{Enum.join(schemes, " or ")}"}
          private_host?(host) -> {:error, "URL host is not public"}
          true -> :ok
        end

      _ ->
        {:error, "URL is not valid"}
    end
  end

  defp check_url(_, _), do: {:error, "URL is not valid"}

  defp private_host?(host) do
    host = String.downcase(host)

    host in ["localhost", "0.0.0.0"] or String.ends_with?(host, ".local") or
      case :inet.parse_address(String.to_charlist(host)) do
        {:ok, {127, _, _, _}} -> true
        {:ok, {10, _, _, _}} -> true
        {:ok, {192, 168, _, _}} -> true
        {:ok, {172, b, _, _}} when b in 16..31 -> true
        {:ok, {169, 254, _, _}} -> true
        {:ok, {0, 0, 0, 0, 0, 0, 0, 1}} -> true
        _ -> false
      end
  end

  defp check_status(%Req.Response{status: status}) when status in 200..299, do: :ok
  defp check_status(%Req.Response{status: status}), do: {:error, "HTTP #{status}"}

  defp check_size(body, max_bytes) when is_binary(body) do
    if byte_size(body) > max_bytes,
      do: {:error, "Response is larger than #{div(max_bytes, 1024 * 1024)} MB"},
      else: {:ok, body}
  end

  defp check_size(_body, _max_bytes), do: {:error, "Response body is empty"}

  defp content_type(response) do
    case Req.Response.get_header(response, "content-type") do
      [value | _] -> value |> String.split(";") |> hd() |> String.trim() |> String.downcase()
      _ -> nil
    end
  end

  defp config, do: Application.get_env(:qlarius, :content_import, [])
end
