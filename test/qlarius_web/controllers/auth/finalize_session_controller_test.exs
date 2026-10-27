defmodule QlariusWeb.Auth.FinalizeSessionControllerTest do
  use QlariusWeb.ConnCase, async: true

  import Qlarius.WidgetAuthFixtures

  alias Qlarius.Accounts
  alias QlariusWeb.Auth.{FinalizeToken, WidgetToken}

  @sync_id "6f5e4d3c-2b1a-4f0e-9d8c-7b6a5f4e3d2c"

  setup do
    user = registered_user_fixture()
    %{user: user, finalize_token: FinalizeToken.sign(%{user_id: user.id, surface: "test"})}
  end

  # `build_conn/0` carries no session cookie and no CSRF token: the
  # situation inside a widget iframe in a cookie-blocking browser.
  defp post_finalize(conn, body) do
    conn
    |> put_req_header("accept", "application/json")
    |> put_req_header("content-type", "application/json")
    |> post(~p"/auth/finalize_session", Jason.encode!(body))
  end

  test "finalizes without a cookie or CSRF token and returns a widget_token",
       %{conn: conn, user: user, finalize_token: finalize_token} do
    conn = post_finalize(conn, %{token: finalize_token, sync_id: @sync_id})

    assert %{"widget_token" => widget_token} = json_response(conn, 200)

    assert {:ok, %{kind: :authed, user_token: user_token, sync_id: @sync_id}} =
             WidgetToken.verify(widget_token)

    assert Accounts.get_user_by_session_token(user_token).id == user.id
    assert get_session(conn, :user_token) == user_token
    assert get_session(conn, :session_sync_id) == @sync_id
  end

  test "is served from the CSRF-free pipeline" do
    assert %{pipe_through: [:auth_exchange]} =
             Phoenix.Router.route_info(QlariusWeb.Router, "POST", "/auth/finalize_session", "")
  end

  test "ignores a malformed sync_id", %{conn: conn, finalize_token: finalize_token} do
    conn = post_finalize(conn, %{token: finalize_token, sync_id: "nope"})

    assert %{"widget_token" => widget_token} = json_response(conn, 200)
    assert {:ok, %{sync_id: sync_id}} = WidgetToken.verify(widget_token)
    assert {:ok, _} = Ecto.UUID.cast(sync_id)
  end

  test "rejects a replayed token", %{conn: conn, finalize_token: finalize_token} do
    assert json_response(post_finalize(conn, %{token: finalize_token}), 200)

    conn = post_finalize(conn, %{token: finalize_token})
    assert %{"error" => "token_replayed"} = json_response(conn, 422)
    refute get_session(conn, :user_token)
  end

  test "rejects an expired token", %{conn: conn, user: user} do
    expired =
      Phoenix.Token.sign(
        QlariusWeb.Endpoint,
        "qadabra auth finalize v1",
        %{user_id: user.id, jti: "expired-jti", iat: 0},
        signed_at: System.system_time(:second) - FinalizeToken.max_age_seconds() - 5
      )

    conn = post_finalize(conn, %{token: expired})
    assert %{"error" => "token_expired"} = json_response(conn, 422)
    refute get_session(conn, :user_token)
  end

  test "rejects an invalid token", %{conn: conn} do
    conn = post_finalize(conn, %{token: "garbage"})
    assert %{"error" => "invalid_token"} = json_response(conn, 422)
    refute get_session(conn, :user_token)
  end

  test "rejects a missing token", %{conn: conn} do
    conn = post_finalize(conn, %{})
    assert %{"error" => "missing_token"} = json_response(conn, 422)
  end
end
