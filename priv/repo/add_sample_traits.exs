defmodule Qlarius.AddSampleTraits do
  alias Qlarius.Repo
  alias Qlarius.Traits.Trait
  alias Qlarius.Accounts.User

  def run do
    case Repo.transaction(fn ->
           # Create 100 sample traits
           traits = create_sample_traits()

           # Get all users
           users = Repo.all(User)

           # Assign 10-20 random traits to each user
           assign_traits_to_users(users, traits)

           :ok
         end) do
      {:ok, :ok} ->
        IO.puts(
          "✅ Successfully created 100 sample traits and assigned 10-20 random traits to each user"
        )

      {:error, reason} ->
        IO.puts("❌ Transaction failed: #{inspect(reason)}")
    end
  end

  defp create_sample_traits do
    # List of sample trait names for user profiling in advertising
    trait_names = [
      # Shopping Interests
      "Luxury Shopper",
      "Budget Conscious",
      "Online Shopper",
      "In-store Shopper",
      "Deal Seeker",
      "Brand Loyal",
      "Trend Follower",
      "Sustainable Shopper",
      "Impulse Buyer",
      "Researches Before Buying",
      "Discount Hunter",
      "Premium Buyer",
      "Seasonal Shopper",
      "Black Friday Enthusiast",
      "Rewards Member",
      "Reviews Products",
      "Gift Giver",
      "Subscription User",
      "Local Business Supporter",
      "Bulk Buyer",

      # Lifestyle
      "Health Conscious",
      "Fitness Enthusiast",
      "Homeowner",
      "Renter",
      "Urban Dweller",
      "Suburban Resident",
      "Rural Resident",
      "Eco-Friendly",
      "Pet Owner",
      "Parent",
      "Expecting Parent",
      "Empty Nester",
      "Retiree",
      "Student",
      "Young Professional",
      "Remote Worker",
      "Commuter",
      "Night Owl",
      "Early Riser",
      "Weekend Warrior",

      # Entertainment
      "Movie Buff",
      "TV Binger",
      "Music Lover",
      "Gamer",
      "Sports Fan",
      "Concert Goer",
      "Theater Attendee",
      "Podcast Listener",
      "Book Reader",
      "Audiobook Listener",
      "Festival Attendee",
      "Museum Visitor",
      "Social Media Active",
      "News Follower",
      "Celebrity Fan",
      "Reality TV Watcher",
      "Comedy Fan",
      "Drama Enthusiast",
      "Sci-Fi Enthusiast",
      "Fantasy Enthusiast",

      # Travel & Dining
      "Frequent Traveler",
      "Domestic Traveler",
      "International Explorer",
      "Weekend Getaway",
      "Luxury Traveler",
      "Budget Traveler",
      "Beach Lover",
      "Mountain Enthusiast",
      "Foodie",
      "Fine Dining",
      "Fast Food Consumer",
      "Organic Eater",
      "Vegetarian",
      "Vegan",
      "Coffee Lover",
      "Wine Enthusiast",
      "Craft Beer Fan",
      "Home Cook",
      "Restaurant Regular",
      "Food Delivery User",

      # Hobbies & Activities
      "Gardener",
      "DIY Enthusiast",
      "Crafter",
      "Photographer",
      "Outdoor Enthusiast",
      "Hiker",
      "Cyclist",
      "Runner",
      "Yoga Practitioner",
      "Meditator",
      "Art Collector",
      "Volunteer",
      "Language Learner",
      "Musician",
      "Dancer",
      "Car Enthusiast",
      "Collector",
      "Home Decorator",
      "Fashion Enthusiast",
      "Beauty Enthusiast"
    ]

    # Insert traits and return them
    trait_names
    |> Enum.take(100)
    |> Enum.map(fn name ->
      %Trait{name: name} |> Repo.insert!()
    end)
  end

  defp assign_traits_to_users(users, traits) do
    Enum.each(users, fn user ->
      # Randomly select 10-20 traits
      num_traits = Enum.random(10..20)
      selected_traits = Enum.take_random(traits, num_traits)

      # Associate the traits with the user
      user
      |> Repo.preload(:traits)
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(:traits, selected_traits)
      |> Repo.update!()

      IO.puts("Assigned #{num_traits} traits to user: #{user.email}")
    end)
  end
end

# Run the script
Qlarius.AddSampleTraits.run()
