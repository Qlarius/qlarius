defmodule Qlarius.YouData.TraitSearchTest do
  use Qlarius.DataCase, async: true

  import Qlarius.MeCPFixtures

  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.YouData.TraitSearch
  alias Qlarius.YouData.Traits.Trait

  defp with_terms!(trait, terms) do
    trait |> Ecto.Changeset.change(search_terms: terms) |> Repo.update!()
  end

  setup do
    hobbies = insert_category!("Hobbies")
    crafts = insert_trait!(hobbies, "Arts and Crafts #{System.unique_integer([:positive])}")
    painting = insert_trait!(nil, "Painting", parent_trait_id: crafts.id, display_order: 1)
    pottery = insert_trait!(nil, "Pottery", parent_trait_id: crafts.id, display_order: 2)

    %{hobbies: hobbies, crafts: crafts, painting: painting, pottery: pottery}
  end

  defp rank(query, opts \\ []) do
    {:ok, tokens} = TraitSearch.tokenize(query)
    TraitSearch.rank(tokens, opts)
  end

  test "a child trait's name finds its parent and is reported as the matched value", ctx do
    assert [%{trait_id: id, matched_values: ["Pottery"], matches: [match]} | _] =
             rank("pottery")

    assert id == ctx.crafts.id
    assert match.tier == "exact"
    assert match.field == "name"
    assert match.text == "Pottery"
  end

  test "search terms match like names, on children and parents", ctx do
    with_terms!(ctx.pottery, ["ceramics", "wheel throwing"])
    with_terms!(ctx.crafts, ["crafting"])

    assert [%{trait_id: id, matched_values: ["Pottery"]} | _] = rank("ceramics")
    assert id == ctx.crafts.id
    assert [%{trait_id: ^id, matched_values: []} | _] = rank("crafting")
  end

  test "a topic-name hit is the reported match when a value hits the same word", ctx do
    token = "zedqua#{System.unique_integer([:positive])}"
    parent = insert_trait!(ctx.hobbies, "Topic #{token}")
    insert_trait!(nil, "Value #{token}", parent_trait_id: parent.id)

    hit = rank(token) |> Enum.find(&(&1.trait_id == parent.id))

    assert [%{field: "name", text: text, tier: "word"}] = hit.matches
    assert text == parent.trait_name
    assert hit.matched_values == ["Value #{token}"]
  end

  test "a category-only hit finds the trait but names no matched values", ctx do
    crafts = rank(ctx.hobbies.name) |> Enum.find(&(&1.trait_id == ctx.crafts.id))
    assert crafts.matched_values == []
  end

  test "surveyed_only leaves out traits in no active survey", ctx do
    assert rank("pottery", surveyed_only: true) |> Enum.all?(&(&1.trait_id != ctx.crafts.id))

    survey_trait!(ctx.crafts)
    assert [%{trait_id: id} | _] = rank("pottery", surveyed_only: true)
    assert id == ctx.crafts.id
  end

  test "a parent on an active survey is searchable with its catalog flag off", ctx do
    token = "xyloshoe#{System.unique_integer([:positive])}"

    parent =
      insert_trait!(ctx.hobbies, "Size #{token}")
      |> Ecto.Changeset.change(is_active: false)
      |> Repo.update!()

    kept = insert_trait!(nil, "Wide #{token}", parent_trait_id: parent.id)

    retired =
      insert_trait!(nil, "Retired #{token}", parent_trait_id: parent.id)
      |> Ecto.Changeset.change(is_active: false)
      |> Repo.update!()

    assert rank(token, surveyed_only: true) == []
    refute Enum.any?(rank(token), &(&1.trait_id == parent.id))

    survey_trait!(parent)

    assert [%{trait_id: id, matched_values: values}] = rank(token, surveyed_only: true)
    assert id == parent.id
    assert values == [kept.trait_name]
    refute retired.trait_name in values
    refute Enum.any?(rank(token), &(&1.trait_id == parent.id))
  end

  test "match_values sorts chat words into child traits and leftovers", ctx do
    with_terms!(ctx.pottery, ["clay"])
    children = Repo.all(from t in Trait, where: t.parent_trait_id == ^ctx.crafts.id)

    {matched, unmatched} = TraitSearch.match_values(children, ["Clay", "paintings", "Origami"])

    assert Enum.map(matched, & &1.trait_name) == ["Painting", "Pottery"]
    assert unmatched == ["Origami"]
  end

  test "tokenize drops short words, keeps numbers, and singularizes ies" do
    assert {:ok, ["dogs", "dog"]} = TraitSearch.tokenize("a dogs")
    assert {:error, :empty_query} = TraitSearch.tokenize("to")
    assert {:ok, ["420"]} = TraitSearch.tokenize("420")
    assert {:ok, ["42"]} = TraitSearch.tokenize("42")

    assert {:ok, tokens} = TraitSearch.tokenize("dispensaries")
    assert "dispensary" in tokens
  end

  describe "ranking" do
    setup do
      category = insert_category!("Rank")
      %{category: category}
    end

    test "among names, a whole word beats a prefix, which beats a long substring",
         ctx do
      exact = insert_trait!(ctx.category, "Exact Holder") |> with_terms!(["brindle"])
      word = insert_trait!(ctx.category, "Has Brindle Coat")
      prefix = insert_trait!(ctx.category, "Brindlehound")
      substr = insert_trait!(ctx.category, "xxbrindle Extra")

      ids = rank("brindle") |> Enum.map(& &1.trait_id)

      assert order(ids, [word.id, prefix.id, substr.id, exact.id])
      refute rank("brin") |> Enum.any?(&(&1.trait_id == substr.id))
    end

    test "a prefix matches the start of a word and not the middle", ctx do
      vet = insert_trait!(ctx.category, "Veterinary Care")
      corvette = insert_trait!(ctx.category, "Corvette Club")

      ids = rank("vet") |> Enum.map(& &1.trait_id)
      assert vet.id in ids
      refute corvette.id in ids
    end

    test "a search term scores at least as high as the same match on a name", ctx do
      by_name = insert_trait!(ctx.category, "Quokka")
      by_term = insert_trait!(ctx.category, "Something Else") |> with_terms!(["quokka"])

      results = rank("quokka")
      name_hit = Enum.find(results, &(&1.trait_id == by_name.id))
      term_hit = Enum.find(results, &(&1.trait_id == by_term.id))

      assert name_hit.score == term_hit.score
      assert hd(term_hit.matches).field == "search_term"
    end

    test "short words do not match inside unrelated words", ctx do
      education = insert_trait!(ctx.category, "Education")
      location = insert_trait!(ctx.category, "Location")
      vacation = insert_trait!(ctx.category, "Vacation")
      pets = insert_trait!(ctx.category, "Pet Ownership")
      insert_trait!(nil, "Cat", parent_trait_id: pets.id)

      ids = rank("cat") |> Enum.map(& &1.trait_id)

      assert pets.id in ids
      refute education.id in ids
      refute location.id in ids
      refute vacation.id in ids
    end

    test "a topic name leads a child name, and both lead a search term", ctx do
      pets = insert_trait!(ctx.category, "Pet Ownership")
      insert_trait!(nil, "Cat", parent_trait_id: pets.id)
      insert_trait!(nil, "Kitten", parent_trait_id: pets.id)
      insert_trait!(nil, "Dog", parent_trait_id: pets.id)
      insert_trait!(nil, "Puppy", parent_trait_id: pets.id)
      hot_dogs = insert_trait!(ctx.category, "Hot Dogs")

      auto = insert_trait!(ctx.category, "Auto Ownership") |> with_terms!(["car"])
      cards = insert_trait!(ctx.category, "Cards")

      cannabis =
        insert_trait!(ctx.category, "Cannabis Use")
        |> with_terms!(["weed", "marijuana", "pot", "420"])

      pottery = insert_trait!(ctx.category, "Arts and Crafts")
      insert_trait!(nil, "Pottery", parent_trait_id: pottery.id)
      potatoes = insert_trait!(ctx.category, "Potatoes")

      religion = insert_trait!(ctx.category, "Religious Affiliation") |> with_terms!(["religion"])
      religious = insert_trait!(ctx.category, "Religion Class")

      nicotine =
        insert_trait!(ctx.category, "Nicotine Products") |> with_terms!(["smoke", "smoking"])

      children = insert_trait!(ctx.category, "Number of Children") |> with_terms!(["kids"])

      gender =
        insert_trait!(ctx.category, "Gender Identity") |> with_terms!(["trans", "transgender"])

      transmission = insert_trait!(ctx.category, "Transmission")
      income = insert_trait!(ctx.category, "Household Income") |> with_terms!(["money", "salary"])

      assert tops(rank("cat"), pets.id)
      assert tops(rank("kitten"), pets.id)
      assert tops(rank("dog"), pets.id)
      assert tops(rank("puppy"), pets.id)
      # "Hot Dogs" has the word in the topic name, so it leads the child "Dog".
      assert before?(rank("dog"), hot_dogs.id, pets.id)

      assert tops(rank("car"), auto.id)
      # "Cards" starts with the query, so the topic name leads the "car" term.
      assert before?(rank("car"), cards.id, auto.id)

      for query <- ~w(weed marijuana 420) do
        assert tops(rank(query), cannabis.id)
      end

      assert before?(rank("pot"), potatoes.id, pottery.id)
      assert before?(rank("pot"), pottery.id, cannabis.id)

      assert tops(rank("religion"), religion.id)
      assert before?(rank("religion"), religious.id, religion.id)

      assert tops(rank("smoke"), nicotine.id)
      assert tops(rank("smoking"), nicotine.id)
      assert tops(rank("kids"), children.id)

      assert tops(rank("trans"), gender.id)
      assert tops(rank("transgender"), gender.id)
      assert before?(rank("trans"), transmission.id, gender.id)

      assert tops(rank("money"), income.id)
      assert tops(rank("salary"), income.id)
    end

    test "ties break toward the parent with more tags, then by name", ctx do
      popular = insert_trait!(ctx.category, "Zzz Popular") |> with_terms!(["xylotag"])
      quiet = insert_trait!(ctx.category, "Aaa Quiet") |> with_terms!(["xylotag"])
      child = insert_trait!(nil, "Zzz Child", parent_trait_id: popular.id)
      insert_tag!(Repo.insert!(%MeFile{}), child, "yes")

      assert before?(rank("xylotag"), popular.id, quiet.id)

      alpha = insert_trait!(ctx.category, "Aaa Even") |> with_terms!(["xylotie"])
      zulu = insert_trait!(ctx.category, "Zzz Even") |> with_terms!(["xylotie"])
      assert before?(rank("xylotie"), alpha.id, zulu.id)
    end

    test "a category-only hit scores below a name hit and names no values", ctx do
      trait = insert_trait!(ctx.category, "Unrelated Topic")
      named = insert_trait!(ctx.category, ctx.category.name)

      [category_hit] = rank(ctx.category.name) |> Enum.filter(&(&1.trait_id == trait.id))
      name_hit = rank(ctx.category.name) |> Enum.find(&(&1.trait_id == named.id))

      assert category_hit.matched_values == []
      assert Enum.all?(category_hit.matches, &(&1.tier == "category"))
      assert name_hit.score > category_hit.score
    end
  end

  defp order(ids, expected) do
    indexes = Enum.map(expected, &Enum.find_index(ids, fn id -> id == &1 end))
    indexes == Enum.sort(indexes) and Enum.all?(indexes, &is_integer/1)
  end

  defp tops(results, trait_id) do
    results |> Enum.take(3) |> Enum.any?(&(&1.trait_id == trait_id))
  end

  defp before?(results, winner_id, loser_id) do
    ids = Enum.map(results, & &1.trait_id)
    win = Enum.find_index(ids, &(&1 == winner_id))
    lose = Enum.find_index(ids, &(&1 == loser_id))
    is_integer(win) and is_integer(lose) and win < lose
  end

  describe "Trait search_terms" do
    test "takes a comma-separated string or a list, cleaned and deduplicated" do
      changeset = Trait.changeset(%Trait{}, %{"search_terms" => " Ceramics, clay,,CLAY "})
      assert Ecto.Changeset.get_change(changeset, :search_terms) == ["ceramics", "clay"]

      changeset = Trait.changeset(%Trait{}, %{search_terms: ["Wheel Throwing", ""]})
      assert Ecto.Changeset.get_change(changeset, :search_terms) == ["wheel throwing"]
    end

    test "caps the number of terms" do
      terms = Enum.map(1..(Trait.max_search_terms() + 1), &"term #{&1}")
      changeset = Trait.changeset(%Trait{}, %{search_terms: terms})
      assert %{search_terms: [_ | _]} = errors_on(changeset)
    end
  end
end
