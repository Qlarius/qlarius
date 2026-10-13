defmodule Qlarius.YouData.TagQualityTest do
  use Qlarius.DataCase, async: true

  import Qlarius.MeCPFixtures

  alias Qlarius.Repo
  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.YouData.MeFiles
  alias Qlarius.YouData.MeFiles.QualityConfirmation
  alias Qlarius.YouData.QualityConfirmations
  alias Qlarius.YouData.TagQuality
  alias Qlarius.YouData.TraitIntegrity
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

    assert reason(tagged(parent, Enum.take(children, 4)), :count).text ==
             "2–3 works best. Keep more and confirm only if every choice is truly accurate."

    assert reason(tagged(parent, children), :count).text ==
             "2–3 works best. Keep these and confirm only if every choice is truly accurate."

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

    assert reason(tagged(maximum, max_children), :count).text ==
             "For best results, consider selecting fewer tag values."

    hard = parent!(category, "Hard", %{hard_max_tags: 1})
    hard_one = child!(hard, "Only")
    hard_two = child!(hard, "Extra")
    assert status(tagged(hard, [hard_one])) == :green

    assert reason(tagged(hard, [hard_one, hard_two]), :count).text ==
             "Too many selected. Advertisers will likely suspect and exclude. Try to stay at 1 or fewer tag values."
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

    assert reason(aged(full, 0), :unripe).status == :green
    assert reason(aged(full, 0), :unripe).text =~ "wait until this is ripe"
    assert status(aged(full, 0)) == :green
    assert reason(aged(full, 5), :ripen).status == :green
    assert status(aged(full, 5)) == :green
    assert status(aged(full, 20)) == :green
    assert reason(aged(full, 40), :stale).status == :yellow
    assert reason(aged(full, 100), :expired).status == :red

    stays_yellow =
      parent!(category, "Degree", %{stale_days: 30})

    assert reason(aged(stays_yellow, 400), :stale).status == :yellow
    refute reason(aged(stays_yellow, 400), :expired)

    ripens =
      parent!(category, "Zip", %{ripen_days: 7, stale_days: 30})

    assert reason(aged(ripens, 1), :ripen).status == :green
    assert status(aged(ripens, 1)) == :green
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

  test "a soft conflict is yellow and a note still replaces the sentence", %{category: category} do
    living = parent!(category, "Living Arrangements", %{})
    alone = child!(living, "Alone")
    household = parent!(category, "Household", %{})
    roommates = child!(household, "Roommates")

    {:ok, _} =
      TraitRelationships.create(%{
        "trait_id" => alone.id,
        "related_trait_id" => roommates.id,
        "kind" => "conflicts",
        "severity" => "soft"
      })

    entry = tagged_pair(living, [alone], [roommates])
    assert reason(entry, :conflict).status == :yellow

    assert reason(entry, :conflict).text ==
             "Alone (Living Arrangements) is unusual with Roommates. Keep both if accurate."

    noted = parent!(category, "Noted", %{})
    left = child!(noted, "Left")
    other = parent!(category, "Other", %{})
    right = child!(other, "Right")

    {:ok, _} =
      TraitRelationships.create(%{
        "trait_id" => left.id,
        "related_trait_id" => right.id,
        "kind" => "conflicts",
        "severity" => "soft",
        "note" => "Keep the stored note"
      })

    assert reason(tagged_pair(noted, [left], [right]), :conflict).text == "Keep the stored note"

    frequency = parent!(category, "Nicotine Frequency", %{})
    never = child!(frequency, "Never")
    products = parent!(category, "Nicotine Products", %{})
    pouches = child!(products, "Pouches")

    {:ok, _} =
      TraitRelationships.create(%{
        "trait_id" => never.id,
        "related_trait_id" => pouches.id,
        "kind" => "conflicts",
        "note" =>
          "\"Never\" (Nicotine Frequency) can't be combined with \"Pouches\" (Nicotine Products)."
      })

    assert reason(tagged_pair(products, [pouches], [never]), :conflict).text ==
             "\"Never\" (Nicotine Frequency) combined with \"Pouches\" (Nicotine Products) does not make sense."
  end

  test "confirming a conflict or a wide count turns it green until a save or it goes stale", %{
    category: category
  } do
    living = parent!(category, "Living", %{stale_days: 30})
    alone = child!(living, "Alone")
    household = parent!(category, "Home", %{stale_days: 10})
    roommates = child!(household, "Roommates")

    {:ok, relationship} =
      TraitRelationships.create(%{
        "trait_id" => alone.id,
        "related_trait_id" => roommates.id,
        "kind" => "conflicts"
      })

    me_file = me_file!([alone, roommates])
    assert QualityConfirmations.confirm(me_file.id, "conflict", relationship.id) == :ok

    held = TagQuality.for_me_file(me_file.id, @now)[living.id]
    assert held.status == :green
    assert reason(held, :confirmed).text == "Conflicts with Roommates"
    assert %DateTime{} = reason(held, :confirmed).confirmed_at
    assert reason(held, :confirmed).withdraw_kind == "conflict"
    assert reason(held, :confirmed).withdraw_ids == [relationship.id]
    refute reason(held, :conflict)

    assert QualityConfirmations.withdraw(me_file.id, "conflict", relationship.id) == :ok
    assert reason(TagQuality.for_me_file(me_file.id, @now)[living.id], :conflict).status == :red

    assert QualityConfirmations.confirm(me_file.id, "conflict", relationship.id) == :ok
    :ok = MeFiles.create_replace_mefile_tags(me_file.id, living.id, [alone.id], 0)
    saved = TagQuality.for_me_file(me_file.id, @now)[living.id]
    assert reason(saved, :conflict).status == :red

    hobbies =
      parent!(category, "Wide", %{ideal_max_tags: 1, hard_max_tags: 3, stale_days: 30})

    first = child!(hobbies, "One")
    second = child!(hobbies, "Two")
    wide = me_file!([first, second])
    assert reason(TagQuality.for_me_file(wide.id, @now)[hobbies.id], :count).confirmable
    assert QualityConfirmations.confirm(wide.id, "count", hobbies.id) == :ok
    confirmed = TagQuality.for_me_file(wide.id, @now)[hobbies.id]
    assert confirmed.status == :green

    assert reason(confirmed, :confirmed).text ==
             "For best results, consider selecting fewer tag values."

    assert reason(confirmed, :confirmed).withdraw_kind == "count"
    refute reason(confirmed, :count)

    assert QualityConfirmations.withdraw(wide.id, "count", hobbies.id) == :ok
    assert reason(TagQuality.for_me_file(wide.id, @now)[hobbies.id], :count).status == :yellow

    assert QualityConfirmations.confirm(wide.id, "count", hobbies.id) == :ok
    :ok = MeFiles.create_replace_mefile_tags(wide.id, hobbies.id, [first.id, second.id], 0)
    assert reason(TagQuality.for_me_file(wide.id, @now)[hobbies.id], :count).status == :yellow

    thin = parent!(category, "Thin", %{ideal_min_tags: 2})
    only = child!(thin, "Only")
    refute Map.get(reason(tagged(thin, [only]), :count), :confirmable)

    stale_parent = parent!(category, "Stale pair", %{stale_days: 100})
    stale_child = child!(stale_parent, "Value")
    other_parent = parent!(category, "Stale other", %{stale_days: 10})
    other_child = child!(other_parent, "Other value")

    {:ok, stale_link} =
      TraitRelationships.create(%{
        "trait_id" => stale_child.id,
        "related_trait_id" => other_child.id,
        "kind" => "conflicts",
        "severity" => "soft"
      })

    stale_file = me_file!([stale_child, other_child])
    assert QualityConfirmations.confirm(stale_file.id, "conflict", stale_link.id) == :ok

    QualityConfirmation
    |> Repo.get_by!(me_file_id: stale_file.id, trait_relationship_id: stale_link.id)
    |> Ecto.Changeset.change(
      confirmed_at: DateTime.add(@now, -20, :day) |> DateTime.truncate(:second)
    )
    |> Repo.update!()

    expired = TagQuality.for_me_file(stale_file.id, @now)[stale_parent.id]
    assert reason(expired, :conflict).status == :yellow

    refute Repo.get_by(QualityConfirmation,
             me_file_id: stale_file.id,
             trait_relationship_id: stale_link.id
           )
  end

  test "the integrity report counts a live confirmation and keeps an expired row", %{
    category: category
  } do
    parent = parent!(category, "Reported", %{stale_days: 10})
    child = child!(parent, "A")
    other = parent!(category, "Reported other", %{})
    other_child = child!(other, "B")

    {:ok, link} =
      TraitRelationships.create(%{
        "trait_id" => child.id,
        "related_trait_id" => other_child.id,
        "kind" => "conflicts",
        "severity" => "soft"
      })

    me_file = me_file!([child, other_child])
    assert QualityConfirmations.confirm(me_file.id, "conflict", link.id) == :ok

    assert Enum.any?(TraitIntegrity.report().confirmed_overrides, fn row ->
             row.relationship_id == link.id and row.count == 1 and row.severity == "soft"
           end)

    QualityConfirmation
    |> Repo.get_by!(me_file_id: me_file.id, trait_relationship_id: link.id)
    |> Ecto.Changeset.change(
      confirmed_at: DateTime.add(@now, -20, :day) |> DateTime.truncate(:second)
    )
    |> Repo.update!()

    refute Enum.any?(
             TraitIntegrity.report().confirmed_overrides,
             &(&1.relationship_id == link.id)
           )

    assert Repo.get_by(QualityConfirmation,
             me_file_id: me_file.id,
             trait_relationship_id: link.id
           )
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

  defp tagged_pair(parent, traits, others) do
    me_file = me_file!(traits ++ others)
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
