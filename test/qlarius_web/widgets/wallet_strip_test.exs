defmodule QlariusWeb.Widgets.WalletStripTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Qlarius.Accounts.Scope
  alias QlariusWeb.Components.WalletBalance
  alias QlariusWeb.Widgets.Arcade.Components
  alias QlariusWeb.Widgets.UnauthCTA

  describe "wallet_balance/1" do
    test "a labelled pill shows a wallet icon and the amount, with the label as its name" do
      html =
        render_component(&WalletBalance.wallet_balance/1,
          id: "w",
          balance: Decimal.new("40.67"),
          footer_label: "WALLET"
        )

      assert html =~ "wallet-balance-pill--labelled"
      assert html =~ "hero-wallet"
      assert html =~ ~s(aria-label="Wallet")
      assert html =~ "$40.67"
      # The amount is the only text, so WalletPulse can read it
      refute html =~ ">WALLET<"
    end

    test "dialogs can drop the icon and keep the label" do
      html =
        render_component(&WalletBalance.wallet_balance/1,
          id: "w",
          balance: Decimal.new("40.67"),
          footer_label: "WALLET",
          icon?: false
        )

      assert html =~ "wallet-balance-pill--labelled"
      assert html =~ ~s(aria-label="Wallet")
      refute html =~ "hero-wallet"
    end

    test "the app header chip stays a plain amount" do
      html = render_component(&WalletBalance.wallet_balance/1, id: "w", balance: Decimal.new("5"))

      refute html =~ "wallet-balance-pill--labelled"
      refute html =~ "hero-wallet"
    end
  end

  describe "wallet_strip/1" do
    test "pill, arrow and top up sit together; the top up menu is compact rows" do
      html =
        render_component(&Components.wallet_strip/1,
          id: "strip",
          balance: Decimal.new("40.67"),
          offered_amount: Decimal.new("1.14"),
          ads_count: 9,
          daily_gift_available?: true
        )

      assert html =~ "wallet-strip-tray__row"
      assert html =~ "hero-arrow-long-left"
      assert html =~ "$1.64"
      assert html =~ "Top up wallet"
      assert html =~ "arqade-menu-row"
      assert html =~ ~s(id="strip-sponster-open")
      assert html =~ "9 ads • $1.14"
      assert html =~ "Daily gift"
    end

    test "a used daily gift is a disabled row" do
      html =
        render_component(&Components.wallet_strip/1,
          id: "strip",
          balance: Decimal.new("1"),
          offered_amount: Decimal.new("0"),
          ads_count: 0,
          daily_gift_available?: false
        )

      assert html =~ ~s(id="strip-sponster-open-disabled")
      assert html =~ ~r/phx-click="daily-gift"[^>]*disabled|disabled[^>]*phx-click="daily-gift"/
    end
  end

  test "anonymous strip shows READY, the arrow and Connect" do
    html = render_component(&UnauthCTA.wallet_strip_or_connect/1, scope: %Scope{}, id: "anon")

    assert html =~ "READY"
    assert html =~ "wallet-strip-tray__row"
    assert html =~ "hero-arrow-long-left"
    assert html =~ "Connect"
  end
end
