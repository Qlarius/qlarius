defmodule QlariusWeb.UserSessionControllerTest do
  use QlariusWeb.ConnCase, async: true

  test "logout returns to /hi so the page can prompt a reconnect", %{conn: conn} do
    conn = delete(conn, ~p"/logout")

    assert redirected_to(conn) == ~p"/hi?reconnect=1"
  end

  test "logout with a local return path stays on that path", %{conn: conn} do
    conn = delete(conn, ~p"/logout", %{"return_to" => "/@ada"})

    assert redirected_to(conn) == "/@ada"
  end
end
