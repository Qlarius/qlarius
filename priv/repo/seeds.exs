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
alias Qlarius.Campaigns.MediaPiece
alias Qlarius.LedgerEntry
alias Qlarius.LedgerHeader
alias Qlarius.Offer
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

for _ <- 1..10 do
  media_piece =
    %MediaPiece{
      title: Faker.Lorem.sentence(),
      display_url: "example.com",
      body_copy: Faker.Lorem.paragraph()
    }
    |> Repo.insert!()

  p1_amt = Decimal.new("#{Enum.random(100..999)}.#{Enum.random(0..99)}")
  p2_amt = Decimal.new("#{Enum.random(100..999)}.#{Enum.random(0..99)}")

  %Offer{
    user_id: user.id,
    media_piece_id: media_piece.id,
    phase_1_amount: p1_amt,
    phase_2_amount: p2_amt,
    amount: Decimal.add(p1_amt, p2_amt)
  }
  |> Repo.insert!()
end
