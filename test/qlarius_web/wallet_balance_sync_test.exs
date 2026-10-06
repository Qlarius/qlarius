defmodule QlariusWeb.WalletBalanceSyncTest do
  use ExUnit.Case, async: true

  alias Qlarius.Accounts.User
  alias Qlarius.Wallets.LedgerHeader
  alias Qlarius.YouData.MeFiles.MeFile
  alias QlariusWeb.WalletBalanceSync

  describe "apply_sync_hook/2" do
    # Real structs, as in a live session: the tippable amount is worked out
    # from the preloaded MeFile and ledger header, so no database is needed.
    test "applies balance update without crashing" do
      me_file = %MeFile{
        id: 1,
        credit_allowance: Decimal.new("2.00"),
        ledger_header: %LedgerHeader{
          balance: Decimal.new("1.25"),
          balance_payable: Decimal.new("0.00")
        }
      }

      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          current_scope: %{
            wallet_balance: Decimal.new("3.25"),
            user: %User{me_file: me_file}
          },
          balance: Decimal.new("3.25")
        }
      }

      new_balance = Decimal.new("3.00")

      updated =
        WalletBalanceSync.apply_sync_hook(
          socket,
          {:me_file_balance_updated, new_balance}
        )

      assert updated.assigns.balance == new_balance
      assert updated.assigns.current_scope.wallet_balance == new_balance
      # Tips spend activity only, never the credit allowance.
      assert Decimal.equal?(updated.assigns.current_scope.available_to_tip, Decimal.new("1.25"))
    end
  end

  describe "notify_parent_after_sync?/1" do
    test "skips refetch and direct balance pushes to avoid parent ping-pong" do
      refute WalletBalanceSync.notify_parent_after_sync?(:update_balance)

      refute WalletBalanceSync.notify_parent_after_sync?(
               {:me_file_balance_updated, Decimal.new("1")}
             )

      refute WalletBalanceSync.notify_parent_after_sync?(:ledger_updated)
      refute WalletBalanceSync.notify_parent_after_sync?({:me_file_ledger_updated, 1})
    end

    test "allows stats and offer refreshes to bubble up" do
      assert WalletBalanceSync.notify_parent_after_sync?({:me_file_stats_updated, 1})
      assert WalletBalanceSync.notify_parent_after_sync?({:me_file_offers_updated, 1})
      assert WalletBalanceSync.notify_parent_after_sync?({:refresh_wallet_balance, 1})
    end
  end

  describe "forward_to_inline_embed?/1" do
    test "does not forward balance already pushed from the embed" do
      refute WalletBalanceSync.forward_to_inline_embed?(
               {:me_file_balance_updated, Decimal.new("1")}
             )
    end

    test "forwards refetch and stats events to the embed" do
      assert WalletBalanceSync.forward_to_inline_embed?(:update_balance)
      assert WalletBalanceSync.forward_to_inline_embed?({:me_file_stats_updated, 1})
    end
  end
end
