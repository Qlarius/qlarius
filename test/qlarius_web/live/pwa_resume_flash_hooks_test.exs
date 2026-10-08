defmodule QlariusWeb.PWAResumeFlashHooksTest do
  use QlariusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defmodule Host do
    use Phoenix.LiveView

    on_mount QlariusWeb.PWAResumeFlashHooks

    @impl true
    def mount(_params, _session, socket) do
      {:ok, socket}
    end

    @impl true
    def render(assigns) do
      ~H"""
      <QlariusWeb.Layouts.flash_group flash={@flash} />
      <div id="content">ok</div>
      """
    end
  end

  test "shows a friendly flash when the client indicates a background return", %{conn: conn} do
    {:ok, view, _html} =
      live_isolated(conn, Host, connect_params: %{"pwa_bg_pending" => "1", "pwa_bg_at" => 1})

    html = render(view)
    assert html =~ "The app refreshed while you were away."
    assert html =~ ~s(id="pwa-lifecycle-hook")
  end

  test "does not show the background-return flash on normal mount", %{conn: conn} do
    {:ok, view, _html} = live_isolated(conn, Host)

    html = render(view)
    refute html =~ "The app refreshed while you were away."
  end
end

