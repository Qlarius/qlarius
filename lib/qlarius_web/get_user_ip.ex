# Based on https://farens.me/blog/how-to-get-user-ip-addresses-in-phoenix-liveview
defmodule QlariusWeb.GetUserIP do
  def on_mount(:assign_ip, _params, _session, socket) do
    ip_address = get_ip_from_headers(socket)

    socket = Phoenix.Component.assign(socket, :user_ip, ip_address)
    {:cont, socket}
  end

  defp get_ip_from_headers(socket) do
    case Phoenix.LiveView.get_connect_info(socket, :x_headers) do
      headers when is_list(headers) ->
        headers
        |> Enum.find_value("0.0.0.0", fn
          {"x-real-ip", value} -> value
          {"x-forwarded-for", value} -> List.first(String.split(value, ","))
          _ -> false
        end)
        |> String.trim()

      _ ->
        "0.0.0.0"
    end
  end
end
