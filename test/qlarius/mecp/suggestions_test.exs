defmodule Qlarius.MeCP.SuggestionsTest do
  use Qlarius.DataCase, async: true

  import Qlarius.MeCPFixtures

  alias Qlarius.MeCP.{AccessLog, Grants, Suggestions}
  alias Qlarius.YouData.Surveys.SurveyQuestion

  # Suggestions render as survey questions, so suggestible traits need one.
  defp make_askable_question!(trait) do
    Repo.insert!(%SurveyQuestion{
      text: "Question about #{trait.trait_name}?",
      trait_id: trait.id,
      # Legacy bytea column holding ASCII "1" for active.
      active: "1",
      display_order: 1,
      added_by: 0,
      modified_by: 0
    })
  end

  defp make_askable!(trait) do
    make_askable_question!(trait)
    trait
  end

  defp seed_with_gap! do
    ctx = seed!(%{tier: 2, scope: %{}})

    gap =
      insert_trait!(ctx.lifestyle, "Pet Ownership #{System.unique_integer([:positive])}")
      |> make_askable!()

    Map.put(ctx, :gap, gap)
  end

  describe "create_suggestion/4" do
    test "queues a pending suggestion and logs one suggestion event" do
      ctx = seed_with_gap!()

      assert {:ok, suggestion} =
               Suggestions.create_suggestion(ctx.grant, ctx.gap.id, %{
                 proposed_values: ["Dog"],
                 reason: "User mentioned wanting to learn to knit with their dog nearby."
               })

      assert suggestion.status == "pending"
      assert suggestion.me_file_id == ctx.me_file.id
      assert suggestion.proposed_values == ["Dog"]

      [event] = AccessLog.list_events_for_grant(ctx.grant.id)
      assert event.kind == "suggestion"
      assert event.response_shape["form"] == "suggest_tag"
    end

    test "resolves trait names and rejects traits without survey questions" do
      ctx = seed_with_gap!()

      assert {:ok, _} = Suggestions.create_suggestion(ctx.grant, ctx.gap.trait_name, %{})

      # Housing (from the base seed) has no survey question.
      assert {:error, :not_askable} =
               Suggestions.create_suggestion(ctx.grant, ctx.housing.id, %{})

      assert {:error, :unknown_trait} =
               Suggestions.create_suggestion(ctx.grant, 999_999_999, %{})
    end

    test "suggesting costs no disclosure budget" do
      ctx = seed_with_gap!()
      capped = %{ctx.grant | budget: %{"period" => "day", "max" => 0}}

      assert {:ok, _} = Suggestions.create_suggestion(capped, ctx.gap.id, %{})
    end

    test "dedupes against pending and recently dismissed; caps pending per grant" do
      ctx = seed_with_gap!()

      assert {:ok, suggestion} = Suggestions.create_suggestion(ctx.grant, ctx.gap.id, %{})
      assert {:ok, :already_suggested} = Suggestions.create_suggestion(ctx.grant, ctx.gap.id, %{})

      # Dismissal starts a cooldown rather than reopening the door.
      :ok = Suggestions.dismiss(suggestion.id, ctx.me_file.id)
      assert {:ok, :already_suggested} = Suggestions.create_suggestion(ctx.grant, ctx.gap.id, %{})

      # Cap: fill to the limit with distinct askable traits.
      for i <- 1..(Suggestions.max_pending_per_grant() - 0) do
        trait = insert_trait!(ctx.lifestyle, "Filler #{i}-#{System.unique_integer()}")
        make_askable!(trait)
        Suggestions.create_suggestion(ctx.grant, trait.id, %{})
      end

      overflow = make_askable!(insert_trait!(ctx.lifestyle, "Overflow"))

      assert {:error, :suggestion_limit_reached} =
               Suggestions.create_suggestion(ctx.grant, overflow.id, %{})
    end

    test "scope containment and revoked grants refuse" do
      ctx = seed_with_gap!()
      scoped = %{ctx.grant | scope: %{"category_ids" => [ctx.demo.id]}}

      assert {:error, :out_of_scope} = Suggestions.create_suggestion(scoped, ctx.gap.id, %{})

      {:ok, revoked} = Grants.revoke_grant(ctx.grant)
      assert {:error, :revoked} = Suggestions.create_suggestion(revoked, ctx.gap.id, %{})
    end

    test "reason is truncated and cleared on dismissal" do
      ctx = seed_with_gap!()
      long = String.duplicate("a", 500)

      assert {:ok, suggestion} =
               Suggestions.create_suggestion(ctx.grant, ctx.gap.id, %{reason: long})

      assert String.length(suggestion.reason) == 280

      :ok = Suggestions.dismiss(suggestion.id, ctx.me_file.id)
      reloaded = Repo.get!(Qlarius.MeCP.Suggestions.TagSuggestion, suggestion.id)
      assert reloaded.status == "dismissed"
      assert reloaded.reason == nil
    end
  end

  describe "observed gaps (hybrid loop)" do
    alias Qlarius.MeCP.Oracle

    test "an empty ask_me answer queues an observed suggestion with one event total" do
      ctx = seed_with_gap!()

      assert {:ok, false} = Oracle.ask(ctx.grant, {:has_trait, ctx.gap.id})

      [suggestion] = Suggestions.list_pending_for_me_file(ctx.me_file.id)
      assert suggestion.source == "observed"
      assert suggestion.trait_id == ctx.gap.id
      assert suggestion.reason == nil

      # Exactly one event: the oracle read. Observation logs nothing extra.
      [event] = AccessLog.list_events_for_grant(ctx.grant.id)
      assert event.kind == "oracle"
    end

    test "an answered ask_me queues nothing" do
      ctx = seed_with_gap!()
      make_askable!(ctx.pets)

      assert {:ok, true} = Oracle.ask(ctx.grant, {:has_trait, ctx.pets.id})
      assert Suggestions.pending_count_for_me_file(ctx.me_file.id) == 0
    end

    test "search_traits queues the top gap once; repeats dedupe" do
      ctx = seed_with_gap!()
      insert_trait!(nil, "Dog", parent_trait_id: ctx.gap.id)

      assert {:ok, _} = Oracle.search_traits(ctx.grant, "do I own a dog?")
      assert {:ok, _} = Oracle.search_traits(ctx.grant, "dogs again")

      [suggestion] = Suggestions.list_pending_for_me_file(ctx.me_file.id)
      assert suggestion.source == "observed"
      assert suggestion.trait_id == ctx.gap.id

      # Two searches, two oracle events, still one suggestion.
      events = AccessLog.list_events_for_grant(ctx.grant.id)
      assert Enum.map(events, & &1.kind) |> Enum.sort() == ["oracle", "oracle"]
    end

    test "gaps on non-askable traits are skipped silently" do
      ctx = seed!(%{tier: 2, scope: %{}})
      empty = insert_trait!(ctx.demo, "Vehicle")

      assert {:ok, false} = Oracle.ask(ctx.grant, {:has_trait, empty.id})
      assert Suggestions.pending_count_for_me_file(ctx.me_file.id) == 0
    end
  end

  describe "lifecycle" do
    test "answering the trait accepts pending suggestions" do
      ctx = seed_with_gap!()
      {:ok, suggestion} = Suggestions.create_suggestion(ctx.grant, ctx.gap.id, %{})

      assert Suggestions.pending_count_for_me_file(ctx.me_file.id) == 1
      assert 1 = Suggestions.accept_pending_for_trait(ctx.me_file.id, ctx.gap.id)

      reloaded = Repo.get!(Qlarius.MeCP.Suggestions.TagSuggestion, suggestion.id)
      assert reloaded.status == "accepted"
      assert Suggestions.pending_count_for_me_file(ctx.me_file.id) == 0
    end

    test "revoking a grant sweeps its pending suggestions" do
      ctx = seed_with_gap!()
      {:ok, _} = Suggestions.create_suggestion(ctx.grant, ctx.gap.id, %{})

      {:ok, _} = Grants.revoke_grant(ctx.grant)
      assert Suggestions.pending_count_for_me_file(ctx.me_file.id) == 0
    end

    test "answering through the normal tag write path resolves the suggestion" do
      ctx = seed_with_gap!()
      {:ok, _} = Suggestions.create_suggestion(ctx.grant, ctx.gap.id, %{})
      child = insert_trait!(nil, "Dog", parent_trait_id: ctx.gap.id)

      :ok =
        Qlarius.YouData.MeFiles.create_replace_mefile_tags(
          ctx.me_file.id,
          ctx.gap.id,
          [child.id],
          0
        )

      assert Suggestions.pending_count_for_me_file(ctx.me_file.id) == 0
    end

    test "suggested_surveys groups anchors by survey with progress and byline data" do
      ctx = seed_with_gap!()

      # A second gap trait in the same survey collapses into one entry.
      sibling =
        insert_trait!(ctx.lifestyle, "Ideal Vacation Activities #{System.unique_integer()}")

      sibling_question = make_askable_question!(sibling)
      gap_question = Repo.get_by!(Qlarius.YouData.Surveys.SurveyQuestion, trait_id: ctx.gap.id)

      survey =
        Repo.insert!(%Qlarius.YouData.Surveys.Survey{
          name: "Ideal Vacation/Getaway",
          active: true,
          created_by: 0,
          updated_by: 0
        })

      for {question, order} <- [{gap_question, 1}, {sibling_question, 2}] do
        Repo.insert!(%Qlarius.YouData.Surveys.SurveyQuestionSurvey{
          survey_question_id: question.id,
          survey_id: survey.id,
          display_order: order
        })
      end

      {:ok, _} = Suggestions.create_suggestion(ctx.grant, ctx.gap.id, %{})
      {:ok, _} = Suggestions.create_suggestion(ctx.grant, sibling.id, %{})

      assert [entry] = Suggestions.suggested_surveys_for_me_file(ctx.me_file.id)
      assert entry.survey.id == survey.id
      assert length(entry.suggestions) == 2
      assert entry.answered == 0
      assert entry.total == 2
      assert entry.latest.grant.mecp_client.name == "Test Client"

      # Group dismissal clears both anchors.
      ids = Enum.map(entry.suggestions, & &1.id)
      assert 2 = Suggestions.dismiss_many(ids, ctx.me_file.id)
      assert Suggestions.suggested_surveys_for_me_file(ctx.me_file.id) == []
    end

    test "anchors without a survey fall back to a trait-level entry" do
      ctx = seed_with_gap!()
      {:ok, _} = Suggestions.create_suggestion(ctx.grant, ctx.gap.id, %{})

      assert [entry] = Suggestions.suggested_surveys_for_me_file(ctx.me_file.id)
      assert entry.survey == nil
      assert entry.total == 1
      assert entry.latest.trait.trait_name == ctx.gap.trait_name
      refute entry.update?
    end

    test "suggestions on already-tagged traits queue and mark the entry as an update" do
      ctx = seed_with_gap!()
      pets_question = make_askable_question!(ctx.pets)
      gap_question = Repo.get_by!(SurveyQuestion, trait_id: ctx.gap.id)

      # Separate surveys so the tagged and untagged anchors group apart.
      for {name, question} <- [{"Pets", pets_question}, {"New Topics", gap_question}] do
        survey =
          Repo.insert!(%Qlarius.YouData.Surveys.Survey{
            name: name,
            active: true,
            created_by: 0,
            updated_by: 0
          })

        Repo.insert!(%Qlarius.YouData.Surveys.SurveyQuestionSurvey{
          survey_question_id: question.id,
          survey_id: survey.id,
          display_order: 1
        })
      end

      # Pets already carries the seeded "Dog" tag: this is the "user said
      # something newer in chat" case, not a gap fill.
      assert {:ok, suggestion} =
               Suggestions.create_suggestion(ctx.grant, ctx.pets.id, %{
                 proposed_values: ["Dog", "Bird"],
                 reason: "Owner mentioned they recently got a dog."
               })

      assert suggestion.status == "pending"

      {:ok, _} = Suggestions.create_suggestion(ctx.grant, ctx.gap.id, %{})

      entries = Suggestions.suggested_surveys_for_me_file(ctx.me_file.id)
      update_entry = Enum.find(entries, & &1.update?)
      gap_entry = Enum.find(entries, &(not &1.update?))

      assert update_entry.latest.trait_id == ctx.pets.id
      assert update_entry.latest.proposed_values == ["Dog", "Bird"]
      assert gap_entry.latest.trait_id == ctx.gap.id
    end

    test "child-trait tags mark the parent anchor's entry as an update" do
      ctx = seed_with_gap!()
      child = insert_trait!(nil, "Cat", parent_trait_id: ctx.gap.id)
      insert_tag!(ctx.me_file, child, "Cat")

      {:ok, _} = Suggestions.create_suggestion(ctx.grant, ctx.gap.id, %{})

      assert [entry] = Suggestions.suggested_surveys_for_me_file(ctx.me_file.id)
      assert entry.update?
    end

    test "list_pending_for_me_file preloads what the Builder needs" do
      ctx = seed_with_gap!()
      {:ok, _} = Suggestions.create_suggestion(ctx.grant, ctx.gap.id, %{reason: "why"})

      [suggestion] = Suggestions.list_pending_for_me_file(ctx.me_file.id)
      assert suggestion.trait.id == ctx.gap.id
      assert suggestion.trait.survey_question.text =~ "Question about"
      assert suggestion.grant.mecp_client.name == "Test Client"
    end
  end
end
