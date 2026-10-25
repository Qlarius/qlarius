# A first pass of directed `excludes` relationships for food and diet, so the
# target editor has suggestions to show in development.
#
#     mix run priv/repo/seeds/trait_excludes_seed.exs
#
# Each row reads "a target that includes {parent} → {answer} will (hard) or may
# (soft) want to keep out people with {parent} → {answer}". The reverse is never
# implied: a vegan restaurant may happily court burger eaters. Rows are looked
# up by name and skipped when a trait is missing or the row already exists, so
# the script is safe to re-run.

import Ecto.Query

alias Qlarius.Repo
alias Qlarius.YouData.TraitRelationships
alias Qlarius.YouData.Traits.Trait

find = fn parent_name, child_name ->
  Repo.one(
    from t in Trait,
      join: p in Trait,
      on: p.id == t.parent_trait_id,
      where: p.trait_name == ^parent_name and t.trait_name == ^child_name and t.is_active == true,
      limit: 1
  )
end

meats = fn name -> {"Meats Preferences", name} end
disliked = fn name -> {"Meats Disliked", name} end
diet = fn name -> {"Typical Daily Diet", name} end
fast_food = fn name -> {"Fast Food Preferences", name} end

vegan = diet.("Vegan")
vegetarian = diet.("Vegetarian")
pescatarian = diet.("Pescatarian")

land_meats = ["Steak (Beef)", "Chicken", "Pork", "Lamb", "Wild Game", "Veal"]
seafood = ["Fish", "Crab", "Lobster", "Shrimp", "Oysters", "Crawfish", "Sushi"]

rows =
  Enum.flat_map(land_meats, fn meat ->
    [
      {meats.(meat), vegan, "hard", "Vegans eat no meat"},
      {meats.(meat), vegetarian, "hard", "Vegetarians eat no meat"},
      {meats.(meat), pescatarian, "hard", "Pescatarians eat fish, not land meat"},
      {meats.(meat), disliked.(meat), "hard", "They told us they dislike it"}
    ]
  end) ++
    Enum.flat_map(seafood, fn item ->
      [
        {meats.(item), vegan, "hard", "Vegans eat no seafood"},
        {meats.(item), vegetarian, "hard", "Vegetarians eat no seafood"},
        {meats.(item), disliked.(item), "hard", "They told us they dislike it"}
      ]
    end) ++
    [
      {fast_food.("Hamburgers"), vegan, "hard", "Vegans eat no meat"},
      {fast_food.("Hamburgers"), vegetarian, "hard", "Vegetarians eat no meat"},
      {fast_food.("Hamburgers"), disliked.("Steak (Beef)"), "soft",
       "Some who dislike steak still eat burgers"},
      {fast_food.("Hot Dogs"), vegan, "hard", "Vegans eat no meat"},
      {fast_food.("Hot Dogs"), vegetarian, "hard", "Vegetarians eat no meat"},
      {fast_food.("Chicken"), vegan, "hard", "Vegans eat no meat"},
      {fast_food.("Chicken"), vegetarian, "hard", "Vegetarians eat no meat"},
      {fast_food.("Chicken"), disliked.("Chicken"), "hard", "They told us they dislike it"},
      {fast_food.("Pizza"), vegan, "soft", "Vegan pizza exists; most pizza is not"},
      {fast_food.("Tacos/Burritos"), vegan, "soft", "Vegan options exist; most are not"}
    ]

summary =
  Enum.reduce(rows, %{created: 0, exists: 0, missing: 0}, fn {from, to, severity, note}, acc ->
    {from_parent, from_name} = from
    {to_parent, to_name} = to

    case {find.(from_parent, from_name), find.(to_parent, to_name)} do
      {%Trait{} = subject, %Trait{} = object} ->
        attrs = %{
          "trait_id" => subject.id,
          "related_trait_id" => object.id,
          "kind" => "excludes",
          "severity" => severity,
          "note" => note
        }

        case TraitRelationships.create(attrs) do
          {:ok, _} ->
            IO.puts(
              "created  #{from_parent} → #{from_name} excludes #{to_parent} → #{to_name} (#{severity})"
            )

            Map.update!(acc, :created, &(&1 + 1))

          {:error, _changeset} ->
            Map.update!(acc, :exists, &(&1 + 1))
        end

      _ ->
        IO.puts("missing  #{from_parent} → #{from_name} or #{to_parent} → #{to_name}")
        Map.update!(acc, :missing, &(&1 + 1))
    end
  end)

IO.inspect(summary, label: "trait excludes seed")
