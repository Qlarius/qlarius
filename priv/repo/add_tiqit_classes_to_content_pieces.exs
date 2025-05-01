alias Qlarius.Accounts
alias Qlarius.Accounts.User
alias Qlarius.Arcade.ContentGroup
alias Qlarius.Arcade.ContentPiece
alias Qlarius.Arcade.Tiqit
alias Qlarius.Arcade.TiqitClass
alias Qlarius.Repo

Repo.delete_all(TiqitClass)

Repo.all(ContentPiece)
|> Enum.each(fn piece ->
  [
    {"3 hours", 3, "0.79"},
    {"24 hours", 24, "2.79"},
    {"7 days", 7*24, "4.79"},
    {"30 days", 30*24, "9.99"},
  ] |> Enum.each(fn {name, dur, price} ->
      %TiqitClass{
        content_piece: piece,
        name: name,
        duration_hours: dur,
        price: Decimal.new(price),
        active: true
      }
      |> Repo.insert!()
    end)
end)
