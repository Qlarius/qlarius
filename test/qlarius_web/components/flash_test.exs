defmodule QlariusWeb.FlashTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias QlariusWeb.CoreComponents
  alias QlariusWeb.Layouts

  test "an info flash is an auto-hiding pill with a check" do
    html =
      render_component(&CoreComponents.flash/1, kind: :info, flash: %{"info" => "Copied"})

    assert html =~ ~s(class="flash-pill flash-pill--info")
    assert html =~ ~s(phx-hook="FlashAutoHide")
    assert html =~ ~s(data-auto-hide="true")
    assert html =~ ~s(role="status")
    assert html =~ "hero-check"
    assert html =~ "Copied"
    # Tapping is handled by the hook (rise out, then clear), not phx-click
    refute html =~ "phx-click"
  end

  test "an error flash is an alert with a warning icon" do
    html =
      render_component(&CoreComponents.flash/1, kind: :error, flash: %{"error" => "Nope"})

    assert html =~ "flash-pill--error"
    assert html =~ ~s(role="alert")
    assert html =~ "hero-exclamation-triangle"
  end

  test "the connection notices say they're reconnecting and only show for their own error" do
    html = render_component(&Layouts.flash_group/1, flash: %{})

    assert html =~ ~s(class="flash-stack")
    assert html =~ "Connection lost"
    assert html =~ "Something went wrong"
    assert html =~ "Trying to reconnect now…"
    assert html =~ ~s(data-auto-hide="false")
    assert html =~ "hero-arrow-path"

    # Each unhides only when its selector matches, and as flex
    assert html =~ ~s(.phx-client-error #client-error)
    assert html =~ ~s(.phx-server-error #server-error)
    refute html =~ "Hang in there"
    refute html =~ "find the internet"
  end
end
