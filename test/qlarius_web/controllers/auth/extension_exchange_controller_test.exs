defmodule QlariusWeb.Auth.ExtensionExchangeControllerTest do
  # Toggles :auth_sheet application env.
  use QlariusWeb.ConnCase, async: false

  import Qlarius.WidgetAuthFixtures

  alias Qlarius.Accounts
  alias QlariusWeb.Auth.{ExtensionIdentityToken, WidgetToken}

  @sync_id "0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d"

  setup do
    previous = Application.get_env(:qlarius, :auth_sheet, [])

    Application.put_env(
      :qlarius,
      :auth_sheet,
      previous
      |> Keyword.put(:extension_exchange_enabled, true)
      |> Keyword.put(:extension_token_emit, true)
    )

    on_exit(fn -> Application.put_env(:qlarius, :auth_sheet, previous) end)

    user = registered_user_fixture()
    token = ExtensionIdentityToken.sign(%{user_id: user.id, device_id: "dev-1", surface: "test"})
    %{user: user, vault_token: token}
  end

  defp post_exchange(conn, body) do
    conn
    |> put_req_header("accept", "application/json")
    |> put_req_header("content-type", "application/json")
    |> post(~p"/auth/extension_exchange", Jason.encode!(body))
  end

  test "exchanges without a session cookie or CSRF token and returns a widget_token",
       %{conn: conn, user: user, vault_token: vault_token} do
    conn = post_exchange(conn, %{token: vault_token, device_id: "dev-1", sync_id: @sync_id})

    assert %{"widget_token" => widget_token} = json_response(conn, 200)

    assert {:ok, %{kind: :authed, user_token: user_token, sync_id: @sync_id}} =
             WidgetToken.verify(widget_token)

    assert Accounts.get_user_by_session_token(user_token).id == user.id
    assert get_session(conn, :user_token) == user_token
    assert get_session(conn, :session_sync_id) == @sync_id
  end

  test "ignores a malformed sync_id", %{conn: conn, vault_token: vault_token} do
    conn = post_exchange(conn, %{token: vault_token, device_id: "dev-1", sync_id: "nope"})

    assert %{"widget_token" => widget_token} = json_response(conn, 200)
    assert {:ok, %{sync_id: sync_id}} = WidgetToken.verify(widget_token)
    assert {:ok, _} = Ecto.UUID.cast(sync_id)
    assert sync_id != "nope"
  end

  test "rejects a device mismatch", %{conn: conn, vault_token: vault_token} do
    conn = post_exchange(conn, %{token: vault_token, device_id: "other"})
    assert %{"error" => "device_mismatch"} = json_response(conn, 422)
  end

  test "rejects an invalid vault token", %{conn: conn} do
    conn = post_exchange(conn, %{token: "garbage", device_id: "dev-1"})
    assert %{"error" => "invalid_token"} = json_response(conn, 422)
  end

  test "is served from the CSRF-free pipeline", %{conn: conn} do
    # `build_conn/0` has no session, so `protect_from_forgery` would raise
    # on a pipeline that still has it; a 4xx JSON error means we got through.
    conn = post_exchange(conn, %{token: "garbage"})
    assert %{"error" => "invalid_token"} = json_response(conn, 422)

    assert %{pipe_through: [:auth_exchange]} =
             Phoenix.Router.route_info(QlariusWeb.Router, "POST", "/auth/extension_exchange", "")
  end

  describe "GET /auth/session_status" do
    test "reports anonymous and hands back a CSRF token that the mint accepts", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> get(~p"/auth/session_status")

      assert %{"authed" => false, "csrf_token" => csrf} = json_response(conn, 200)
      assert is_binary(csrf) and csrf != ""

      # Same browser, next request: the token from the probe passes
      # protect_from_forgery on the CSRF-guarded mint endpoint (401 means we
      # got past CSRF and failed only on the missing user).
      conn =
        conn
        |> recycle()
        |> put_req_header("accept", "application/json")
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-csrf-token", csrf)
        |> post(~p"/auth/extension_token", Jason.encode!(%{device_id: "dev-1"}))

      assert %{"error" => "unauthenticated"} = json_response(conn, 401)
    end

    test "reports authed for a signed-in session", %{conn: conn, user: user} do
      conn =
        conn
        |> log_in_user(user)
        |> put_req_header("accept", "application/json")
        |> get(~p"/auth/session_status")

      assert %{"authed" => true, "csrf_token" => _} = json_response(conn, 200)
    end
  end
end
