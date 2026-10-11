defmodule QlariusWeb.Api.Admin.TraitBulkTest do
  use QlariusWeb.ConnCase, async: false

  import Ecto.Query
  import Phoenix.LiveViewTest
  import Qlarius.MeCPFixtures

  alias Qlarius.Accounts
  alias Qlarius.Accounts.{AdminApiTokens, User}
  alias Qlarius.Repo
  alias Qlarius.YouData.Traits.Trait
  alias Qlarius.YouData.Traits.TraitAuditEntry
  alias Qlarius.YouData.Traits.TraitRelationship
  alias Qlarius.YouData.TraitRelationships

  setup do
    admin =
      %User{}
      |> User.registration_changeset(%{
        "alias" => "bulk-admin-#{System.unique_integer([:positive])}"
      })
      |> Ecto.Changeset.put_change(:role, "admin")
      |> Repo.insert!()

    {:ok, _token, raw} = AdminApiTokens.issue(admin, "bulk-test")

    parent =
      insert_category!("Bulk")
      |> insert_trait!("Diet")
      |> Ecto.Changeset.change(input_type: "multi_select")
      |> Repo.update!()

    plants = insert_trait!(nil, "Plants", parent_trait_id: parent.id, display_order: 1)
    fish = insert_trait!(nil, "Fish", parent_trait_id: parent.id, display_order: 2)
    none = insert_trait!(nil, "None of these", parent_trait_id: parent.id, display_order: 3)

    %{token: raw, admin: admin, parent: parent, plants: plants, fish: fish, none: none}
  end

  defp authed(token), do: build_conn() |> put_req_header("authorization", "Bearer #{token}")

  test "make_exclusive is idempotent and unmake removes only sibling conflicts", ctx do
    body =
      ctx.token
      |> authed()
      |> post(~p"/api/admin/traits/#{ctx.parent.id}/children/#{ctx.none.id}/make_exclusive", %{
        "note" => "Stands alone"
      })
      |> json_response(200)

    assert body["created"] == 2
    assert body["skipped"] == 0
    assert length(body["relationship_ids"]) == 2

    again =
      ctx.token
      |> authed()
      |> post(~p"/api/admin/traits/#{ctx.parent.id}/children/#{ctx.none.id}/make_exclusive", %{})
      |> json_response(200)

    assert again["created"] == 0
    assert again["skipped"] == 2

    outside = insert_trait!(nil, "Outside")

    {:ok, _} =
      Qlarius.YouData.TraitRelationships.create(%{
        "trait_id" => ctx.none.id,
        "related_trait_id" => outside.id,
        "kind" => "conflicts"
      })

    cleared =
      ctx.token
      |> authed()
      |> post(~p"/api/admin/traits/#{ctx.parent.id}/children/#{ctx.none.id}/unmake_exclusive", %{})
      |> json_response(200)

    assert cleared["deleted"] == 2
    assert Repo.get_by(TraitRelationship, trait_id: min(ctx.none.id, outside.id), related_trait_id: max(ctx.none.id, outside.id))
  end

  test "a new child inherits an exclusive sibling's conflicts", ctx do
    ctx.token
    |> authed()
    |> post(~p"/api/admin/traits/#{ctx.parent.id}/children/#{ctx.plants.id}/make_exclusive", %{})
    |> json_response(200)

    body =
      ctx.token
      |> authed()
      |> post(~p"/api/admin/traits/#{ctx.parent.id}/children", %{
        "children" => [%{"trait_name" => "Eggs"}]
      })
      |> json_response(201)

    eggs = Enum.find(body["children"], &(&1["trait_name"] == "Eggs"))

    assert Enum.any?(body["inserted_relationships"], fn link ->
             Enum.sort([link["trait_id"], link["related_trait_id"]]) ==
               Enum.sort([ctx.plants.id, eggs["id"]])
           end)

    shown =
      ctx.token |> authed() |> get(~p"/api/admin/traits/#{ctx.parent.id}") |> json_response(200)

    assert ctx.plants.id in shown["exclusive_child_ids"]

    catalog =
      ctx.token |> authed() |> get(~p"/api/admin/traits_catalog") |> json_response(200)

    listed =
      catalog["trait_categories"]
      |> Enum.flat_map(& &1["parent_traits"])
      |> Enum.find(&(&1["id"] == ctx.parent.id))

    assert ctx.plants.id in listed["exclusive_child_ids"]
    assert Map.has_key?(listed, "nudge_text")
    assert Map.has_key?(listed, "ideal_min_tags")
    assert Map.has_key?(listed, "skip_exempt")

    quiet =
      ctx.token
      |> authed()
      |> post(~p"/api/admin/traits/design_packs", %{
        "mode" => "reform",
        "extend_exclusive_conflicts" => false,
        "parent" => %{"id" => ctx.parent.id},
        "survey_question" => %{"text" => "What do you eat?"},
        "children" => [
          %{"id" => ctx.plants.id, "trait_name" => "Plants"},
          %{"id" => ctx.fish.id, "trait_name" => "Fish"},
          %{"id" => ctx.none.id, "trait_name" => "None of these"},
          %{"trait_name" => "Dairy"}
        ]
      })
      |> json_response(200)

    assert quiet["inserted_relationships"] == []
  end

  test "sibling links can be listed by parent and type", ctx do
    ctx.token
    |> authed()
    |> post(~p"/api/admin/traits/#{ctx.parent.id}/children/#{ctx.none.id}/make_exclusive", %{})
    |> json_response(200)

    body =
      ctx.token
      |> authed()
      |> get(~p"/api/admin/trait_relationships?parent_id=#{ctx.parent.id}&type=conflicts")
      |> json_response(200)

    assert length(body["relationships"]) == 2
    assert Enum.all?(body["relationships"], &(&1["kind"] == "conflicts"))
  end

  test "bulk relationships are idempotent, dry_run writes nothing, and an error rolls back",
       ctx do
    created =
      ctx.token
      |> authed()
      |> post(~p"/api/admin/trait_relationships/bulk", %{
        "create" => [
          %{
            "trait_id" => ctx.plants.id,
            "related_trait_id" => ctx.fish.id,
            "type" => "conflicts",
            "note" => "Pick one"
          }
        ]
      })
      |> json_response(200)

    assert hd(created["results"])["status"] == "created"
    refute created["rolled_back"]

    again =
      ctx.token
      |> authed()
      |> post(~p"/api/admin/trait_relationships/bulk", %{
        "create" => [
          %{"trait_id" => ctx.fish.id, "related_trait_id" => ctx.plants.id, "type" => "conflicts"}
        ]
      })
      |> json_response(200)

    assert hd(again["results"])["status"] == "exists"

    link_id = hd(created["results"])["relationship"]["id"]

    dry =
      ctx.token
      |> authed()
      |> post(~p"/api/admin/trait_relationships/bulk", %{
        "dry_run" => true,
        "delete" => [link_id]
      })
      |> json_response(200)

    assert hd(dry["results"])["status"] == "deleted"
    assert dry["rolled_back"]
    assert Repo.get(TraitRelationship, link_id)

    rolled =
      ctx.token
      |> authed()
      |> post(~p"/api/admin/trait_relationships/bulk", %{
        "create" => [
          %{"trait_id" => ctx.none.id, "related_trait_id" => ctx.none.id, "type" => "requires"}
        ],
        "delete" => [link_id]
      })
      |> json_response(422)

    assert rolled["rolled_back"]
    assert Repo.get(TraitRelationship, link_id)

    patched =
      ctx.token
      |> authed()
      |> patch(~p"/api/admin/trait_relationships/#{link_id}", %{"note" => "Choose one", "type" => "conflicts"})
      |> json_response(200)

    assert patched["relationship"]["note"] == "Choose one"
  end

  test "bulk rules and search terms validate, keep omitted fields, and do not insert a skip",
       ctx do
    updated =
      ctx.token
      |> authed()
      |> patch(~p"/api/admin/traits/bulk_rules", %{
        "items" => [%{"trait_id" => ctx.parent.id, "ripen_days" => 7, "nudge_text" => "Helps"}]
      })
      |> json_response(200)

    assert hd(updated["results"])["status"] == "updated"
    parent = Repo.get!(Trait, ctx.parent.id)
    assert parent.ripen_days == 7
    assert parent.nudge_text == "Helps"
    refute Repo.exists?(from t in Trait, where: t.parent_trait_id == ^parent.id and t.is_skipped_tag == true)

    kept =
      ctx.token
      |> authed()
      |> patch(~p"/api/admin/traits/bulk_rules", %{
        "items" => [%{"trait_id" => ctx.parent.id, "stale_days" => 30}]
      })
      |> json_response(200)

    assert hd(kept["results"])["status"] == "updated"
    parent = Repo.get!(Trait, ctx.parent.id)
    assert parent.ripen_days == 7
    assert parent.stale_days == 30

    dry =
      ctx.token
      |> authed()
      |> patch(~p"/api/admin/traits/bulk_rules", %{
        "dry_run" => true,
        "items" => [%{"trait_id" => ctx.parent.id, "ripen_days" => nil}]
      })
      |> json_response(200)

    assert dry["rolled_back"]
    assert Repo.get!(Trait, ctx.parent.id).ripen_days == 7

    bad =
      ctx.token
      |> authed()
      |> patch(~p"/api/admin/traits/bulk_rules", %{
        "items" => [
          %{"trait_id" => ctx.parent.id, "expired_days" => 9},
          %{"trait_id" => ctx.plants.id, "ideal_min_tags" => 2}
        ]
      })
      |> json_response(422)

    assert bad["rolled_back"]
    assert Repo.get!(Trait, ctx.parent.id).expired_days == nil

    terms =
      ctx.token
      |> authed()
      |> patch(~p"/api/admin/traits/bulk_search_terms", %{
        "items" => [
          %{"trait_id" => ctx.parent.id, "search_terms" => ["eating"]},
          %{"trait_id" => ctx.parent.id, "child_id" => ctx.fish.id, "search_terms" => ["seafood"]}
        ]
      })
      |> json_response(200)

    assert Enum.map(terms["results"], & &1["status"]) == ["updated", "updated"]
    assert Repo.get!(Trait, ctx.parent.id).search_terms == ["eating"]
    assert Repo.get!(Trait, ctx.fish.id).search_terms == ["seafood"]
    refute Repo.exists?(from t in Trait, where: t.parent_trait_id == ^ctx.parent.id and t.is_skipped_tag == true)
  end

  test "changes are logged with the token label, before, and after", ctx do
    ctx.token
    |> authed()
    |> patch(~p"/api/admin/traits/bulk_rules", %{
      "items" => [%{"trait_id" => ctx.parent.id, "ripen_days" => 4}]
    })
    |> json_response(200)

    body =
      ctx.token
      |> authed()
      |> get(~p"/api/admin/audit_log?trait_id=#{ctx.parent.id}")
      |> json_response(200)

    entry = Enum.find(body["entries"], &(&1["action"] == "rules"))
    assert entry["token_label"] == "bulk-test"
    assert entry["before"]["ripen_days"] == nil
    assert entry["after"]["ripen_days"] == 4
    assert entry["inserted_at"]
    assert Repo.get_by(TraitAuditEntry, trait_id: ctx.parent.id, action: "rules")
  end

  test "a bulk call counts as one write", ctx do
    key = "admin_api_write:#{ctx.admin.id}"

    for _ <- 1..59 do
      assert {:allow, _} = Hammer.check_rate(key, 60_000, 60)
    end

    ctx.token
    |> authed()
    |> post(~p"/api/admin/trait_relationships/bulk", %{
      "create" =>
        for _ <- 1..5 do
          %{
            "trait_id" => ctx.plants.id,
            "related_trait_id" => ctx.fish.id,
            "type" => "conflicts"
          }
        end
    })
    |> json_response(200)

    ctx.token
    |> authed()
    |> patch(~p"/api/admin/traits/#{ctx.parent.id}", %{"meta_1" => "again"})
    |> json_response(429)
  end

  test "the trait manager marks a child exclusive without clearing tags", ctx do
    for {id, name, parent_id} <- [
          {1, "Sex", nil},
          {93, "Age", nil},
          {200_001, "Male", 1},
          {200_093, "25-34", 93}
        ] do
      Repo.insert!(%Trait{
        id: id,
        trait_name: name,
        parent_trait_id: parent_id,
        input_type: "text",
        display_order: 1,
        modified_by: 0,
        added_by: 0
      })
    end

    {:ok, %{user: user}} =
      Accounts.register_new_user(%{
        alias: "bulk-lv-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01],
        sex_trait_id: 200_001,
        age_trait_id: 200_093
      })

    user |> Ecto.Changeset.change(role: "admin") |> Repo.update!()

    {:ok, view, _html} =
      user
      |> then(&log_in_user(build_conn(), &1))
      |> live(~p"/admin/traits")

    view
    |> element("button[phx-value-id='#{ctx.parent.id}']")
    |> render_click()

    view
    |> element("button[phx-value-id='#{ctx.none.id}']", "Mark as exclusive to other children")
    |> render_click()

    html = render(view)
    assert html =~ "Exclusive"
    assert html =~ "Clear exclusive links"

    ids = TraitRelationships.exclusive_child_ids(ctx.parent.id)
    assert ctx.none.id in ids
  end
end
