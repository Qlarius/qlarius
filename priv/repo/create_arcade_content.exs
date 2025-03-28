alias Qlarius.Arcade.{Content, TicketType}
alias Qlarius.Repo

# Example Content 1: Video
video = %Content{
  title: "Introduction to Elixir",
  description: "Learn the fundamentals of Elixir programming in this comprehensive introduction. We'll cover functional programming concepts, pattern matching, the actor model with processes, and how to build concurrent applications. Perfect for developers coming from object-oriented languages who want to explore the power of Elixir.",
  content_type: "video",
  date_published: ~D[2025-03-01],
  length: 1200, # 20 minutes in seconds
  preview_length: 60, # 1 minute preview
  file_url: "https://example.com/videos/intro_elixir.mp4",
  preview_url: "https://example.com/videos/intro_elixir_preview.mp4",
  price_default: Decimal.new("5.00")
}
|> Repo.insert!()

# Ticket Types for Video
%TicketType{
  content_id: video.id,
  name: "1-hour access",
  duration_seconds: 3600,
  price: Decimal.new("2.00"),
  is_active: true
}
|> Repo.insert!()

%TicketType{
  content_id: video.id,
  name: "24-hour access",
  duration_seconds: 86_400,
  price: Decimal.new("4.50"),
  is_active: true
}
|> Repo.insert!()

# Example Content 2: Podcast
podcast = %Content{
  title: "Tech Talk: AI Innovations",
  description: "Join us as we dive into the latest advancements in artificial intelligence. We'll explore the latest trends in AI, including natural language processing, machine learning, and more. Perfect for tech enthusiasts who want to stay ahead of the curve.",
  content_type: "podcast",
  date_published: ~D[2025-03-15],
  length: 1800, # 30 minutes in seconds
  preview_length: 120, # 2 minute preview
  file_url: "https://example.com/podcasts/ai_innovations.mp3",
  preview_url: "https://example.com/podcasts/ai_innovations_preview.mp3",
  price_default: Decimal.new("3.00")
}
|> Repo.insert!()

# Ticket Types for Podcast
%TicketType{
  content_id: podcast.id,
  name: "1-hour access",
  duration_seconds: 3600,
  price: Decimal.new("1.50"),
  is_active: true
}
|> Repo.insert!()

%TicketType{
  content_id: podcast.id,
  name: "7-day access",
  duration_seconds: 604_800,
  price: Decimal.new("2.75"),
  is_active: true
}
|> Repo.insert!()

# Example Content 3: Blog Post
blog = %Content{
  title: "The Future of Content Creation",
  description: "In this blog post, we'll explore the latest trends in content creation, including the rise of AI-powered tools and the importance of user engagement. We'll also discuss the future of content creation and how it will continue to evolve in the coming years.",
  content_type: "blog",
  date_published: ~D[2025-03-20],
  length: 1500, # 1500 words
  preview_length: 200, # 200-word preview
  file_url: "https://example.com/blogs/future_content.html",
  preview_url: "https://example.com/blogs/future_content_preview.html",
  price_default: Decimal.new("2.00")
}
|> Repo.insert!()

# Ticket Types for Blog Post
%TicketType{
  content_id: blog.id,
  name: "24-hour access",
  duration_seconds: 86_400,
  price: Decimal.new("1.00"),
  is_active: true
}
|> Repo.insert!()

%TicketType{
  content_id: blog.id,
  name: "Permanent access",
  duration_seconds: 31_536_000, # 1 year, effectively permanent
  price: Decimal.new("1.75"),
  is_active: true
}
|> Repo.insert!()

IO.puts "Example content and ticket types seeded successfully!"
