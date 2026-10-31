defmodule QlariusWeb.Auth.WidgetTokenTest do
  use ExUnit.Case, async: true

  alias QlariusWeb.Auth.WidgetToken

  @sync_id "3f6a2c9e-1b4d-4e8f-9a0b-7c5d6e8f9a1b"

  test "anon token round-trips and builds a sync-only session" do
    token = WidgetToken.sign_anon(@sync_id)

    assert {:ok, %{kind: :anon, sync_id: @sync_id, user_token: nil} = payload} =
             WidgetToken.verify(token)

    assert WidgetToken.session_for(payload) == %{
             "session_sync_id" => @sync_id,
             "widget_token_session" => true,
             "widget_token_kind" => "anon"
           }
  end

  test "anon token without a sync id yields a session without one" do
    assert {:ok, payload} = WidgetToken.verify(WidgetToken.sign_anon(nil))

    assert WidgetToken.session_for(payload) == %{
             "widget_token_session" => true,
             "widget_token_kind" => "anon"
           }
  end

  test "authed token is accepted once and mirrors the cookie session keys" do
    user_token = :crypto.strong_rand_bytes(32)
    token = WidgetToken.sign_authed(user_token, @sync_id)

    assert {:ok, %{kind: :authed, user_token: ^user_token, sync_id: @sync_id} = payload} =
             WidgetToken.verify(token)

    assert WidgetToken.session_for(payload) == %{
             "session_sync_id" => @sync_id,
             "user_token" => user_token,
             "live_socket_id" => "users_sessions:#{Base.url_encode64(user_token)}",
             "widget_token_session" => true,
             "widget_token_kind" => "authed"
           }

    assert {:error, :used} = WidgetToken.verify(token)
  end

  test "session token is reusable and marks its kind" do
    user_token = :crypto.strong_rand_bytes(32)
    token = WidgetToken.sign_session(user_token, @sync_id)

    assert {:ok, %{kind: :session, user_token: ^user_token} = payload} =
             WidgetToken.verify(token)

    assert {:ok, %{kind: :session, user_token: ^user_token}} = WidgetToken.verify(token)
    assert WidgetToken.session_for(payload)["widget_token_kind"] == "session"
  end

  test "rejects garbage, empty, and non-binary input" do
    assert {:error, :invalid} = WidgetToken.verify("not-a-token")
    assert {:error, :invalid} = WidgetToken.verify("")
    assert {:error, :invalid} = WidgetToken.verify(nil)
    assert {:error, :invalid} = WidgetToken.verify(%{})
  end

  describe "lifetimes" do
    @salt "qadabra widget socket v1"

    defp aged(payload, seconds_ago) do
      Phoenix.Token.sign(QlariusWeb.Endpoint, @salt, payload,
        signed_at: System.system_time(:second) - seconds_ago
      )
    end

    test "anon tokens expire after a day" do
      assert {:ok, %{kind: :anon}} =
               WidgetToken.verify(aged(%{kind: :anon, sync_id: @sync_id}, 60))

      assert {:error, :expired} =
               WidgetToken.verify(aged(%{kind: :anon, sync_id: @sync_id}, 25 * 60 * 60))
    end

    test "authed hand-offs expire after two minutes" do
      payload = %{kind: :authed, user_token: "u", sync_id: @sync_id, jti: "jti-aged-1"}
      assert {:error, :expired} = WidgetToken.verify(aged(payload, 180))
    end

    test "session tokens outlive a day and expire after thirty" do
      payload = %{kind: :session, user_token: "u", sync_id: @sync_id}

      assert {:ok, %{kind: :session}} = WidgetToken.verify(aged(payload, 20 * 24 * 60 * 60))
      assert {:error, :expired} = WidgetToken.verify(aged(payload, 31 * 24 * 60 * 60))
    end
  end

  test "rejects tokens signed with another salt" do
    other = Phoenix.Token.sign(QlariusWeb.Endpoint, "some other salt", %{kind: :anon})
    assert {:error, :invalid} = WidgetToken.verify(other)
  end
end
