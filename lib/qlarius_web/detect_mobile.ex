defmodule QlariusWeb.DetectMobile do
  @moduledoc """
  Server-side mobile device detection from user agent.
  Prevents layout shift by detecting mobile before first render.
  """

  import Phoenix.Component, only: [assign: 3]

  def on_mount(:detect_mobile, _params, session, socket) do
    is_mobile =
      case Map.get(session, "is_mobile") do
        nil ->
          # Fallback: detect from user agent — only available on the
          # root LV. Nested/child LVs (e.g. ArcadeLive rendered
          # inline from QlinkPage.Show) can't call
          # `get_connect_info/2`; they inherit mobile context from
          # the parent's layout and don't need to detect it again,
          # so default to false.
          if root_live_view?(socket) do
            case Phoenix.LiveView.get_connect_info(socket, :user_agent) do
              nil -> false
              user_agent -> mobile?(user_agent)
            end
          else
            false
          end

        val ->
          val
      end

    {:cont, assign(socket, :is_mobile, is_mobile)}
  end

  # `socket.parent_pid` is nil only for the root LiveView in a page;
  # every `live_render/3`'d child has the parent's pid here. This is
  # the same discriminator Phoenix itself uses in
  # `Phoenix.LiveView.raise_root_and_mount_only!/2`.
  defp root_live_view?(%{parent_pid: nil}), do: true
  defp root_live_view?(_), do: false

  defp mobile?(user_agent) do
    String.match?(user_agent, ~r/Mobile|Android|iPhone|iPad|iPod/i)
  end
end
