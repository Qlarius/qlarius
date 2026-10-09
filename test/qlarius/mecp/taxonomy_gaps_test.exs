defmodule Qlarius.MeCP.TaxonomyGapsTest do
  use Qlarius.DataCase, async: true

  import Qlarius.MeCPFixtures

  alias Qlarius.MeCP.{AccessLog, Oracle, Suggestions, TaxonomyGaps}
  alias Qlarius.MeCP.Suggestions.TagSuggestion
  alias Qlarius.MeCP.TaxonomyGaps.Gap
  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.YouData.Surveys.SurveyQuestion

  defp gaps, do: Repo.all(Gap)

  # Another person on the same assistant
  defp another_grant!(ctx) do
    insert_grant!(Repo.insert!(%MeFile{}), ctx.client, %{tier: 2, scope: %{}})
  end

  # An orphaned trait: a question, but in no active survey
  defp orphan_trait!(ctx) do
    orphan = insert_trait!(ctx.lifestyle, "Favorite Color")

    Repo.insert!(%SurveyQuestion{
      text: "Favorite color?",
      trait_id: orphan.id,
      active: "1",
      display_order: 1,
      added_by: 0,
      modified_by: 0
    })

    orphan
  end

  describe "normalize/1" do
    test "trims, collapses whitespace, scrubs contact details and keys on words" do
      assert {:ok, text, key} =
               TaxonomyGaps.normalize("  Anime   conventions? mail me a@b.co or 5551234567 ")

      assert text == "Anime conventions? mail me [email] or #"
      assert key == "anime conventions mail me email or"
      assert :error = TaxonomyGaps.normalize("  ?! ")
    end
  end

  describe "capture at the oracle's miss points" do
    test "a search with no match records the subject, de-identified" do
      ctx = seed!(%{tier: 2, scope: %{}})

      assert {:ok, []} = Oracle.search_traits(ctx.grant, "anime conventions")

      [gap] = gaps()
      assert gap.source == "search"
      assert gap.reason == "no_match"
      assert gap.subject == "anime conventions"
      assert gap.mecp_client_id == ctx.client.id

      # No link back to the person: a keyed hash, not the MeFile id
      refute gap.person_key == to_string(ctx.me_file.id)
      assert gap.person_key =~ ~r/^[0-9a-f]{64}$/
      refute Map.has_key?(Map.from_struct(gap), :me_file_id)
      refute Map.has_key?(Map.from_struct(gap), :mecp_grant_id)
    end

    test "a category-only hit is a weak match with the nearest trait; a trait hit is covered" do
      ctx = seed!(%{tier: 2, scope: %{}})
      category_word = ctx.lifestyle.name |> String.split() |> hd()

      {:ok, _} = Oracle.search_traits(ctx.grant, "#{category_word} podcasts")
      [gap] = gaps()
      assert gap.reason == "weak_match"
      assert gap.nearest_trait_id == ctx.pets.id

      {:ok, _} = Oracle.search_traits(ctx.grant, "pets")
      assert length(gaps()) == 1
    end

    test "ask_me by an unknown trait name records it; repeats in a day count once" do
      ctx = seed!(%{tier: 2, scope: %{}})

      assert {:error, :unknown_trait} = Oracle.ask(ctx.grant, {:has_trait, "Board Games"})
      assert {:error, :unknown_trait} = Oracle.ask(ctx.grant, {:has_trait, "board games"})

      assert [%Gap{source: "ask", reason: "unknown_trait", subject_key: "board games"}] = gaps()
    end

    test "suggest_tag for an unknown or orphaned trait records it, values but not the reason" do
      ctx = seed!(%{tier: 2, scope: %{}})

      assert {:error, :unknown_trait} =
               Suggestions.create_suggestion(ctx.grant, "Board Games", %{
                 proposed_values: ["Catan", "Chess"],
                 reason: "Mentioned game night with Pat on 2026-10-01"
               })

      orphan = orphan_trait!(ctx)

      assert {:error, :not_askable} =
               Suggestions.create_suggestion(ctx.grant, orphan.id, %{proposed_values: ["Blue"]})

      unknown = Enum.find(gaps(), &(&1.reason == "unknown_trait"))
      assert unknown.source == "suggest"
      assert unknown.proposed_values == ["Catan", "Chess"]
      refute inspect(gaps()) =~ "Pat"

      orphaned = Enum.find(gaps(), &(&1.reason == "not_askable"))
      assert orphaned.nearest_trait_id == orphan.id
      assert orphaned.subject == "Favorite Color"
    end
  end

  describe "admin read model" do
    test "a subject shows once enough different people raised it" do
      ctx = seed!(%{tier: 2, scope: %{}})
      grants = [ctx.grant, another_grant!(ctx)]

      for grant <- grants, do: Oracle.search_traits(grant, "anime conventions")

      assert TaxonomyGaps.list_subjects(30) == []
      assert TaxonomyGaps.hidden_subject_count(30) == 1

      Oracle.search_traits(another_grant!(ctx), "Anime conventions!")

      assert [subject] = TaxonomyGaps.list_subjects(30)
      assert subject.subject_key == "anime conventions"
      assert subject.people == 3
      assert subject.reasons == ["no_match"]
      assert TaxonomyGaps.hidden_subject_count(30) == 0
    end

    test "orphaned traits people still want are listed by trait" do
      ctx = seed!(%{tier: 2, scope: %{}})
      orphan = orphan_trait!(ctx)

      Suggestions.create_suggestion(ctx.grant, orphan.id, %{})

      assert [%{trait: "Favorite Color", people: 1}] = TaxonomyGaps.orphan_demand(30)
    end

    test "suggestions already filed on an orphaned trait count too, once per person" do
      ctx = seed!(%{tier: 2, scope: %{}})
      orphan = orphan_trait!(ctx)
      other = another_grant!(ctx)

      # Filed before the orphan rule, in any status
      for {grant, status} <- [{ctx.grant, "pending"}, {other, "dismissed"}] do
        Repo.insert!(%TagSuggestion{
          mecp_grant_id: grant.id,
          me_file_id: grant.me_file_id,
          trait_id: orphan.id,
          status: status,
          source: "observed"
        })
      end

      # The first person's assistant tries again and is refused
      assert {:error, :not_askable} = Suggestions.create_suggestion(ctx.grant, orphan.id, %{})

      assert [%{trait: "Favorite Color", people: 2, mentions: 3, last_seen: today}] =
               TaxonomyGaps.orphan_demand(30)

      assert today == Date.utc_today()

      # Back in an active survey, it's no longer orphaned
      survey_trait!(orphan)
      assert TaxonomyGaps.orphan_demand(30) == []
    end
  end

  test "access-log digests are keyed, not a plain hash of the request" do
    plain = :crypto.hash(:sha256, inspect({:search_traits, "dog"})) |> Base.encode16(case: :lower)
    keyed = AccessLog.digest({:search_traits, "dog"})

    assert keyed =~ ~r/^[0-9a-f]{64}$/
    refute keyed == plain
    assert keyed == AccessLog.digest({:search_traits, "dog"})
  end
end
