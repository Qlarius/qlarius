# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Qlarius.Repo.insert!(%Qlarius.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Qlarius.Accounts
alias Qlarius.Accounts.User
alias Qlarius.Wallets.LedgerEntry
alias Qlarius.Wallets.LedgerHeader
alias Qlarius.Repo

Repo.delete_all(User)

{:ok, user} =
  Accounts.register_user(%{
    email: "test@qlarius.com",
    password: "password1234",
    password_confirmation: "password1234"
  })

balance = Decimal.new("0.00")

ledger_header =
  %LedgerHeader{
    user_id: user.id,
    description: "Example Ledger",
    balance: balance
  }
  |> Repo.insert!()

cents = [0, 19, 29, 39, 49, 59, 69, 79, 99]

balance =
  Enum.reduce(1..100, balance, fn _, balance ->
    amount = Decimal.new("#{Enum.random(0..2)}.#{Enum.random(cents)}")
    balance = Decimal.add(balance, amount)

    %LedgerEntry{
      amount: amount,
      description: Faker.Lorem.sentence(2..3),
      running_balance: balance,
      ledger_header_id: ledger_header.id
    }
    |> Repo.insert!()

    balance
  end)

ledger_header
|> Ecto.Changeset.change(%{balance: balance})
|> Repo.update!()
