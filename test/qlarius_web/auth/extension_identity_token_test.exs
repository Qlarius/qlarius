defmodule QlariusWeb.Auth.ExtensionIdentityTokenTest do
  use ExUnit.Case, async: true

  alias QlariusWeb.Auth.ExtensionIdentityToken

  test "sign and verify round-trip" do
    token =
      ExtensionIdentityToken.sign(%{
        user_id: 42,
        device_id: "device-abc",
        surface: "test"
      })

    assert {:ok, payload} = ExtensionIdentityToken.verify(token)
    assert payload.user_id == 42
    assert payload.device_id == "device-abc"
    assert is_binary(payload.jti)
  end

  test "invalidate rejects further verifies" do
    token =
      ExtensionIdentityToken.sign(%{
        user_id: 7,
        device_id: "device-xyz"
      })

    assert :ok = ExtensionIdentityToken.invalidate_token(token)
    assert {:error, :invalidated} = ExtensionIdentityToken.verify(token)
  end

  test "rejects malformed tokens" do
    assert {:error, :invalid} = ExtensionIdentityToken.verify("not-a-token")
  end
end
