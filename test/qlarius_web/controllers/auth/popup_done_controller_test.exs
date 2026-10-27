defmodule QlariusWeb.Auth.PopupDoneControllerTest do
  use QlariusWeb.ConnCase, async: true

  import Qlarius.WidgetAuthFixtures

  alias QlariusWeb.Auth.WidgetToken

  @sync_id "5e4d3c2b-1a0f-4e9d-8c7b-6a5f4e3d2c1b"

  defp widget_token_from(html) do
    case Regex.run(~r/"widget_token":"([^"]+)"/, html) do
      [_, token] -> token
      nil -> nil
    end
  end

  test "hands a validated opener a one-shot widget_token for the session user", %{conn: conn} do
    user = registered_user_fixture()

    conn =
      conn
      |> log_in_user(user)
      |> get(~p"/auth/popup_done?opener_origin=https://localhost:4001&sync_id=#{@sync_id}")

    html = html_response(conn, 200)
    assert html =~ ~s|"https://localhost:4001"|
    assert html =~ "qadabra:auth:popup-done"

    token = widget_token_from(html)
    assert is_binary(token)

    assert {:ok, %{kind: :authed, user_token: user_token, sync_id: @sync_id}} =
             WidgetToken.verify(token)

    assert user_token == get_session(conn, :user_token)
  end

  test "posts to * with no token when opener_origin is absent", %{conn: conn} do
    conn = conn |> log_in_user(registered_user_fixture()) |> get(~p"/auth/popup_done")

    html = html_response(conn, 200)
    assert html =~ ~s|var target = "*"|
    refute widget_token_from(html)
  end

  test "refuses a foreign opener_origin", %{conn: conn} do
    conn =
      conn
      |> log_in_user(registered_user_fixture())
      |> get(~p"/auth/popup_done?opener_origin=https://evil.example")

    html = html_response(conn, 200)
    assert html =~ ~s|var target = "*"|
    refute widget_token_from(html)
  end

  test "refuses an opener_origin with a path or over plain http on a public host", %{conn: conn} do
    conn = log_in_user(conn, registered_user_fixture())

    for origin <- ["https://qadabra.app/evil", "http://qadabra.app", "javascript:alert(1)"] do
      html =
        conn
        |> get(~p"/auth/popup_done?opener_origin=#{origin}")
        |> html_response(200)

      refute widget_token_from(html), "accepted #{origin}"
    end
  end

  test "mints nothing for an anonymous popup", %{conn: conn} do
    html =
      conn
      |> get(~p"/auth/popup_done?opener_origin=https://localhost:4001")
      |> html_response(200)

    refute widget_token_from(html)
  end
end
