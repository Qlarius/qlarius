defmodule QlariusWeb.WidgetSocketTest do
  use ExUnit.Case, async: true

  import Phoenix.ChannelTest
  import Phoenix.ConnTest, only: [build_conn: 0, get: 2, html_response: 2]

  alias QlariusWeb.Auth.WidgetToken
  alias QlariusWeb.WidgetSocket

  @endpoint QlariusWeb.Endpoint
  @sync_id "9d1c4b7a-2e3f-4a5b-8c6d-0e1f2a3b4c5d"

  describe "session_from/2" do
    test "cookie session wins when present" do
      cookie = %{"user_token" => "from-cookie", "session_sync_id" => "cookie-sync"}
      token = WidgetToken.sign_authed("from-token", @sync_id)

      assert WidgetSocket.session_from(%{"widget_token" => token}, %{session: cookie}) == cookie
    end

    test "missing cookie and valid anon token gives an anonymous session" do
      token = WidgetToken.sign_anon(@sync_id)

      assert WidgetSocket.session_from(%{"widget_token" => token}, %{session: nil}) == %{
               "session_sync_id" => @sync_id,
               "widget_token_session" => true,
               "widget_token_kind" => "anon"
             }
    end

    test "missing cookie and valid authed token gives a user session" do
      token = WidgetToken.sign_authed("user-token", @sync_id)

      assert %{"user_token" => "user-token", "session_sync_id" => @sync_id} =
               WidgetSocket.session_from(%{"widget_token" => token}, %{session: nil})
    end

    test "missing cookie and no token is an empty map, never nil" do
      assert WidgetSocket.session_from(%{}, %{session: nil}) == %{}
      assert WidgetSocket.session_from(%{}, %{}) == %{}
    end

    test "missing cookie and garbage token is an anonymous session flagged as refused" do
      assert WidgetSocket.session_from(%{"widget_token" => "junk"}, %{session: nil}) == %{
               "widget_token_refused" => true
             }
    end

    test "a reused authed token falls back to anonymous instead of failing" do
      token = WidgetToken.sign_authed("user-token", @sync_id)
      assert %{"user_token" => _} = WidgetSocket.session_from(%{"widget_token" => token}, %{})

      assert WidgetSocket.session_from(%{"widget_token" => token}, %{}) == %{
               "widget_token_refused" => true
             }
    end

    test "an anonymous cookie does not shadow a user-bearing token" do
      cookie = %{"session_sync_id" => "cookie-sync", "_csrf_token" => "x"}
      token = WidgetToken.sign_session("user-token", @sync_id)

      assert %{"user_token" => "user-token", "widget_token_session" => true} =
               WidgetSocket.session_from(%{"widget_token" => token}, %{session: cookie})
    end

    test "an anonymous cookie with an anon token keeps the cookie session" do
      cookie = %{"session_sync_id" => "cookie-sync"}
      token = WidgetToken.sign_anon(@sync_id)

      assert WidgetSocket.session_from(%{"widget_token" => token}, %{session: cookie}) == cookie
    end

    test "an anonymous cookie with a refused token is flagged" do
      cookie = %{"session_sync_id" => "cookie-sync"}

      assert WidgetSocket.session_from(%{"widget_token" => "junk"}, %{session: cookie}) ==
               Map.put(cookie, "widget_token_refused", true)
    end

    test "a sync_id param replaces the stored token's page id" do
      token = WidgetToken.sign_session("user-token", @sync_id)
      new_id = "1F2E3D4C-5B6A-4798-8899-AABBCCDDEEFF"

      assert %{"session_sync_id" => "1f2e3d4c-5b6a-4798-8899-aabbccddeeff"} =
               WidgetSocket.session_from(
                 %{"widget_token" => token, "sync_id" => new_id},
                 %{session: nil}
               )

      assert %{"session_sync_id" => @sync_id} =
               WidgetSocket.session_from(
                 %{"widget_token" => token, "sync_id" => "not-a-uuid"},
                 %{session: nil}
               )
    end
  end

  describe "LiveView join without a cookie (the former reload loop)" do
    # Plain `Phoenix.LiveView.Socket` leaves `connect_info.session` nil when
    # the cookie is missing and `Phoenix.LiveView.Channel` answers `stale`,
    # which the JS client turns into an immediate page reload. Drive the real
    # channel join with the tokens from a rendered widget page.
    setup do
      Qlarius.DataCase.setup_sandbox(async: true)
      :ok
    end

    defp rendered_widget(path) do
      html = build_conn() |> get(path) |> html_response(200)

      [main] = Regex.run(~r/<div[^>]*data-phx-main[^>]*>/, html)
      [_, id] = Regex.run(~r/\sid="([^"]+)"/, main)
      [_, session] = Regex.run(~r/data-phx-session="([^"]+)"/, main)
      [_, static] = Regex.run(~r/data-phx-static="([^"]+)"/, main)
      [_, widget_token] = Regex.run(~r/name="widget-token"\s+content="([^"]+)"/, html)

      %{
        topic: "lv:" <> id,
        join: %{
          "session" => session,
          "static" => static,
          "url" => "https://localhost:4001" <> path,
          "params" => %{"_mounts" => 0}
        },
        widget_token: widget_token
      }
    end

    # `Phoenix.ChannelTest.join/4` asks the channel process for its socket
    # afterwards, which `Phoenix.LiveView.Channel` does not answer; the
    # underlying server join is enough to observe the reply.
    defp join_live_view(socket, topic, payload) do
      message = %Phoenix.Socket.Message{
        event: "phx_join",
        topic: topic,
        payload: payload,
        ref: System.unique_integer([:positive])
      }

      starter = fn _socket, _from, spec ->
        DynamicSupervisor.start_child(Qlarius.WidgetSocketTestSupervisor, spec)
      end

      Phoenix.Channel.Server.join(socket, Phoenix.LiveView.Channel, message, starter: starter)
    end

    setup do
      start_supervised!({DynamicSupervisor, name: Qlarius.WidgetSocketTestSupervisor})
      :ok
    end

    test "joins anonymously with no cookie and no token" do
      %{topic: topic, join: join} = rendered_widget("/widgets/ads_ext/")

      {:ok, socket} = connect(WidgetSocket, %{}, connect_info: %{session: nil})
      assert {:ok, %{rendered: _}, pid} = join_live_view(socket, topic, join)
      assert Process.alive?(pid)
    end

    test "joins anonymously with no cookie and the page's anon token" do
      %{topic: topic, join: join, widget_token: token} = rendered_widget("/widgets/ads_ext/")

      {:ok, socket} =
        connect(WidgetSocket, %{"widget_token" => token}, connect_info: %{session: nil})

      assert {:ok, %{rendered: _}, pid} = join_live_view(socket, topic, join)
      assert Process.alive?(pid)
    end

    test "the stock LiveView socket still replies stale for the same join" do
      %{topic: topic, join: join} = rendered_widget("/widgets/ads_ext/")

      {:ok, socket} = connect(Phoenix.LiveView.Socket, %{}, connect_info: %{session: nil})

      assert {:error, %{reason: "stale"}} = join_live_view(socket, topic, join)
    end
  end

  describe "connect/3" do
    test "connects with no cookie session and no token" do
      assert {:ok, socket} = connect(WidgetSocket, %{}, connect_info: %{session: nil})
      assert socket.private.connect_info.session == %{}
    end

    test "connects with no cookie session and a widget token" do
      token = WidgetToken.sign_authed("user-token", @sync_id)

      assert {:ok, socket} =
               connect(WidgetSocket, %{"widget_token" => token}, connect_info: %{session: nil})

      assert %{"user_token" => "user-token", "live_socket_id" => "users_sessions:" <> _} =
               socket.private.connect_info.session

      assert WidgetSocket.id(socket) == "users_sessions:" <> Base.url_encode64("user-token")
    end

    test "connects with a cookie session and ignores the token" do
      cookie = %{"user_token" => "cookie-user", "live_socket_id" => "users_sessions:abc"}
      token = WidgetToken.sign_authed("token-user", @sync_id)

      assert {:ok, socket} =
               connect(WidgetSocket, %{"widget_token" => token}, connect_info: %{session: cookie})

      assert socket.private.connect_info.session == cookie
      assert WidgetSocket.id(socket) == "users_sessions:abc"
    end
  end
end
