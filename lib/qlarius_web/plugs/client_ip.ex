defmodule QlariusWeb.Plugs.ClientIp do
  @moduledoc """
  Replaces `conn.remote_ip` with the originating client address when the
  app runs behind a trusted proxy (Cloudflare in front of Gigalixir).

  Without this every request arrives from the proxy's address, so the
  per-IP auth rate limits (`Qlarius.Auth.RateLimit`) become one shared
  bucket for all visitors: forty widget exchanges across the whole user
  base exhaust `/auth/extension_exchange` for an hour.

  Enabled by `config :qlarius, :trust_proxy_ip_headers, true` (prod only).
  `cf-connecting-ip` wins; the first `x-forwarded-for` entry is the
  fallback. Unparseable values leave `remote_ip` untouched.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if Application.get_env(:qlarius, :trust_proxy_ip_headers, false) do
      case client_ip(conn) do
        nil -> conn
        ip -> %{conn | remote_ip: ip}
      end
    else
      conn
    end
  end

  defp client_ip(conn) do
    header_ip(conn, "cf-connecting-ip") || header_ip(conn, "x-forwarded-for")
  end

  defp header_ip(conn, name) do
    conn
    |> get_req_header(name)
    |> List.first()
    |> case do
      nil -> nil
      value -> value |> String.split(",") |> List.first() |> String.trim() |> parse()
    end
  end

  defp parse(""), do: nil

  defp parse(value) do
    case :inet.parse_strict_address(String.to_charlist(value)) do
      {:ok, ip} -> ip
      {:error, _} -> nil
    end
  end
end
