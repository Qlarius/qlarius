defmodule QlariusWeb.Api.Admin.TraitControllerTest do
  use QlariusWeb.ConnCase, async: false

  import Qlarius.MeCPFixtures

  alias Qlarius.Accounts.{AdminApiTokens, User}
  alias Qlarius.Repo
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
end
