defmodule QlariusWeb.WalletBalanceSyncDailyGiftTest do
  use Qlarius.DataCase, async: false

  alias Qlarius.Accounts.User
  alias Qlarius.Repo
  alias Qlarius.Wallets
  alias Qlarius.Wallets.LedgerHeader
  alias Qlarius.YouData.MeFiles.MeFile
  alias QlariusWeb.WalletBalanceSync

  test "a balance refresh keeps the gift claimed on the acting wallet" do
    acting = wallet_user!("acting")
    signed_in = wallet_user!("signed-in")

    assert {:ok, :credited} = Wallets.claim_daily_gift(acting)

    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        current_scope: %{
          true_user: signed_in,
          user: acting,
          wallet_balance: Decimal.new("0.00")
        },
        daily_gift_available?: true,
        current_balance: Decimal.new("0.00")
      }
    }

    updated =
      WalletBalanceSync.apply_sync_hook(
        socket,
        {:me_file_balance_updated, Decimal.new("0.50")}
      )

    refute updated.assigns.daily_gift_available?
  end

  defp wallet_user!(label) do
    user =
      %User{}
      |> User.registration_changeset(%{
        alias: "#{label}-#{System.unique_integer([:positive])}",
        role: "consumer"
      })
      |> Repo.insert!()

    me_file =
      %MeFile{}
      |> MeFile.changeset(%{user_id: user.id, date_of_birth: ~D[1990-01-01]})
      |> Repo.insert!()

    header =
      Repo.insert!(%LedgerHeader{
        description: "Consumer",
        balance: Decimal.new("0.00"),
        balance_payable: Decimal.new("0.00"),
        me_file_id: me_file.id
      })

    %{user | me_file: %{me_file | ledger_header: header}}
  end
end
