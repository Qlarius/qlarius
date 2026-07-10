defmodule Qlarius.MeCP.SuggestionsTest do
  use Qlarius.DataCase, async: true

  import Qlarius.MeCPFixtures

  alias Qlarius.MeCP.{AccessLog, Grants, Suggestions}
  alias Qlarius.YouData.Surveys.SurveyQuestion

  # Suggestions render as survey questions, so suggestible traits need one.
  defp make_askable!(trait) do
    Repo.insert!(%SurveyQuestion{
      text: "Question about #{trait.trait_name}?",
      trait_id: trait.id,
      # Legacy bytea column holding ASCII "1" for active.
      active: "1",
      display_order: 1,
      added_by: 0,
      modified_by: 0
    })

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
