defmodule QlariusWeb.Api.Admin.TraitControllerTest do
  use QlariusWeb.ConnCase, async: false

  import Qlarius.MeCPFixtures

  alias Qlarius.Accounts.{AdminApiTokens, User}
  alias Qlarius.Repo
  alias Qlarius.YouData.Surveys.{SurveyAnswer, SurveyQuestion}
  alias Qlarius.YouData.Traits.Trait

  setup do
    admin =
      %User{}
      |> User.registration_changeset(%{
        "alias" => "api-admin-#{System.unique_integer([:positive])}"
      })
      |> Ecto.Changeset.put_change(:role, "admin")
      |> Repo.insert!()

    {:ok, _token, raw} = AdminApiTokens.issue(admin, "test")

    crafts =
      insert_category!("Hobbies")
      |> insert_trait!("Arts and Crafts")
      |> Ecto.Changeset.change(input_type: "multi_select")
      |> Repo.update!()

    pottery = insert_trait!(nil, "Pottery", parent_trait_id: crafts.id)
    %{token: raw, crafts: crafts, pottery: pottery}
  end

  defp authed(token), do: build_conn() |> put_req_header("authorization", "Bearer #{token}")

  test "search terms are written and read on parents and children", ctx do
    body =
      ctx.token
      |> authed()
      |> patch(~p"/api/admin/traits/#{ctx.crafts.id}", %{"search_terms" => "Crafting, DIY"})
      |> json_response(200)

    assert body["search_terms"] == ["crafting", "diy"]

    body =
      ctx.token
      |> authed()
      |> patch(~p"/api/admin/traits/#{ctx.crafts.id}/children/#{ctx.pottery.id}", %{
        "search_terms" => ["Ceramics", "clay"]
      })
      |> json_response(200)

    assert body["search_terms"] == ["ceramics", "clay"]

    body =
      ctx.token |> authed() |> get(~p"/api/admin/traits/#{ctx.crafts.id}") |> json_response(200)

    assert body["search_terms"] == ["crafting", "diy"]

    assert [%{"search_terms" => ["ceramics", "clay"]}] =
             body["children"] |> Enum.filter(&(&1["id"] == ctx.pottery.id))
  end

  test "leaving search_terms out keeps them; null clears them", ctx do
    ctx.crafts |> Ecto.Changeset.change(search_terms: ["crafting"]) |> Repo.update!()

    ctx.token |> authed() |> patch(~p"/api/admin/traits/#{ctx.crafts.id}", %{"meta_1" => "x"})
    assert Repo.get!(Trait, ctx.crafts.id).search_terms == ["crafting"]

    ctx.token
    |> authed()
    |> patch(~p"/api/admin/traits/#{ctx.crafts.id}", %{"search_terms" => nil})

    assert Repo.get!(Trait, ctx.crafts.id).search_terms == []
  end

  test "design packs take search terms on the parent and children", ctx do
    body =
      ctx.token
      |> authed()
      |> post(~p"/api/admin/traits/design_packs", %{
        "mode" => "reform",
        "parent" => %{"id" => ctx.crafts.id, "search_terms" => ["handmade"]},
        "survey_question" => %{"text" => "Which crafts interest you?"},
        "children" => [
          %{
            "id" => ctx.pottery.id,
            "trait_name" => "Pottery",
            "search_terms" => ["Wheel throwing"]
          },
          %{"trait_name" => "Knitting", "search_terms" => "yarn, needles"}
        ]
      })
      |> json_response(200)

    assert body["search_terms"] == ["handmade"]
    terms = Map.new(body["children"], &{&1["trait_name"], &1["search_terms"]})
    assert terms["Pottery"] == ["wheel throwing"]
    assert terms["Knitting"] == ["yarn", "needles"]
  end

  test "catalog returns search terms on parents and children", ctx do
    ctx.crafts |> Ecto.Changeset.change(search_terms: ["crafting"]) |> Repo.update!()
    ctx.pottery |> Ecto.Changeset.change(search_terms: ["clay"]) |> Repo.update!()

    body =
      ctx.token |> authed() |> get(~p"/api/admin/traits_catalog") |> json_response(200)

    parent =
      body["trait_categories"]
      |> Enum.flat_map(& &1["parent_traits"])
      |> Enum.find(&(&1["id"] == ctx.crafts.id))

    assert parent["search_terms"] == ["crafting"]

    child = Enum.find(parent["children"], &(&1["id"] == ctx.pottery.id))
    assert child["search_terms"] == ["clay"]
  end

  test "trait search returns the ranked results the Builder and Qai see", ctx do
    ctx.pottery |> Ecto.Changeset.change(search_terms: ["ceramics"]) |> Repo.update!()

    body =
      ctx.token
      |> authed()
      |> get(~p"/api/admin/trait_search?q=ceramics&scope=all")
      |> json_response(200)

    hit = Enum.find(body["results"], &(&1["trait_id"] == ctx.crafts.id))
    assert hit["matched_values"] == ["Pottery"]
    assert hit["score"] > 1

    assert Enum.any?(
             hit["matches"],
             &(&1["field"] == "search_term" and &1["tier"] == "exact" and
                 &1["token"] == "ceramics")
           )

    missed =
      ctx.token
      |> authed()
      |> get(~p"/api/admin/trait_search?q=ceramics&scope=builder")
      |> json_response(200)

    refute Enum.any?(missed["results"], &(&1["trait_id"] == ctx.crafts.id))

    survey_trait!(ctx.crafts)

    found =
      ctx.token
      |> authed()
      |> get(~p"/api/admin/trait_search?q=ceramics&scope=builder")
      |> json_response(200)

    assert Enum.any?(found["results"], &(&1["trait_id"] == ctx.crafts.id))

    bad =
      ctx.token
      |> authed()
      |> get(~p"/api/admin/trait_search?q=ceramics&scope=nope")
      |> json_response(422)

    assert bad["error"] == "invalid_scope"
  end

  test "show returns one question and one answer when a trait has duplicates", ctx do
    survey_trait!(ctx.crafts)
    question = Repo.get_by!(SurveyQuestion, trait_id: ctx.crafts.id)

    Repo.insert!(%SurveyQuestion{
      text: "A second question about crafts",
      trait_id: ctx.crafts.id,
      active: "1",
      display_order: 2,
      added_by: 0,
      modified_by: 0
    })

    Repo.insert!(%SurveyAnswer{
      text: "Yes",
      trait_id: ctx.pottery.id,
      survey_question_id: question.id,
      display_order: 1,
      added_by: 0,
      modified_by: 0
    })

    Repo.insert!(%SurveyAnswer{
      text: "Prefer not to say",
      trait_id: ctx.pottery.id,
      survey_question_id: question.id,
      display_order: 9,
      added_by: 0,
      modified_by: 0
    })

    body =
      ctx.token |> authed() |> get(~p"/api/admin/traits/#{ctx.crafts.id}") |> json_response(200)

    assert body["survey_question"]["id"] == question.id

    child = Enum.find(body["children"], &(&1["id"] == ctx.pottery.id))
    assert child["survey_answer"]["text"] == "Yes"
  end

  test "quality fields replace, clear, and reject a bad order", ctx do
    body =
      ctx.token
      |> authed()
      |> patch(~p"/api/admin/traits/#{ctx.crafts.id}", %{
        "ideal_min_tags" => 3,
        "ideal_max_tags" => 8,
        "hard_max_tags" => 15,
        "stale_days" => 365
      })
      |> json_response(200)

    assert body["ideal_min_tags"] == 3
    assert body["hard_max_tags"] == 15
    assert body["stale_days"] == 365
    assert body["expired_days"] == nil

    ctx.token
    |> authed()
    |> patch(~p"/api/admin/traits/#{ctx.crafts.id}", %{"meta_1" => "kept"})
    |> json_response(200)

    assert Repo.get!(Trait, ctx.crafts.id).ideal_min_tags == 3

    body =
      ctx.token
      |> authed()
      |> patch(~p"/api/admin/traits/#{ctx.crafts.id}", %{"ideal_min_tags" => nil})
      |> json_response(200)

    assert body["ideal_min_tags"] == nil
    assert body["ideal_max_tags"] == 8

    error =
      ctx.token
      |> authed()
      |> patch(~p"/api/admin/traits/#{ctx.crafts.id}", %{
        "ripen_days" => 30,
        "stale_days" => 10
      })
      |> json_response(422)

    assert error["error"] == "invalid"
    assert error["errors"]["stale_days"]
  end

  test "relationships are created, listed, canonicalized, and deleted", ctx do
    knitting = insert_trait!(nil, "Knitting", parent_trait_id: ctx.crafts.id)

    body =
      ctx.token
      |> authed()
      |> post(~p"/api/admin/trait_relationships", %{
        "trait_id" => knitting.id,
        "related_trait_id" => ctx.pottery.id,
        "kind" => "conflicts",
        "note" => "Pick one craft"
      })
      |> json_response(201)

    relationship = body["relationship"]
    assert relationship["kind"] == "conflicts"
    assert relationship["trait_id"] == min(knitting.id, ctx.pottery.id)
    assert relationship["related_trait_id"] == max(knitting.id, ctx.pottery.id)
    assert relationship["note"] == "Pick one craft"

    listed =
      ctx.token
      |> authed()
      |> get(~p"/api/admin/trait_relationships?trait_id=#{ctx.crafts.id}")
      |> json_response(200)

    assert Enum.map(listed["relationships"], & &1["id"]) == [relationship["id"]]

    shown =
      ctx.token |> authed() |> get(~p"/api/admin/traits/#{ctx.crafts.id}") |> json_response(200)

    assert Enum.map(shown["relationships"], & &1["id"]) == [relationship["id"]]

    duplicate =
      ctx.token
      |> authed()
      |> post(~p"/api/admin/trait_relationships", %{
        "trait_id" => ctx.pottery.id,
        "related_trait_id" => knitting.id,
        "kind" => "conflicts"
      })
      |> json_response(422)

    assert duplicate["errors"]["trait_id"]

    self =
      ctx.token
      |> authed()
      |> post(~p"/api/admin/trait_relationships", %{
        "trait_id" => ctx.pottery.id,
        "related_trait_id" => ctx.pottery.id,
        "kind" => "requires"
      })
      |> json_response(422)

    assert self["errors"]["related_trait_id"]

    ctx.token
    |> authed()
    |> delete(~p"/api/admin/trait_relationships/#{relationship["id"]}")
    |> json_response(200)

    ctx.token
    |> authed()
    |> delete(~p"/api/admin/trait_relationships/#{relationship["id"]}")
    |> json_response(404)
  end

  test "a new parent reports the skip child it just inserted, unless it is exempt", ctx do
    body =
      ctx.token
      |> authed()
      |> post(~p"/api/admin/traits/#{ctx.crafts.id}/children", %{
        "children" => [%{"trait_name" => "Weaving"}]
      })
      |> json_response(201)

    assert [%{"trait_name" => "Prefer not to say", "is_skipped_tag" => true, "is_exclusive" => true}] =
             body["inserted_children"]

    exempt =
      insert_category!("Required")
      |> insert_trait!("Birth year")
      |> Ecto.Changeset.change(%{input_type: "single_select", skip_exempt: true})
      |> Repo.update!()

    quiet =
      ctx.token
      |> authed()
      |> patch(~p"/api/admin/traits/#{exempt.id}", %{"meta_1" => "year"})
      |> json_response(200)

    assert quiet["inserted_children"] == []
    assert quiet["skip_exempt"] == true
  end

  test "count rules on a single_select parent or a child are rejected", ctx do
    single =
      insert_category!("Pick")
      |> insert_trait!("Gender")
      |> Ecto.Changeset.change(input_type: "single_select")
      |> Repo.update!()

    parent_error =
      ctx.token
      |> authed()
      |> patch(~p"/api/admin/traits/#{single.id}", %{"ideal_min_tags" => 1})
      |> json_response(422)

    assert parent_error["errors"]["ideal_min_tags"]

    child_error =
      ctx.token
      |> authed()
      |> patch(~p"/api/admin/traits/#{ctx.crafts.id}/children/#{ctx.pottery.id}", %{
        "ideal_max_tags" => 2
      })
      |> json_response(422)

    assert child_error["errors"]["ideal_min_tags"]
  end

  test "a suspicious relationship is saved and the warning comes back with it", ctx do
    body =
      ctx.token
      |> authed()
      |> post(~p"/api/admin/trait_relationships", %{
        "trait_id" => ctx.pottery.id,
        "related_trait_id" => ctx.crafts.id,
        "kind" => "conflicts"
      })
      |> json_response(201)

    assert body["relationship"]["id"]
    assert "a child conflicts with its own parent" in body["warnings"]
  end

  test "the integrity report is read only", ctx do
    body =
      ctx.token
      |> authed()
      |> get(~p"/api/admin/traits/integrity_report?skip_rate_threshold=15")
      |> json_response(200)

    assert is_map(body["summary"])
    assert is_list(body["issues"])
    assert is_list(body["skip_monitoring"])
    assert body["skip_rate_threshold"] == 0.15

    ctx.token
    |> authed()
    |> get(~p"/api/admin/traits/integrity_report?skip_rate_threshold=0.2")
    |> json_response(200)
    |> then(fn again -> assert again["skip_rate_threshold"] == 0.2 end)
  end
end
