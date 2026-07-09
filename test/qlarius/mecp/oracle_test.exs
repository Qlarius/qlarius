defmodule Qlarius.MeCP.OracleTest do
  use Qlarius.DataCase, async: true

  import Qlarius.MeCPFixtures

  alias Qlarius.MeCP
  alias Qlarius.MeCP.{AccessLog, Grants, Oracle}

  defp event_count(grant), do: length(AccessLog.list_events_for_grant(grant.id))

  # --- question forms ---------------------------------------------------------

  describe "ask/3 question forms" do
    setup do
      seed!(%{scope: %{}, tier: 2})
    end

    test "has_trait answers true for held and false for unheld traits", ctx do
      empty = insert_trait!(ctx.demo, "Vehicle")

      assert {:ok, true} = Oracle.ask(ctx.grant, {:has_trait, ctx.housing.id})
      assert {:ok, false} = Oracle.ask(ctx.grant, {:has_trait, empty.id})
    end

    test "trait_values returns values with confirmation month/year", ctx do
      assert {:ok, [%{value: "Renter", confirmed: confirmed}]} =
               Oracle.ask(ctx.grant, {:trait_values, ctx.housing.id})

      assert confirmed =~ ~r/^[A-Z][a-z]{2} \d{4}$/
    end

    test "value_in matches case-insensitively", ctx do
      assert {:ok, true} = Oracle.ask(ctx.grant, {:value_in, ctx.pets.id, ["dog", "cat"]})
      assert {:ok, false} = Oracle.ask(ctx.grant, {:value_in, ctx.pets.id, ["cat"]})
    end

    test "bucket returns the matching label only", ctx do
      buckets = [{"no_pets", ["None"]}, {"has_pets", ["Dog", "Cat"]}]
      assert {:ok, "has_pets"} = Oracle.ask(ctx.grant, {:bucket, ctx.pets.id, buckets})
      assert {:ok, nil} = Oracle.ask(ctx.grant, {:bucket, ctx.pets.id, [{"birds", ["Parrot"]}]})
    end

    test "a child trait id resolves to its effective parent trait", ctx do
      child = insert_trait!(nil, "Downtown", parent_trait_id: ctx.housing.id)
      insert_tag!(ctx.me_file, child, nil)

      assert {:ok, values} = Oracle.ask(ctx.grant, {:trait_values, child.id})
      assert Enum.map(values, & &1.value) |> Enum.sort() == ["Downtown", "Renter"]
    end

    test "unknown trait and malformed questions refuse", ctx do
      assert {:error, :unknown_trait} = Oracle.ask(ctx.grant, {:has_trait, 999_999_999})
      assert {:error, :unsupported_question} = Oracle.ask(ctx.grant, {:tell_me_everything})
    end
  end

  # --- grant checks -----------------------------------------------------------

  describe "ask/3 grant checks" do
    test "scope containment: out-of-scope trait refuses and logs nothing" do
      ctx = seed!(%{tier: 2, scope: %{"category_ids" => []}})
      grant = %{ctx.grant | scope: %{"category_ids" => [ctx.demo.id]}}

      assert {:ok, true} = Oracle.ask(grant, {:has_trait, ctx.housing.id})
      assert {:error, :out_of_scope} = Oracle.ask(grant, {:has_trait, ctx.pets.id})
      assert event_count(grant) == 1
    end

    test "oracle requires tier 2" do
      ctx = seed!(%{tier: 1, scope: %{}})
      assert {:error, :insufficient_tier} = Oracle.ask(ctx.grant, {:has_trait, ctx.housing.id})
      assert event_count(ctx.grant) == 0
    end

    test "revoked grant refuses" do
      ctx = seed!(%{tier: 2, scope: %{}})
      {:ok, revoked} = Grants.revoke_grant(ctx.grant)
      assert {:error, :revoked} = Oracle.ask(revoked, {:has_trait, ctx.housing.id})
    end

    test "expired grant refuses" do
      ctx = seed!(%{tier: 2, scope: %{}})
      now = DateTime.utc_now()
      expired = %{ctx.grant | expires_at: DateTime.add(now, -3600)}
      assert {:error, :expired} = Oracle.ask(expired, {:has_trait, ctx.housing.id}, now: now)
    end
  end

  # --- budget enforcement ------------------------------------------------------

  describe "budget enforcement" do
    test "exhausted budget refuses; refusal logs no event" do
      ctx = seed!(%{tier: 2, scope: %{}, budget: %{"period" => "day", "max" => 2}})
      q = {:has_trait, ctx.housing.id}

      assert {:ok, _} = Oracle.ask(ctx.grant, q)
      assert {:ok, _} = Oracle.ask(ctx.grant, q)
      assert {:error, :budget_exhausted} = Oracle.ask(ctx.grant, q)
      assert event_count(ctx.grant) == 2
    end

    test "budget resets in the next period" do
      ctx = seed!(%{tier: 2, scope: %{}, budget: %{"period" => "day", "max" => 1}})
      q = {:has_trait, ctx.housing.id}
      now = DateTime.utc_now()

      assert {:ok, _} = Oracle.ask(ctx.grant, q, now: now)
      assert {:error, :budget_exhausted} = Oracle.ask(ctx.grant, q, now: now)
      assert {:ok, _} = Oracle.ask(ctx.grant, q, now: DateTime.add(now, 86_400))
    end

    test "max 0 is always exhausted; empty budget is unlimited" do
      capped = seed!(%{tier: 2, scope: %{}, budget: %{"max" => 0}})

      assert {:error, :budget_exhausted} =
               Oracle.ask(capped.grant, {:has_trait, capped.housing.id})

      open = seed!(%{tier: 2, scope: %{}, budget: %{}})

      for _ <- 1..5 do
        assert {:ok, _} = Oracle.ask(open.grant, {:has_trait, open.housing.id})
      end
    end

    test "capsule reads draw from the same budget as oracle answers" do
      ctx = seed!(%{tier: 3, scope: %{}, budget: %{"period" => "day", "max" => 2}})

      assert {:ok, _} = MeCP.request_capsule(ctx.grant)
      assert {:ok, _} = Oracle.ask(ctx.grant, {:has_trait, ctx.housing.id})
      assert {:error, :budget_exhausted} = MeCP.request_capsule(ctx.grant)
      assert {:error, :budget_exhausted} = Oracle.ask(ctx.grant, {:has_trait, ctx.housing.id})
    end
  end

  # --- capsule gateway ---------------------------------------------------------

  describe "request_capsule/2" do
    test "renders the scoped capsule and requires tier 3" do
      ctx = seed!(%{tier: 3, scope: %{}})
      scoped = %{ctx.grant | scope: %{"category_ids" => [ctx.demo.id]}}

      assert {:ok, rendered} = MeCP.request_capsule(scoped)
      assert rendered =~ "Renter"
      refute rendered =~ "Dog"

      oracle_only = %{ctx.grant | tier: 2}
      assert {:error, :insufficient_tier} = MeCP.request_capsule(oracle_only)
    end
  end

  # --- access-log completeness -------------------------------------------------

  describe "access log" do
    test "every successful read writes exactly one event; shapes never carry values" do
      ctx = seed!(%{tier: 3, scope: %{}})

      assert {:ok, _} = MeCP.request_capsule(ctx.grant)
      assert {:ok, _} = Oracle.ask(ctx.grant, {:has_trait, ctx.housing.id})
      assert {:ok, _} = Oracle.ask(ctx.grant, {:trait_values, ctx.pets.id})

      events = AccessLog.list_events_for_grant(ctx.grant.id)
      assert length(events) == 3
      assert Enum.map(events, & &1.kind) |> Enum.sort() == ["capsule", "oracle", "oracle"]

      for event <- events do
        assert event.request_digest =~ ~r/^[0-9a-f]{64}$/
        shape = inspect(event.response_shape)
        refute shape =~ "Renter"
        refute shape =~ "Dog"
      end
    end

    test "capsule event shape summarizes counts and size" do
      ctx = seed!(%{tier: 3, scope: %{}})
      assert {:ok, rendered} = MeCP.request_capsule(ctx.grant)

      [event] = AccessLog.list_events_for_grant(ctx.grant.id)

      assert event.response_shape == %{
               "categories" => 2,
               "traits" => 2,
               "values" => 2,
               "bytes" => byte_size(rendered)
             }
    end
  end
end
