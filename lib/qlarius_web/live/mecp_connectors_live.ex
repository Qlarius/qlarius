defmodule QlariusWeb.MeCPConnectorsLive do
  @moduledoc """
  Bookmarks to `/me_file/connectors` now open the Settings YouData panel.
  """

  use QlariusWeb, :live_view

  on_mount {QlariusWeb.DetectMobile, :detect_mobile}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, push_navigate(socket, to: ~p"/settings?#{[setting: "ai_connectors"]}")}
  end

  @impl true
  def render(assigns) do
    ~H""
  end
end
