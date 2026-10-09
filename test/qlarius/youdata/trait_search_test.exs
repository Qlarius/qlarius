defmodule Qlarius.YouData.TraitSearchTest do
  use Qlarius.DataCase, async: true

  import Qlarius.MeCPFixtures

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
    assert [%{trait_id: id, matched_values: ["Pottery"], score: 2} | _] = rank("pottery")
    assert id == ctx.crafts.id
  end

  test "search terms match like names, on children and parents", ctx do
    with_terms!(ctx.pottery, ["ceramics", "wheel throwing"])
    with_terms!(ctx.crafts, ["crafting"])

    assert [%{trait_id: id, matched_values: ["Pottery"]} | _] = rank("ceramics")
    assert id == ctx.crafts.id
    assert [%{trait_id: ^id, matched_values: []} | _] = rank("crafting")
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

  test "match_values sorts chat words into child traits and leftovers", ctx do
    with_terms!(ctx.pottery, ["clay"])
    children = Repo.all(from t in Trait, where: t.parent_trait_id == ^ctx.crafts.id)

    {matched, unmatched} = TraitSearch.match_values(children, ["Clay", "paintings", "Origami"])

    assert Enum.map(matched, & &1.trait_name) == ["Painting", "Pottery"]
    assert unmatched == ["Origami"]
  end

  test "tokenize drops short words and adds a naive singular" do
    assert {:ok, ["dogs", "dog"]} = TraitSearch.tokenize("a dogs")
    assert {:error, :empty_query} = TraitSearch.tokenize("to")
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
