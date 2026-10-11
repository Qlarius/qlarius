defmodule Qlarius.YouData.TagQualityTest do
  use Qlarius.DataCase, async: true

  import Qlarius.MeCPFixtures

  alias Qlarius.Repo
  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.YouData.TagQuality
  alias Qlarius.YouData.TraitRelationships

  @now ~U[2026-06-15 12:00:00Z]

  setup do
    %{category: insert_category!("Quality")}
  end

  test "count bands, including the hard maximum and a skip", %{category: category} do
    parent =
      parent!(category, "Hobbies", %{
        ideal_min_tags: 2,
        ideal_max_tags: 3,
        hard_max_tags: 4
      })

    children = for n <- 1..5, do: child!(parent, "Hobby #{n}")
    skip = child!(parent, "Prefer not to say", %{is_skipped_tag: true})

    assert status(tagged(parent, Enum.take(children, 2))) == :green
    assert status(tagged(parent, Enum.take(children, 3))) == :green
    assert reason(tagged(parent, Enum.take(children, 1)), :count).text == "Fewer than usual"
    assert reason(tagged(parent, Enum.take(children, 4)), :count).text == "More than usual"
    assert reason(tagged(parent, children), :count).status == :red

    skipped = tagged(parent, [skip])
    assert status(skipped) == :skipped
    refute reason(skipped, :count)

    with_skip = tagged(parent, [hd(children), skip])
    assert reason(with_skip, :count).text == "Fewer than usual"
  end

  test "a count rule can be only a minimum, only a maximum, or only a hard maximum", %{
    category: category
  } do
    minimum = parent!(category, "Minimum", %{ideal_min_tags: 2})
    min_child = child!(minimum, "One")
    assert reason(tagged(minimum, [min_child]), :count).status == :yellow

    maximum = parent!(category, "Maximum", %{ideal_max_tags: 1})
    max_children = [child!(maximum, "A"), child!(maximum, "B")]
    assert reason(tagged(maximum, max_children), :count).text == "More than usual"

    hard = parent!(category, "Hard", %{hard_max_tags: 1})
    hard_one = child!(hard, "Only")
    hard_two = child!(hard, "Extra")
    assert status(tagged(hard, [hard_one])) == :green
    assert reason(tagged(hard, [hard_one, hard_two]), :count).status == :red
  end

  test "freshness bands, including a null expiry and a null unripe threshold", %{
    category: category
  } do
    full =
      parent!(category, "Income", %{
        unripe_days: 2,
        ripen_days: 7,
        stale_days: 30,
        expired_days: 90
      })

    assert reason(aged(full, 0), :unripe).status == :red
    assert reason(aged(full, 5), :ripen).status == :yellow
    assert status(aged(full, 20)) == :green
    assert reason(aged(full, 40), :stale).status == :yellow
    assert reason(aged(full, 100), :expired).status == :red

    stays_yellow =
      parent!(category, "Degree", %{stale_days: 30})

    assert reason(aged(stays_yellow, 400), :stale).status == :yellow
    refute reason(aged(stays_yellow, 400), :expired)

    ripens =
      parent!(category, "Zip", %{ripen_days: 7, stale_days: 30})

    assert reason(aged(ripens, 1), :ripen).status == :yellow
    refute reason(aged(ripens, 1), :unripe)
  end

  test "a conflict lights both sides, and a requirement can mean any value of a parent", %{
    category: category
  } do
    children = parent!(category, "Children", %{})
    none = child!(children, "0")
    sons = parent!(category, "Sons", %{})
    one_son = child!(sons, "1")

    {:ok, _} =
      TraitRelationships.create(%{
        "trait_id" => none.id,
        "related_trait_id" => sons.id,
        "kind" => "conflicts",
        "note" => "You can't have 0 children and also have a son"
      })

    me_file = me_file!([none, one_son])
    quality = TagQuality.for_me_file(me_file.id, @now)

    assert reason(quality[children.id], :conflict).text =~ "can't have 0 children"
    assert reason(quality[sons.id], :conflict).status == :red

    golf = parent!(category, "Golf", %{})
    working = child!(golf, "Working on my game")
    activities = parent!(category, "Activities", %{})

    {:ok, _} =
      TraitRelationships.create(%{
        "trait_id" => working.id,
        "related_trait_id" => activities.id,
        "kind" => "requires"
      })

    missing = me_file!([working])

    assert reason(TagQuality.for_me_file(missing.id, @now)[golf.id], :requires).text =~
             "Activities"

    hiking = child!(activities, "Hiking")
    present = me_file!([working, hiking])
    present_quality = TagQuality.for_me_file(present.id, @now)
    refute reason(present_quality[golf.id], :requires)
    assert status(present_quality[activities.id]) == :green
  end

  test "a birthdate is always green" do
    me_file = Repo.insert!(%MeFile{date_of_birth: ~D[1990-01-01]})
    assert TagQuality.for_me_file(me_file.id, @now)[-1] == %{status: :green, reasons: []}

    blank = Repo.insert!(%MeFile{})
    refute Map.has_key?(TagQuality.for_me_file(blank.id, @now), -1)
  end

  test "the light takes the worst status, and a parent with no rules is green", %{
    category: category
  } do
    hobbies =
      parent!(category, "Padded", %{ideal_min_tags: 2, ideal_max_tags: 2, hard_max_tags: 3})

    only = child!(hobbies, "Only one")
    banned = parent!(category, "Banned", %{})
    banned_value = child!(banned, "Yes")

    {:ok, _} =
      TraitRelationships.create(%{
        "trait_id" => only.id,
        "related_trait_id" => banned_value.id,
        "kind" => "conflicts"
      })

    me_file = me_file!([only, banned_value])
    entry = TagQuality.for_me_file(me_file.id, @now)[hobbies.id]
    assert entry.status == :red
    assert Enum.map(entry.reasons, & &1.check) |> Enum.sort() == [:conflict, :count]

    plain = parent!(category, "Plain", %{})
    value = child!(plain, "Value")
    plain_file = me_file!([value])
    assert TagQuality.for_me_file(plain_file.id, @now)[plain.id] == %{status: :green, reasons: []}

    empty = parent!(category, "Empty", %{ideal_min_tags: 1, stale_days: 10})
    blank = Repo.insert!(%MeFile{})
    refute Map.has_key?(TagQuality.for_me_file(blank.id, @now), empty.id)
  end

  test "a skip is neutral, still ages, and does not satisfy or trigger a link", %{
    category: category
  } do
    parent = parent!(category, "Income", %{stale_days: 30})
    skip = child!(parent, "Prefer not to say", %{is_skipped_tag: true})
    stale = tagged_age(parent, [skip], 40)
    assert reason(stale, :stale).status == :yellow
    assert status(stale) == :yellow

    activities = parent!(category, "Activities", %{})
    activity_skip = child!(activities, "Rather not", %{is_skipped_tag: true})
    golf = parent!(category, "Golf", %{})
    working = child!(golf, "Working on my game")

    {:ok, _} =
      TraitRelationships.create(%{
        "trait_id" => working.id,
        "related_trait_id" => activities.id,
        "kind" => "requires"
      })

    unanswered = me_file!([working, activity_skip])
    assert reason(TagQuality.for_me_file(unanswered.id, @now)[golf.id], :requires)

    banned = parent!(category, "Banned", %{})
    banned_value = child!(banned, "Yes")

    {:ok, _} =
      TraitRelationships.create(%{
        "trait_id" => skip.id,
        "related_trait_id" => banned_value.id,
        "kind" => "conflicts"
      })

    quiet = me_file!([skip, banned_value])
    quiet_quality = TagQuality.for_me_file(quiet.id, @now)
    assert status(quiet_quality[parent.id]) == :skipped
    refute reason(quiet_quality[banned.id], :conflict)
  end

  test "an exclusive answer kept beside another answer is yellow", %{category: category} do
    parent = parent!(category, "Diet", %{})
    none = child!(parent, "None of these", %{is_exclusive: true})
    vegan = child!(parent, "Vegan")
    entry = tagged(parent, [none, vegan])

    assert status(entry) == :yellow
    assert reason(entry, :exclusive).text == "exclusive answer combined with other answers"
  end

  defp parent!(category, name, attrs) do
    category
    |> insert_trait!(name)
    |> Ecto.Changeset.change(Map.merge(%{input_type: "multi_select"}, attrs))
    |> Repo.update!()
  end

  defp child!(parent, name, attrs \\ %{}) do
    nil
    |> insert_trait!(name, parent_trait_id: parent.id)
    |> Ecto.Changeset.change(attrs)
    |> Repo.update!()
  end

  defp me_file!(traits) do
    me_file = Repo.insert!(%MeFile{})
    Enum.each(traits, &tag!(me_file, &1, 20))
    me_file
  end

  defp tagged(parent, traits) do
    me_file = me_file!(traits)
    TagQuality.for_me_file(me_file.id, @now)[parent.id]
  end

  defp tagged_age(parent, traits, days) do
    me_file = Repo.insert!(%MeFile{})
    Enum.each(traits, &tag!(me_file, &1, days))
    TagQuality.for_me_file(me_file.id, @now)[parent.id]
  end

  defp aged(parent, days) do
    value = child!(parent, "Value #{System.unique_integer([:positive])}")
    me_file = Repo.insert!(%MeFile{})
    tag!(me_file, value, days)
    TagQuality.for_me_file(me_file.id, @now)[parent.id]
  end

  defp tag!(me_file, trait, days_ago) do
    tag = insert_tag!(me_file, trait, trait.trait_name)

    added =
      @now
      |> DateTime.to_date()
      |> Date.add(-days_ago)
      |> NaiveDateTime.new!(~T[08:00:00])

    tag |> Ecto.Changeset.change(added_date: added) |> Repo.update!()
  end

  defp status(entry), do: entry.status

  defp reason(entry, check) do
    Enum.find(entry.reasons, &(&1.check == check))
  end
end
