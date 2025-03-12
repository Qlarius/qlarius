alias Qlarius.Repo
alias Qlarius.Accounts.User
alias Qlarius.Traits.{Trait, UserTag}
import Ecto.Query

# Get the user
user = Repo.get_by!(User, email: "test@qlarius.com")

# Get all traits with their values preloaded
traits =
  Trait
  |> where([t], t.active == true)
  |> where([t], t.input_type in [:radios, :select, :checkboxes])
  |> preload(:values)
  |> Repo.all()

for trait <- traits do
  case trait.input_type do
    :text ->
      # Skip free text traits
      :noop

    :radios ->
      # For radio/select, pick one random value
      if trait.values != [] do
        random_value = Enum.random(trait.values)

        %UserTag{user_id: user.id, trait_value_id: random_value.id}
        |> Repo.insert!()
      end

    :select ->
      # Same as radios - pick one random value
      if trait.values != [] do
        random_value = Enum.random(trait.values)

        %UserTag{user_id: user.id, trait_value_id: random_value.id}
        |> Repo.insert!()
      end

    :checkboxes ->
      # For checkboxes, pick 1 or more random values
      if trait.values != [] do
        # Randomly select between 1 and all values
        num_selections = Enum.random(1..length(trait.values))

        trait.values
        |> Enum.shuffle()
        |> Enum.take(num_selections)
        |> Enum.each(fn value ->
          Repo.insert!(%UserTag{user_id: user.id, trait_value_id: value.id})
        end)
      end
  end
end

IO.puts("Finished assigning random trait values to user #{user.email}")
