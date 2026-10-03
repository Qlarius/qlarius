defmodule Qlarius.AdminApi.SafeFetch do
  @moduledoc """
  Fetches a banner image from an HTTPS URL.

  The host is resolved first and refused when any address is private, loopback,
  link-local, multicast, or unspecified, including IPv4 addresses written inside
  IPv6. The connection then goes to an address that passed that check. Redirects
  are followed by hand, at most three, and each hop is checked the same way.
  The body is capped at 10 MB while it is read, and the image type is taken from
  the file's first bytes.
  """

  @max_bytes 10 * 1024 * 1024
  @max_redirects 3
  @timeout 10_000

  @types [
    {"jpeg", "image/jpeg", <<0xFF, 0xD8, 0xFF>>},
    {"png", "image/png", <<0x89, 0x50, 0x4E, 0x47>>},
    {"gif", "image/gif", <<0x47, 0x49, 0x46, 0x38>>}
  ]

  def fetch(url, opts \\ []) do
    fetch_hop(url, opts, 0)
  end

  @doc "Checks image bytes that were already read, for example from a multipart upload."
  def fetch_bytes(body) when is_binary(body) do
    if byte_size(body) > @max_bytes, do: {:error, :image_too_large}, else: type(body)
  end

  def public_address?(address), do: not blocked_address?(address)

  defp fetch_hop(_url, _opts, hops) when hops > @max_redirects, do: {:error, :image_redirect_limit}

  defp fetch_hop(url, opts, hops) do
    with {:ok, uri} <- https_uri(url),
         {:ok, ip} <- checked_address(uri.host, opts),
         {:ok, resp} <- request(uri, ip, opts) do
      cond do
        resp.status in 300..399 ->
          case location(resp, uri) do
            nil -> {:error, "Image URL redirected without a location"}
            next -> fetch_hop(next, opts, hops + 1)
          end

        resp.status != 200 ->
          {:error, "Image URL returned HTTP #{resp.status}"}

        resp.body == :too_big ->
          {:error, :image_too_large}

        true ->
          type(resp.body)
      end
    end
  end

  defp https_uri(url) when is_binary(url) do
    case URI.parse(String.trim(url)) do
      %URI{scheme: "https", host: host, path: path} = uri when is_binary(host) and host != "" ->
        {:ok, %{uri | path: path || "/"}}

      %URI{scheme: scheme} when scheme in ["http", nil] ->
        {:error, :image_not_https}

      _ ->
        {:error, :image_not_https}
    end
  end

  defp https_uri(_), do: {:error, :image_not_https}

  defp checked_address(host, opts) do
    resolver = Keyword.get(opts, :resolve, &resolve/1)

    with {:ok, addresses} <- resolver.(host) do
      cond do
        addresses == [] ->
          {:error, "Image host did not resolve"}

        Enum.any?(addresses, &blocked_address?/1) ->
          {:error, :image_host_blocked}

        true ->
          {:ok, hd(addresses)}
      end
    end
  end

  defp resolve(host) do
    case :inet.parse_address(String.to_charlist(host)) do
      {:ok, address} ->
        {:ok, [address]}

      {:error, _} ->
        charlist = String.to_charlist(host)

        with {:ok, v4} <- lookup(charlist, :inet),
             {:ok, v6} <- lookup(charlist, :inet6) do
          {:ok, v4 ++ v6}
        end
    end
  end

  defp lookup(host, family) do
    case :inet.getaddrs(host, family) do
      {:ok, addresses} -> {:ok, addresses}
      {:error, :nxdomain} -> {:ok, []}
      {:error, reason} -> {:error, "Image host did not resolve (#{reason})"}
    end
  end

  defp request(uri, ip, opts) do
    pinned = %{uri | host: ip_host(ip), authority: nil}

    result =
      Req.get(URI.to_string(pinned),
        plug: opts[:plug],
        redirect: false,
        decode_body: false,
        receive_timeout: @timeout,
        headers: [{"host", host_header(uri)}],
        connect_options: [hostname: uri.host, timeout: @timeout],
        into: &collect_body/2
      )

    case result do
      {:ok, response} -> {:ok, response}
      {:error, exception} -> {:error, "Image fetch failed: #{Exception.message(exception)}"}
    end
  end

  defp collect_body({:data, data}, {req, %Req.Response{body: body} = resp}) do
    body = if is_binary(body), do: body, else: ""
    body = body <> data

    if byte_size(body) > @max_bytes do
      {:halt, {req, %{resp | body: :too_big}}}
    else
      {:cont, {req, %{resp | body: body}}}
    end
  end

  defp ip_host({_, _, _, _} = ip), do: ip |> :inet.ntoa() |> List.to_string()

  defp ip_host(ip) do
    ip |> :inet.ntoa() |> List.to_string() |> then(&"[#{&1}]")
  end

  defp host_header(%URI{host: host, port: port}) when port in [nil, 443], do: host
  defp host_header(%URI{host: host, port: port}), do: "#{host}:#{port}"

  defp location(resp, current) do
    case Req.Response.get_header(resp, "location") do
      [value | _] -> current |> URI.merge(value) |> URI.to_string()
      _ -> nil
    end
  end

  defp type(<<"RIFF", _::binary-size(4), "WEBP", _::binary>> = body) do
    {:ok, %{body: body, ext: "webp", content_type: "image/webp"}}
  end

  defp type(body) when is_binary(body) do
    case Enum.find(@types, fn {_ext, _type, magic} -> String.starts_with?(body, magic) end) do
      {ext, content_type, _} -> {:ok, %{body: body, ext: ext, content_type: content_type}}
      nil -> {:error, :image_type_rejected}
    end
  end

  defp type(_), do: {:error, :image_type_rejected}

  defp blocked_address?({0, _, _, _}), do: true
  defp blocked_address?({10, _, _, _}), do: true
  defp blocked_address?({127, _, _, _}), do: true
  defp blocked_address?({169, 254, _, _}), do: true
  defp blocked_address?({172, b, _, _}) when b in 16..31, do: true
  defp blocked_address?({192, 168, _, _}), do: true
  defp blocked_address?({100, b, _, _}) when b in 64..127, do: true
  defp blocked_address?({a, _, _, _}) when a >= 224, do: true

  defp blocked_address?({0, 0, 0, 0, 0, 0, 0, 0}), do: true
  defp blocked_address?({0, 0, 0, 0, 0, 0, 0, 1}), do: true
  defp blocked_address?({a, _, _, _, _, _, _, _}) when a in 0xFC00..0xFDFF, do: true
  defp blocked_address?({a, _, _, _, _, _, _, _}) when a in 0xFE80..0xFEBF, do: true
  defp blocked_address?({a, _, _, _, _, _, _, _}) when a >= 0xFF00, do: true
  defp blocked_address?({0, 0, 0, 0, 0, 65_535, a, b}), do: blocked_address?(mapped_v4(a, b))
  defp blocked_address?(_), do: false

  defp mapped_v4(a, b), do: {div(a, 256), rem(a, 256), div(b, 256), rem(b, 256)}
end
