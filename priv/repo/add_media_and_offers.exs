alias Qlarius.Accounts.User
alias Qlarius.Sponster.Ads.AdCategory
alias Qlarius.Sponster.Ads.MediaPiece
alias Qlarius.Marketing.MediaRun
alias Qlarius.Marketing.MediaSequence
alias Qlarius.Offer
alias Qlarius.Repo

user = Repo.get_by!(User, email: "test@qlarius.com")

Repo.delete_all(Offer)
Repo.delete_all(MediaPiece)
Repo.delete_all(MediaRun)
Repo.delete_all(MediaSequence)

categories = Repo.all(AdCategory)

for _ <- 1..10 do
  media_piece =
    %MediaPiece{
      title: Faker.Lorem.sentence(),
      display_url: "example.com",
      body_copy: Faker.Lorem.paragraph(),
      jump_url: "example.com",
      ad_category: Enum.random(categories)
    }
    |> Repo.insert!()

  media_sequence = %MediaSequence{title: "Sequence"} |> Repo.insert!()

  media_run =
    %MediaRun{media_piece: media_piece, media_sequence: media_sequence}
    |> Repo.insert!()

  p1_amt = Decimal.new("0.05")
  p2_amt = Decimal.new("0.#{Enum.random(15..99)}")

  %Offer{
    user_id: user.id,
    media_run: media_run,
    phase_1_amount: p1_amt,
    phase_2_amount: p2_amt,
    amount: Decimal.add(p1_amt, p2_amt)
  }
  |> Repo.insert!()
end
