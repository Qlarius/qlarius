defmodule QlariusWeb.Plugs.SessionFlagPlugsTest do
  use ExUnit.Case, async: true

  import Plug.Test
  import Plug.Conn

  alias QlariusWeb.Plugs.{MobileDetection, StorePWASession}

  @desktop_ua "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"

  describe "MobileDetection" do
    test "leaves the session untouched when is_mobile is unchanged" do
      conn =
        conn(:get, "/")
        |> put_req_header("user-agent", @desktop_ua)
        |> init_test_session(%{"is_mobile" => false})
        |> reset_session_info()
        |> MobileDetection.call([])

      refute session_written?(conn)
    end

    test "writes is_mobile when it changes" do
      conn =
        conn(:get, "/")
        |> put_req_header("user-agent", @desktop_ua)
        |> init_test_session(%{})
        |> reset_session_info()
        |> MobileDetection.call([])

      assert session_written?(conn)
      assert get_session(conn, :is_mobile) == false
    end
  end

  describe "StorePWASession" do
    test "leaves the session untouched when the PWA flags are unchanged" do
      conn =
        conn(:get, "/")
        |> put_req_header("cookie", "is_pwa=false; mobile_browser_ok=true")
        |> init_test_session(%{"is_pwa" => false, "mobile_browser_ok" => true})
        |> reset_session_info()
        |> StorePWASession.call([])

      refute session_written?(conn)
    end

    test "writes the PWA flags when they change" do
      conn =
        conn(:get, "/")
        |> put_req_header("cookie", "is_pwa=true")
        |> init_test_session(%{"is_pwa" => false})
        |> reset_session_info()
        |> StorePWASession.call([])

      assert session_written?(conn)
      assert get_session(conn, :is_pwa) == true
      assert get_session(conn, :mobile_browser_ok) == false
    end
  end

  defp reset_session_info(conn),
    do: %{conn | private: Map.delete(conn.private, :plug_session_info)}

  defp session_written?(conn), do: conn.private[:plug_session_info] == :write
end
