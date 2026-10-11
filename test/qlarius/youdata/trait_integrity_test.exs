defmodule Qlarius.YouData.TraitIntegrityTest do
  use Qlarius.DataCase, async: true

  import Qlarius.MeCPFixtures

  alias Qlarius.Repo
  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.YouData.Surveys.SurveyAnswer
  alias Qlarius.YouData.TraitIntegrity
  alias Qlarius.YouData.TraitRelationships

  test "each catalog check is reported, and a high skip rate is flagged" do
    category = insert_category!("Integrity")

    duplicate = parent!(category, "Duplicate skip")
    child!(duplicate, "Prefer not to say", %{is_skipped_tag: true, display_order: 2})
    lookalike = child!(duplicate, "Rather not say", %{display_order: 1})

    missing = parent!(category, "Needs a skip")

    many = parent!(category, "Two skips")
    child!(many, "Skip A", %{is_skipped_tag: true, display_order: 1})
    Repo.query!("DROP INDEX traits_one_active_skipped_tag_per_parent")
    child!(many, "Skip B", %{is_skipped_tag: true, display_order: 2})

    order = parent!(category, "Skip first")
    early = child!(order, "Prefer not to say", %{is_skipped_tag: true, display_order: 1})
    child!(order, "Later", %{display_order: 2})

    doubled = parent!(category, "Same order")
    child!(doubled, "One", %{display_order: 3})
    child!(doubled, "Two", %{display_order: 3})

    orphan = parent!(category, "No survey")
    surveyed = parent!(category, "On a survey") |> survey_trait!()
    child!(surveyed, "Answered", %{display_order: 1})
    child!(surveyed, "Prefer not to say", %{is_skipped_tag: true, display_order: 2})

    placeholder = parent!(category, "TEST hobby")

    blank_answer_parent = parent!(category, "Blank answer") |> survey_trait!()
    blank_child = child!(blank_answer_parent, "Untitled", %{display_order: 1})

    legacy = parent!(category, "Old wording") |> survey_trait!("Please click Add/Update<br>  now")

    named = parent!(category, "Pottery")
    named |> Ecto.Changeset.change(search_terms: ["pottery"]) |> Repo.update!()

    shared = for n <- 1..4, do: parent!(category, "Shared #{n}")

    Enum.each(shared, fn parent ->
      parent |> Ecto.Changeset.change(search_terms: ["sharedterm"]) |> Repo.update!()
    end)

    inactive = child!(parent!(category, "Retired parent"), "Gone", %{is_active: false})
    other = child!(parent!(category, "Still here"), "Stay")

    {:ok, _} =
      TraitRelationships.create(%{
        "trait_id" => inactive.id,
        "related_trait_id" => other.id,
        "kind" => "conflicts"
      })

    single = parent!(category, "One choice", %{input_type: "single_select"})
    left = child!(single, "Left")
    right = child!(single, "Right")

    {:ok, _} =
      TraitRelationships.create(%{
        "trait_id" => left.id,
        "related_trait_id" => right.id,
        "kind" => "conflicts"
      })

    {:ok, _} =
      TraitRelationships.create(%{
        "trait_id" => left.id,
        "related_trait_id" => single.id,
        "kind" => "conflicts"
      })

    {:ok, _} =
      TraitRelationships.create(%{
        "trait_id" => left.id,
        "related_trait_id" => right.id,
        "kind" => "requires"
      })

    broken =
      parent!(category, "Broken rules")
      |> Ecto.Changeset.change(%{ideal_max_tags: 5, hard_max_tags: 2})
      |> Repo.update!()

    skipped = parent!(category, "Often skipped") |> survey_trait!("How often?")
    answer = child!(skipped, "Often")
    skip = child!(skipped, "Prefer not to say", %{is_skipped_tag: true, display_order: 9})
    tag_file(answer, 0)
    old_skip = tag_file(skip, 40)
    tag_file(skip, 10)

    Repo.insert!(%SurveyAnswer{
      text: "   ",
      trait_id: blank_child.id,
      survey_question_id: Repo.preload(blank_answer_parent, :survey_question).survey_question.id,
      display_order: 1,
      added_by: 0,
      modified_by: 0
    })

    report = TraitIntegrity.report()
    issues = report.issues

    assert report.summary["duplicate_skip_name"] >= 1
    assert has?(issues, "duplicate_skip_name", lookalike.id)
    assert has?(issues, "missing_skip", missing.id)
    assert has?(issues, "multiple_skips", many.id)
    assert has?(issues, "skip_not_last", early.id)
    assert has?(issues, "duplicate_display_order", doubled.id)
    assert has?(issues, "orphan_parent", orphan.id)
    refute has?(issues, "orphan_parent", surveyed.id)
    assert has?(issues, "placeholder_name", placeholder.id)
    assert has?(issues, "missing_survey_answer", blank_child.id)
    assert has?(issues, "legacy_wording", legacy.id)
    assert has?(issues, "search_term_repeats_name", named.id)
    assert has?(issues, "search_term_on_many_parents", hd(shared).id)
    assert Enum.any?(issues, &(&1.check == "relationship_warning" and &1.detail =~ "inactive"))

    assert Enum.any?(
             issues,
             &(&1.check == "relationship_warning" and &1.detail =~ "single_select")
           )

    assert Enum.any?(issues, &(&1.check == "relationship_warning" and &1.detail =~ "own parent"))

    assert Enum.any?(
             issues,
             &(&1.check == "relationship_warning" and &1.detail =~ "both conflicts and requires")
           )

    assert has?(issues, "conflicting_rules", broken.id)
    assert has?(issues, "high_skip_rate", skipped.id)

    row = Enum.find(report.skip_monitoring, &(&1.parent_id == skipped.id))
    assert row.skip_count == 2
    assert row.answered_count == 3
    assert row.skip_rate > 0.15
    assert row.review_wording
    assert row.survey =~ "Survey"
    assert row.skips_30_days == 1
    assert row.skips_90_days == 2
    assert old_skip
  end

  defp has?(issues, check, id) do
    Enum.any?(issues, &(&1.check == check and &1.trait_id == id))
  end

  defp parent!(category, name, attrs \\ %{}) do
    category
    |> insert_trait!(name)
    |> Ecto.Changeset.change(Map.merge(%{input_type: "multi_select", is_active: true}, attrs))
    |> Repo.update!()
  end

  defp child!(parent, name, attrs \\ %{}) do
    nil
    |> insert_trait!(name, parent_trait_id: parent.id, display_order: attrs[:display_order] || 1)
    |> Ecto.Changeset.change(Map.delete(attrs, :display_order))
    |> Repo.update!()
  end

  defp tag_file(trait, days_ago) do
    me_file = Repo.insert!(%MeFile{})
    tag = insert_tag!(me_file, trait, trait.trait_name)

    added =
      Date.utc_today()
      |> Date.add(-days_ago)
      |> NaiveDateTime.new!(~T[08:00:00])

    tag |> Ecto.Changeset.change(added_date: added) |> Repo.update!()
    me_file
  end
end
