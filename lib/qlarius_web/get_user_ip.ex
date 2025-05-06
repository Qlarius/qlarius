# Based on https://farens.me/blog/how-to-get-user-ip-addresses-in-phoenix-liveview
defmodule QlariusWeb.GetUserIP do
  def on_mount(:assign_ip, _params, _session, socket) do
    peer_data = Phoenix.LiveView.get_connect_info(socket, :peer_data)

    case peer_data do
      %{address: ip_tuple} when is_tuple(ip_tuple) ->
        IO.inspect(ip_tuple, label: ":peer_data address tuple")

      _ ->
        IO.inspect(peer_data, label: "peer_data (no address tuple)")
    end

    IO.inspect(Phoenix.LiveView.get_connect_info(socket, :x_headers), label: "x_headers")
    IO.inspect(get_ip_from_peer_data(socket), label: "ip_from_peer_data")
    ip_address = get_ip_from_headers(socket)

    socket = Phoenix.Component.assign(socket, :user_ip, ip_address)
    {:cont, socket}
  end

  defp get_ip_from_headers(socket) do
    case Phoenix.LiveView.get_connect_info(socket, :x_headers) do
      headers when is_list(headers) ->
        headers
        |> Enum.find_value(nil, fn
          {"x-real-ip", value} -> value
          {"x-forwarded-for", value} -> List.first(String.split(value, ","))
          _ -> false
        end)
        |> case do
          nil -> get_ip_from_peer_data(socket)
          ip -> String.trim(ip)
        end

      _ ->
        get_ip_from_peer_data(socket)
    end
  end

  defp get_ip_from_peer_data(socket) do
    case Phoenix.LiveView.get_connect_info(socket, :peer_data) do
      %{address: ip_tuple} when is_tuple(ip_tuple) ->
        :inet.ntoa(ip_tuple) |> to_string()

      _ ->
        "0.0.0.0"
    end
  end
end
