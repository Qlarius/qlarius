defmodule QlariusWeb.WalletBalanceSyncTest do
  use ExUnit.Case, async: true

  alias QlariusWeb.WalletBalanceSync

  describe "apply_sync_hook/2" do
    test "applies balance update without crashing" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          current_scope: %{
            wallet_balance: Decimal.new("1.25"),
            user: %{me_file: %{ledger_header: %{balance: Decimal.new("1.25")}}}
          },
          balance: Decimal.new("1.25")
        }
      }

      new_balance = Decimal.new("1.00")

      updated =
        WalletBalanceSync.apply_sync_hook(
          socket,
          {:me_file_balance_updated, new_balance}
        )

      assert updated.assigns.balance == new_balance
      assert updated.assigns.current_scope.wallet_balance == new_balance
    end
  end

  describe "notify_parent_after_sync?/1" do
    test "skips refetch and direct balance pushes to avoid parent ping-pong" do
      refute WalletBalanceSync.notify_parent_after_sync?(:update_balance)
      refute WalletBalanceSync.notify_parent_after_sync?({:me_file_balance_updated, Decimal.new("1")})
    end

    test "allows stats and offer refreshes to bubble up" do
      assert WalletBalanceSync.notify_parent_after_sync?({:me_file_stats_updated, 1})
      assert WalletBalanceSync.notify_parent_after_sync?({:me_file_offers_updated, 1})
      assert WalletBalanceSync.notify_parent_after_sync?({:refresh_wallet_balance, 1})
    end
  end

  describe "forward_to_inline_embed?/1" do
    test "does not forward balance already pushed from the embed" do
      refute WalletBalanceSync.forward_to_inline_embed?({:me_file_balance_updated, Decimal.new("1")})
    end

    test "forwards refetch and stats events to the embed" do
      assert WalletBalanceSync.forward_to_inline_embed?(:update_balance)
      assert WalletBalanceSync.forward_to_inline_embed?({:me_file_stats_updated, 1})
    end
  end
end
