defmodule QlariusWeb.LiveViewDebugHooks do
  @moduledoc false

  import Phoenix.LiveView

  alias QlariusWeb.LiveViewDebug

  def on_mount(:default, _params, _session, socket) do
    socket =
      if LiveViewDebug.enabled?() do
        socket =
          attach_hook(socket, :lv_debug_handle_info, :handle_info, fn msg, socket ->
            unless LiveViewDebug.wallet_sync_message?(msg) or internal_msg?(msg) do
              LiveViewDebug.log_handle_info(socket, msg)
            end

            {:cont, socket}
          end)

        LiveViewDebug.log_mount(socket)
      else
        socket
      end

    {:cont, socket}
  end

  defp internal_msg?(:wallet_balance_sync_subscribe), do: true
  defp internal_msg?(_), do: false
end
