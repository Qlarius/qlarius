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
alias Qlarius.LedgerEntry
alias Qlarius.LedgerHeader
alias Qlarius.Repo

Repo.delete_all(User)

{:ok, user} =
  Accounts.register_user(%{
    email: "test@qlarius.com",
    password: "password1234",
    password_confirmation: "password1234"
  })

ledger_header =
  %LedgerHeader{
    user_id: user.id,
    description: "Example Ledger",
    balance: Decimal.new("1000.00")
  }
  |> Repo.insert!()

for _ <- 1..20 do
  %LedgerEntry{
    amount: Decimal.new("#{Enum.random(1..100)}.#{Enum.random(0..99)}"),
    description: Faker.Lorem.sentence(2..3),
    ledger_header_id: ledger_header.id
  }
  |> Repo.insert!()
end
