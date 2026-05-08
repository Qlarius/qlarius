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

  # Qlink host: the plug exercises detection + session writes.
  test "on Qlink host: assigns in_app_browser and session for Instagram UA" do
    ua =
      "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Instagram 289.0.0.15.76"

    conn =
      :get
      |> conn("https://qlinkin.bio/")
      |> init_test_session(%{})
      |> put_req_header("user-agent", ua)
      |> fetch_session()
      |> InAppBrowserDetection.call([])

    assert %{family: :instagram, os: :ios} = conn.assigns.in_app_browser
    assert %{"family" => "instagram", "os" => "ios"} = get_session(conn, "qlarius_iab")
  end

  test "on Qlink host: assigns in_app_browser and session for Reddit UA" do
    ua =
      "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Reddit/2024.45.0"

    conn =
      :get
      |> conn("https://qlinkin.bio/")
      |> init_test_session(%{})
      |> put_req_header("user-agent", ua)
      |> fetch_session()
      |> InAppBrowserDetection.call([])

    assert %{family: :reddit, os: :ios} = conn.assigns.in_app_browser
    assert %{"family" => "reddit", "os" => "ios"} = get_session(conn, "qlarius_iab")
  end

  # Qlink host: stale IAB session data is cleared when the UA no longer matches.
  test "on Qlink host: clears assign and session for normal mobile Chrome" do
    ua =
      "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"

    conn =
      :get
      |> conn("https://qlinkin.bio/")
      |> init_test_session(%{"qlarius_iab" => %{"family" => "instagram"}})
      |> put_req_header("user-agent", ua)
      |> fetch_session()
      |> InAppBrowserDetection.call([])

    assert conn.assigns.in_app_browser == nil
    assert get_session(conn, "qlarius_iab") == nil
  end

  # Non-Qlink host: the plug MUST NOT touch the session. Previously this
  # was the root cause of intermittent auth session loss on qadabra.app —
  # every request rewrote the session cookie via delete_session, which
  # clashed with HostAwareSession's Domain=.qadabra.app attribute.
  test "on non-Qlink host (qadabra.app): assigns nil and does not touch session" do
    ua =
      "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Instagram 289.0.0.15.76"

    conn =
      :get
      |> conn("https://qadabra.app/")
      |> init_test_session(%{"user_token" => "stays-put", "qlarius_iab" => %{"family" => "instagram"}})
      |> put_req_header("user-agent", ua)
      |> fetch_session()
      |> InAppBrowserDetection.call([])

    assert conn.assigns.in_app_browser == nil
    # Auth session key untouched.
    assert get_session(conn, "user_token") == "stays-put"
    # Pre-existing IAB session key is preserved (we don't touch the
    # session on non-Qlink hosts at all). The on_mount is only used
    # by Qlink LiveViews, so stale data here is harmless.
    assert get_session(conn, "qlarius_iab") == %{"family" => "instagram"}
    # Most importantly: plug_session_info is NOT :write — the cookie
    # is not marked dirty, so Plug.Session won't emit a Set-Cookie
    # header just because this plug ran.
    refute conn.private[:plug_session_info] == :write
  end
end
