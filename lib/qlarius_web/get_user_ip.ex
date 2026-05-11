# Based on https://farens.me/blog/how-to-get-user-ip-addresses-in-phoenix-liveview
defmodule QlariusWeb.GetUserIP do
  @moduledoc """
  `on_mount` hook that assigns `:user_ip` on the socket.

  `Phoenix.LiveView.get_connect_info/2` only works on the **root** LV —
  calling it from a nested child LV raises at runtime. When a LV that
  uses this hook mounts as a child (e.g. `ArcadeLive` nested inside
  `QlinkPage.Show`), we fall back to `"0.0.0.0"`. The downstream
  consumer (`Qlarius.Auth.RateLimit`) treats `"0.0.0.0"` as "unknown —
  skip per-IP gate", which is the right behavior for nested children
  anyway since their parent LV (which does have the real IP) is the one
  hosting the `AuthSheet`; nested children forward
  `{:open_auth_sheet, brand}` to the parent rather than opening their own sheet
  (see plan rev 8 / B5).
  """

  def on_mount(:assign_ip, _params, _session, socket) do
    ip_address =
      if root_lv?(socket) do
        get_ip_from_headers(socket)
      else
        "0.0.0.0"
      end

    socket = Phoenix.Component.assign(socket, :user_ip, ip_address)
    {:cont, socket}
  end

  defp root_lv?(socket), do: is_nil(socket.parent_pid)

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
