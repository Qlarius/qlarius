defmodule Qlarius.Qai.EconomicsTest do
  use Qlarius.DataCase, async: true

  alias Qlarius.Qai.{Economics, Sessions}
  alias Qlarius.YouData.MeFiles.MeFile

  defp insert_me_file!, do: Repo.insert!(%MeFile{})

  defp assistant_turn!(session, usage, opts \\ []) do
    {:ok, draft} =
      Sessions.add_message(session, "assistant", "", model: Keyword.get(opts, :model, "claude-sonnet-4-6"))

    {:ok, message} = Sessions.finalize_message(draft, "reply", usage: usage)
    message
  end

  defp seed_traffic! do
    me_file = insert_me_file!()
    {:ok, session_a} = Sessions.create_session(me_file.id)
    {:ok, session_b} = Sessions.create_session(me_file.id)

    # Session A: two frontier turns, cache warm on the second.
    assistant_turn!(session_a, %{
      "input_tokens" => 1000,
      "output_tokens" => 400,
      "cache_creation_input_tokens" => 3000,
      "cache_read_input_tokens" => 0
    })

    assistant_turn!(session_a, %{
      "input_tokens" => 200,
      "output_tokens" => 300,
      "cache_creation_input_tokens" => 0,
      "cache_read_input_tokens" => 3000
    })

    # Session B: one cheap-tier turn and one stopped turn with no usage.
    assistant_turn!(session_b, %{"input_tokens" => 500, "output_tokens" => 100},
      model: "claude-haiku-4-5"
    )

    {:ok, draft} = Sessions.add_message(session_b, "assistant", "")
    {:ok, _} = Sessions.finalize_message(draft, "partial", stopped: true)

    %{me_file: me_file, session_a: session_a, session_b: session_b}
  end

  test "totals sum token classes, count distinct sessions, and separate unmeasured turns" do
    seed_traffic!()

    totals = Economics.totals(7)

    assert totals.turns == 4
    assert totals.unmeasured == 1
    assert totals.sessions == 2
    assert totals.me_files == 1
    assert totals.input == 1700
    assert totals.output == 800
    assert totals.cache_read == 3000
    assert totals.cache_write == 3000
  end

  test "cost prices token classes cache-aware and by tier" do
    # 1000 in + 3000 cache-write (1.25x) + 3000 cache-read (0.1x) at $3/MTok,
    # 700 out at $15/MTok.
    row = %{model: "claude-sonnet-4-6", input: 1000, output: 700, cache_read: 3000, cache_write: 3000}

    expected = (1000 + 3000 * 1.25 + 3000 * 0.1) / 1.0e6 * 3.0 + 700 / 1.0e6 * 15.0
    assert_in_delta Economics.cost(row), expected, 1.0e-10

    cheap = %{row | model: "claude-haiku-4-5"}
    cheap_expected = (1000 + 3000 * 1.25 + 3000 * 0.1) / 1.0e6 * 1.0 + 700 / 1.0e6 * 5.0
    assert_in_delta Economics.cost(cheap), cheap_expected, 1.0e-10

    # The caching win is measured against reads and writes repriced as input.
    assert Economics.uncached_cost(row) > Economics.cost(row)
  end

  test "model breakdown, daily series, and cache hit share reflect seeded traffic" do
    seed_traffic!()

    breakdown = Economics.model_breakdown(7)
    assert [%{model: "claude-sonnet-4-6", turns: 2}, %{model: "claude-haiku-4-5", turns: 1}] =
             breakdown

    assert [day] = Economics.daily_series(7)
    assert day.turns == 4
    assert day.sessions == 2

    # 3000 cache reads out of 1700 + 3000 + 3000 context tokens.
    assert_in_delta Economics.cache_hit_share(Economics.totals(7)), 3000 / 7700, 0.001
  end

  test "session cost distribution prices per session and orders percentiles" do
    seed_traffic!()

    distribution = Economics.session_cost_distribution(7)

    assert distribution.count == 2
    assert distribution.p50 <= distribution.p90
    assert distribution.p90 == distribution.max
    assert distribution.max > 0
  end

  test "empty windows return zeroes, not nils" do
    totals = Economics.totals(7)
    assert totals.turns == 0
    assert totals.input == 0

    assert Economics.daily_series(7) == []
    assert Economics.session_cost_distribution(7) == %{count: 0, p50: 0.0, p90: 0.0, max: 0.0}
    assert Economics.cache_hit_share(totals) == 0.0
  end

  test "suggestion conversion groups by client with acceptance rate" do
    import Qlarius.MeCPFixtures
    alias Qlarius.MeCP.Suggestions

    ctx = seed!(%{tier: 2, scope: %{}})
    trait = insert_trait!(ctx.lifestyle, "Pet Ownership #{System.unique_integer([:positive])}")

    Repo.insert!(%Qlarius.YouData.Surveys.SurveyQuestion{
      text: "Pets?",
      trait_id: trait.id,
      active: "1",
      display_order: 1,
      added_by: 0,
      modified_by: 0
    })

    {:ok, suggestion} = Suggestions.create_suggestion(ctx.grant, trait.id, %{})
    :ok = Suggestions.dismiss(suggestion.id, ctx.me_file.id)

    assert [row] = Economics.suggestion_conversion(7)
    assert row.client == "Test Client"
    assert row.filed == 1
    assert row.dismissed == 1
    assert row.acceptance_rate == 0.0
  end
end
