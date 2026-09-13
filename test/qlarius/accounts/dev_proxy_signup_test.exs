defmodule Qlarius.Accounts.DevProxySignupTest do
  use Qlarius.DataCase, async: false

  alias Qlarius.Accounts
  alias Qlarius.Accounts.DevProxySignup
  alias Qlarius.Accounts.User
  alias Qlarius.Accounts.UserProxy
  alias Qlarius.Repo

  @trigger "5551234567"
  @true_alias "trae@qlarius.com"

  setup do
    previous_bypass = Application.get_env(:qlarius, :bypass_phone_verification)
    previous_cfg = Application.get_env(:qlarius, :dev_proxy_signup)

    on_exit(fn ->
      restore_env(:bypass_phone_verification, previous_bypass)
      restore_env(:dev_proxy_signup, previous_cfg)
    end)

    Application.delete_env(:qlarius, :bypass_phone_verification)
    Application.delete_env(:qlarius, :dev_proxy_signup)
    :ok
  end

  describe "resolve_true_user/1" do
    test "ignores when bypass is off even if config is set" do
      enable_config()
      Application.put_env(:qlarius, :bypass_phone_verification, false)

      assert DevProxySignup.resolve_true_user(@trigger) == :ignore
      refute DevProxySignup.enabled?()
    end

    test "ignores when config is unset" do
      Application.put_env(:qlarius, :bypass_phone_verification, true)

      assert DevProxySignup.resolve_true_user(@trigger) == :ignore
    end

    test "ignores a non-trigger phone" do
      enable_hook()

      assert DevProxySignup.resolve_true_user("5550001111") == :ignore
    end

    test "returns true_user_missing when the alias does not exist" do
      enable_hook()

      assert DevProxySignup.resolve_true_user(@trigger) == {:error, :true_user_missing}
      assert DevProxySignup.missing_true_user_message() =~ @true_alias
    end

    test "matches formatted and E.164 variants and returns the true user" do
      enable_hook()
      true_user = insert_true_user!()

      for phone <- [@trigger, "555-123-4567", "+15551234567", "15551234567"] do
        assert {:ok, %{id: id}} = DevProxySignup.resolve_true_user(phone)
        assert id == true_user.id
      end
    end
  end

  describe "omit_persisted_phone?/1" do
    test "is true only for the trigger while the hook is on" do
      enable_hook()

      assert DevProxySignup.omit_persisted_phone?("555-123-4567")
      refute DevProxySignup.omit_persisted_phone?("5550001111")

      Application.put_env(:qlarius, :bypass_phone_verification, false)
      refute DevProxySignup.omit_persisted_phone?(@trigger)
    end
  end

  describe "register + activate" do
    test "creates a proxy without persisting the trigger phone and activates it" do
      enable_hook()
      true_user = insert_true_user!()

      {:ok, %{user: proxy}} =
        Accounts.register_new_user(%{
          alias: "proxy-#{System.unique_integer([:positive])}",
          mobile_number: nil,
          role: "user",
          date_of_birth: ~D[1990-01-01],
          true_user_id: true_user.id
        })

      assert is_nil(proxy.mobile_number_hash)
      assert {:ok, _} = Accounts.activate_proxy_user(true_user.id, proxy.id)

      link =
        Repo.get_by!(UserProxy, true_user_id: true_user.id, proxy_user_id: proxy.id)

      assert link.active

      active = User.active_proxy_user_or_self(Accounts.get_user!(true_user.id))
      assert active.id == proxy.id
    end
  end

  defp enable_hook do
    Application.put_env(:qlarius, :bypass_phone_verification, true)
    enable_config()
  end

  defp enable_config do
    Application.put_env(:qlarius, :dev_proxy_signup,
      trigger_phone: @trigger,
      true_user_alias: @true_alias
    )
  end

  defp insert_true_user! do
    {:ok, %{user: user}} =
      Accounts.register_new_user(%{
        alias: @true_alias,
        role: "user",
        date_of_birth: ~D[1980-01-01]
      })

    user
  end

  defp restore_env(key, nil), do: Application.delete_env(:qlarius, key)
  defp restore_env(key, value), do: Application.put_env(:qlarius, key, value)
end
