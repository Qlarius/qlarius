alias Qlarius.Accounts
alias Qlarius.Accounts.User
alias Qlarius.Arcade.ContentGroup
alias Qlarius.Arcade.ContentPiece
alias Qlarius.Arcade.Tiqit
alias Qlarius.Arcade.TiqitType
alias Qlarius.Repo

Repo.delete_all(Tiqit)
Repo.delete_all(TiqitType)
Repo.delete_all(ContentGroup)
Repo.delete_all(ContentPiece)

creator = %User{} = Accounts.get_user_by_email("test@qlarius.com")

group = %ContentGroup{
  title: "Learn Elixir",
  description: "Elixir is a functional programming language created by José Valim",
  creator_id: creator.id
}
|> Repo.insert!()

video = %ContentPiece{
  creator: creator,
  title: "Introduction to Elixir",
  description: "Learn the fundamentals of Elixir programming in this comprehensive introduction.",
  content_type: :video,
  file_url: "https://example.com/videos/intro_elixir.mp4",
  preview_url: "https://example.com/videos/intro_elixir_preview.mp4",
  date_published: Date.utc_today(),
  price_default: Decimal.new("5.00")
}
|> Repo.insert!()

# Associate video with group
Repo.insert_all("content_groups_content_pieces", [%{
  content_group_id: group.id,
  content_piece_id: video.id,
  inserted_at: DateTime.utc_now(),
  updated_at: DateTime.utc_now()
}])

# Tiqit Types for Video
%TiqitType{
  content_piece_id: video.id,
  name: "1-hour access",
  duration_hours: 1,
  price: Decimal.new("2.00"),
  active: true
}
|> Repo.insert!()

%TiqitType{
  content_piece_id: video.id,
  name: "24-hour access",
  duration_hours: 24,
  price: Decimal.new("4.50"),
  active: true
}
|> Repo.insert!()

# Example ContentPiece 2: Podcast
podcast = %ContentPiece{
  creator: creator,
  title: "Tech Talk: AI Innovations",
  description: "Join us as we dive into the latest advancements in artificial intelligence. We'll explore the latest trends in AI, including natural language processing, machine learning, and more. Perfect for tech enthusiasts who want to stay ahead of the curve.",
  content_type: :podcast,
  date_published: ~D[2025-03-15],
  length: 1800, # 30 minutes in seconds
  preview_length: 120, # 2 minute preview
  file_url: "https://example.com/podcasts/ai_innovations.mp3",
  preview_url: "https://example.com/podcasts/ai_innovations_preview.mp3",
  price_default: Decimal.new("3.00")
}
|> Repo.insert!()

# Associate podcast with group
Repo.insert_all("content_groups_content_pieces", [%{
  content_group_id: group.id,
  content_piece_id: podcast.id,
  inserted_at: DateTime.utc_now(),
  updated_at: DateTime.utc_now()
}])

# Tiqit Types for Podcast
%TiqitType{
  content_piece_id: podcast.id,
  name: "1-hour access",
  duration_hours: 1,
  price: Decimal.new("1.50"),
  active: true
}
|> Repo.insert!()

%TiqitType{
  content_piece_id: podcast.id,
  name: "7-day access",
  duration_hours: 7 * 24,
  price: Decimal.new("2.75"),
  active: true
}
|> Repo.insert!()

# Example ContentPiece 3: Blog Post
blog = %ContentPiece{
  creator: creator,
  title: "The Future of Content Creation",
  description: "In this blog post, we'll explore the latest trends in content creation, including the rise of AI-powered tools and the importance of user engagement. We'll also discuss the future of content creation and how it will continue to evolve in the coming years.",
  content_type: :blog,
  date_published: ~D[2025-03-20],
  length: 1500, # 1500 words
  preview_length: 200, # 200-word preview
  file_url: "https://example.com/blogs/future_content.html",
  preview_url: "https://example.com/blogs/future_content_preview.html",
  price_default: Decimal.new("2.00")
}
|> Repo.insert!()

Repo.insert_all("content_groups_content_pieces", [%{
  content_group_id: group.id,
  content_piece_id: blog.id,
  inserted_at: DateTime.utc_now(),
  updated_at: DateTime.utc_now()
}])

# Tiqit Types for Blog Post
%TiqitType{
  content_piece_id: blog.id,
  name: "24-hour access",
  duration_hours: 24,
  price: Decimal.new("1.00"),
  active: true
}
|> Repo.insert!()

%TiqitType{
  content_piece_id: blog.id,
  name: "Permanent access",
  duration_hours: nil,
  price: Decimal.new("1.75"),
  active: true
}
|> Repo.insert!()

group = %ContentGroup{
  title: "Rick Astley",
  description: "The Greatest Hits",
  creator_id: creator.id
}
|> Repo.insert!()


[
"Never gonna give you up",
"Never gonna let you down",
"Never gonna make you cry",
"Never gonna say goodbye"
] |> Enum.each(fn title ->
  song = %ContentPiece{
    creator: creator,
    title: title,
    content_type: :song,
    date_published: Date.utc_today(),
    length: 600,
    preview_length: 200,
    file_url: "https://example.com/astley",
    preview_url: "https://example.com/astley-preview",
  }
  |> Repo.insert!()

  %TiqitType{
    content_piece_id: song.id,
    name: "Rent (24 hours)",
    duration_hours: 24,
    price: Decimal.new("0.49"),
    active: true
  }
  |> Repo.insert!()

  %TiqitType{
    content_piece_id: song.id,
    name: "Purchase",
    duration_hours: nil,
    price: Decimal.new("0.99"),
    active: true
  }
  |> Repo.insert!()

  Repo.insert_all("content_groups_content_pieces", [%{
    content_group_id: group.id,
    content_piece_id: song.id,
    inserted_at: DateTime.utc_now(),
    updated_at: DateTime.utc_now()
  }])
end)

IO.puts "Example content, tiqit types, and content group seeded successfully!"
