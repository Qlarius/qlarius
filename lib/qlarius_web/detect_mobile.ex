defmodule QlariusWeb.DetectMobile do
  @moduledoc """
  Server-side mobile device detection from user agent.
  Prevents layout shift by detecting mobile before first render.
  """

  import Phoenix.Component, only: [assign: 3]

  def on_mount(:detect_mobile, _params, _session, socket) do
    is_mobile =
      case Phoenix.LiveView.get_connect_info(socket, :user_agent) do
        nil -> false
        user_agent -> mobile?(user_agent)
      end

    {:cont, assign(socket, :is_mobile, is_mobile)}
  end

  defp mobile?(user_agent) do
    String.match?(user_agent, ~r/Mobile|Android|iPhone|iPad|iPod/i)
  end
end
