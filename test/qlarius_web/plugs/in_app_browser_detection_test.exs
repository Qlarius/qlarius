defmodule QlariusWeb.Plugs.InAppBrowserDetectionTest do
  use ExUnit.Case, async: false

  import Plug.Test
  import Plug.Conn

  alias QlariusWeb.Plugs.InAppBrowserDetection

  setup do
    prev = Application.get_env(:qlarius, :in_app_browser_escape)
    Application.put_env(:qlarius, :in_app_browser_escape, enabled: true, auto_attempt: false)

    on_exit(fn ->
      Application.put_env(:qlarius, :in_app_browser_escape, prev)
    end)

    :ok
  end

  test "assigns in_app_browser and session for Instagram UA" do
    ua =
      "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Instagram 289.0.0.15.76"

    conn =
      :get
      |> conn("/")
      |> init_test_session(%{})
      |> put_req_header("user-agent", ua)
      |> fetch_session()
      |> InAppBrowserDetection.call([])

    assert %{family: :instagram, os: :ios} = conn.assigns.in_app_browser
    assert %{"family" => "instagram", "os" => "ios"} = get_session(conn, "qlarius_iab")
  end

  test "clears assign and session for normal mobile Chrome" do
    ua =
      "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"

    conn =
      :get
      |> conn("/")
      |> init_test_session(%{"qlarius_iab" => %{"family" => "instagram"}})
      |> put_req_header("user-agent", ua)
      |> fetch_session()
      |> InAppBrowserDetection.call([])

    assert conn.assigns.in_app_browser == nil
    assert get_session(conn, "qlarius_iab") == nil
  end
end
