defmodule QlariusWeb.Widgets.CookielessMountTest do
  @moduledoc """
  Widget LiveViews must mount for a visitor with no session cookie: the
  socket turns a missing cookie into an empty or token-derived session, so
  every `/widgets/*` route has to cope with `current_scope: nil`, and a
  token-backed authed mount has to hand the client a renewable token.
  """
  use QlariusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Qlarius.WidgetAuthFixtures

  alias Qlarius.Accounts
  alias QlariusWeb.Auth.WidgetToken

  @sync_id "2c3d4e5f-6a7b-4c8d-9e0f-1a2b3c4d5e6f"

  # LiveViewTest always supplies a session; an empty one is what the
  # socket produces when there is no cookie and no token.
  defp cookieless(conn), do: init_test_session(conn, %{})

  describe "anonymous mounts" do
    for path <- ["/widgets/ads_ext/", "/widgets/arqade", "/widgets/wallet", "/widgets/insta_tip"] do
      test "#{path} mounts with no scope", %{conn: conn} do
        {:ok, _view, html} = live(cookieless(conn), unquote(path))
        assert is_binary(html)
      end
    end

    test "arqade catalog, creator, group, piece, and tiqit_pass mount with no scope", %{
      conn: conn
    } do
      catalog = Qlarius.ContentImportHelpers.podcast_catalog_fixture()
      group = Qlarius.ContentImportHelpers.content_group_fixture(catalog)

      piece =
        %Qlarius.Tiqit.Arcade.ContentPiece{content_group_id: group.id}
        |> Qlarius.Tiqit.Arcade.ContentPiece.changeset(%{
          title: "Episode 1",
          date_published: ~D[2026-01-01]
        })
        |> Qlarius.Repo.insert!()

      for path <- [
            "/widgets/arqade/catalog/#{catalog.id}",
            "/widgets/arqade/creator/#{catalog.creator_id}",
            "/widgets/arqade/group/#{group.id}",
            "/widgets/arqade/#{piece.id}",
            "/widgets/tiqit_pass/#{catalog.id}"
          ] do
        assert {:ok, _view, html} = live(cookieless(conn), path), "failed to mount #{path}"
        assert is_binary(html)
      end
    end

    test "the embed document carries the widget socket meta tags", %{conn: conn} do
      html = conn |> get("/widgets/ads_ext/?sync_id=#{@sync_id}") |> html_response(200)

      assert html =~ ~s|<meta name="widget-socket" content="/widgets/live">|
      assert [_, token] = Regex.run(~r/name="widget-token"\s+content="([^"]+)"/, html)
      assert {:ok, %{kind: :anon, sync_id: @sync_id}} = WidgetToken.verify(token)
    end

    test "non-embed pages do not carry widget socket meta tags", %{conn: conn} do
      html = conn |> get("/connect") |> html_response(200)
      refute html =~ ~s|name="widget-socket"|
      refute html =~ ~s|name="widget-token"|
    end
  end

  describe "token-backed authed mount" do
    test "pushes a renewable session token", %{conn: conn} do
      user = registered_user_fixture()
      user_token = Accounts.generate_user_session_token(user)

      session =
        %{kind: :authed, user_token: user_token, sync_id: @sync_id}
        |> WidgetToken.session_for()

      {:ok, view, _html} = live(init_test_session(conn, session), "/widgets/ads_ext/")

      assert_push_event(view, "qadabra:widget-session-token", %{token: token})

      assert {:ok, %{kind: :session, user_token: ^user_token, sync_id: @sync_id}} =
               WidgetToken.verify(token)
    end

    test "pushes nothing for a cookie-backed authed mount", %{conn: conn} do
      user = registered_user_fixture()
      {:ok, view, _html} = live(log_in_user(conn, user), "/widgets/ads_ext/")

      refute_push_event(view, "qadabra:widget-session-token", %{})
    end

    test "logging out from a token-backed widget deletes the DB session token", %{conn: conn} do
      user = registered_user_fixture()
      user_token = Accounts.generate_user_session_token(user)

      session =
        %{kind: :authed, user_token: user_token, sync_id: @sync_id}
        |> WidgetToken.session_for()

      {:ok, view, _html} = live(init_test_session(conn, session), "/widgets/ads_ext/")

      render_hook(view, "confirm_widget_logout", %{})

      assert_push_event(view, "qadabra:session-logout", %{token_session: true})
      refute Accounts.get_user_by_session_token(user_token)
    end
  end
end
