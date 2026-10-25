defmodule QlariusWeb.Api.Admin.AntiTraitGroupApiTest do
  @moduledoc """
  Exercises the Anti-Trait Group and `excludes` examples from the agent guides
  (`?topic=traits` and `?topic=campaigns`) end to end through the admin API.
  """

  use QlariusWeb.ConnCase, async: false

  import Qlarius.TargetingFixtures

  alias Qlarius.Accounts.{AdminApiTokens, User}
  alias Qlarius.AdCategoryFixtures
  alias Qlarius.Repo
  alias Qlarius.Sponster.Campaigns.{Targets, TraitGroup}

  @png <<137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8,
         2, 0, 0, 0, 144, 119, 83, 222, 0, 0, 0, 12, 73, 68, 65, 84, 8, 215, 99, 248, 255, 255,
         63, 0, 5, 254, 2, 254, 167, 53, 129, 132, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130>>

  setup do
    admin =
      %User{}
      |> User.registration_changeset(%{
        "alias" => "api-admin-#{System.unique_integer([:positive])}"
      })
      |> Ecto.Changeset.put_change(:role, "admin")
      |> Repo.insert!()

    {:ok, _token, raw} = AdminApiTokens.issue(admin, "test")
    AdCategoryFixtures.ensure_three_tap_type!()

    food = parent_trait_fixture("Fast Food Preferences")
    burgers = trait_fixture(food, "Hamburgers")
    pizza = trait_fixture(food, "Pizza")
    diet = parent_trait_fixture("Typical Daily Diet")
    vegan = trait_fixture(diet, "Vegan")
    vegetarian = trait_fixture(diet, "Vegetarian")
    home_zip = parent_trait_fixture("Home Zip Code")
    work_zip = parent_trait_fixture("Work Zip Code")
    home = trait_fixture(home_zip, "85001")
    work = trait_fixture(work_zip, "85001")

    # Guide: "Hamburgers excludes Vegan" is stored; the reverse is not.
    me_file_fixture([burgers, home])
    me_file_fixture([burgers, vegan, home])
    me_file_fixture([pizza, work])

    marketer = marketer_fixture()

    %{
      conn: build_conn() |> put_req_header("authorization", "Bearer #{raw}"),
      marketer: marketer,
      row: AdCategoryFixtures.row_fixture(),
      n: System.unique_integer([:positive]),
      food: food,
      burgers: burgers,
      pizza: pizza,
      diet: diet,
      vegan: vegan,
      vegetarian: vegetarian,
      home: home,
      work: work
    }
  end

  defp banner do
    path = Path.join(System.tmp_dir!(), "banner-#{System.unique_integer([:positive])}.png")
    File.write!(path, @png)
    %Plug.Upload{path: path, filename: "banner.png", content_type: "image/png"}
  end

  defp group(conn, attrs) do
    conn |> post(~p"/api/admin/trait_groups", attrs) |> json_response(201)
  end

  describe "excludes rows (?topic=traits)" do
    test "bulk create from the guide, direction filter, and warnings", ctx do
      body = %{
        "create" => [
          %{
            "trait_id" => ctx.burgers.id,
            "related_trait_id" => ctx.vegan.id,
            "type" => "excludes",
            "note" => "Vegans eat no meat"
          },
          %{
            "trait_id" => ctx.burgers.id,
            "related_trait_id" => ctx.vegetarian.id,
            "type" => "excludes",
            "severity" => "soft"
          }
        ]
      }

      dry =
        ctx.conn
        |> post(~p"/api/admin/trait_relationships/bulk", Map.put(body, "dry_run", true))
        |> json_response(200)

      assert Enum.map(dry["results"], & &1["status"]) == ["created", "created"]

      assert ctx.conn
             |> get(~p"/api/admin/trait_relationships?trait_id=#{ctx.food.id}&kind=excludes")
             |> json_response(200) == %{"relationships" => []}

      created =
        ctx.conn |> post(~p"/api/admin/trait_relationships/bulk", body) |> json_response(200)

      [hard, soft] = created["results"]
      assert hard["relationship"]["severity"] == "hard"
      assert hard["relationship"]["trait_id"] == ctx.burgers.id
      assert hard["relationship"]["related_trait_id"] == ctx.vegan.id
      assert soft["relationship"]["severity"] == "soft"

      from_food =
        ctx.conn
        |> get(
          ~p"/api/admin/trait_relationships?trait_id=#{ctx.food.id}&kind=excludes&direction=from"
        )
        |> json_response(200)

      assert length(from_food["relationships"]) == 2

      assert ctx.conn
             |> get(
               ~p"/api/admin/trait_relationships?trait_id=#{ctx.food.id}&kind=excludes&direction=to"
             )
             |> json_response(200) == %{"relationships" => []}

      to_diet =
        ctx.conn
        |> get(
          ~p"/api/admin/trait_relationships?trait_id=#{ctx.diet.id}&kind=excludes&direction=to"
        )
        |> json_response(200)

      assert length(to_diet["relationships"]) == 2

      assert ctx.conn
             |> get(~p"/api/admin/trait_relationships?trait_id=#{ctx.diet.id}&direction=sideways")
             |> json_response(422)
             |> Map.fetch!("error") == "invalid_direction"

      reverse =
        ctx.conn
        |> post(~p"/api/admin/trait_relationships", %{
          trait_id: ctx.vegan.id,
          related_trait_id: ctx.burgers.id,
          kind: "excludes"
        })
        |> json_response(201)

      assert Enum.any?(reverse["warnings"], &(&1 =~ "reverse excludes row"))

      same_parent =
        ctx.conn
        |> post(~p"/api/admin/trait_relationships", %{
          trait_id: ctx.burgers.id,
          related_trait_id: ctx.pizza.id,
          kind: "excludes"
        })
        |> json_response(201)

      assert Enum.any?(same_parent["warnings"], &(&1 =~ "own parent"))

      report = ctx.conn |> get(~p"/api/admin/traits/integrity_report") |> json_response(200)
      excludes = report["excludes"]
      assert excludes["total"] >= 4

      assert Enum.any?(
               excludes["symmetric"],
               &(&1["relationship_id"] == hard["relationship"]["id"])
             )

      assert Enum.any?(excludes["unused"], &(&1["relationship_id"] == hard["relationship"]["id"]))

      # Half of the burger holders are vegan in this fixture: 1 of 2 is not over half.
      refute Enum.any?(
               excludes["over_constraining"],
               &(&1["relationship_id"] == hard["relationship"]["id"])
             )
    end
  end

  describe "Anti-Trait Groups on targets (?topic=campaigns)" do
    setup ctx do
      {:ok, _} =
        Qlarius.YouData.TraitRelationships.create(%{
          "trait_id" => ctx.burgers.id,
          "related_trait_id" => ctx.vegan.id,
          "kind" => "excludes",
          "note" => "Vegans eat no meat"
        })

      ref = "ptp-2610-brand#{ctx.n}-phx"
      marketer = ctx.marketer.id

      burger_fans =
        group(ctx.conn, %{
          api_ref: "#{ref}.tg-1",
          title: "Burger fans",
          marketer_id: marketer,
          parent_trait_id: ctx.food.id,
          trait_ids: [ctx.burgers.id, ctx.pizza.id]
        })

      phoenix =
        group(ctx.conn, %{
          api_ref: "#{ref}.tg-2",
          title: "Phoenix",
          marketer_id: marketer,
          trait_ids: [ctx.home.id, ctx.work.id]
        })

      assert phoenix["trait_group"]["parent_trait_id"] == nil
      assert phoenix["trait_group"]["role"] == "include"

      %{ref: ref, burger_fans: burger_fans["trait_group"], phoenix: phoenix["trait_group"]}
    end

    test "role is fixed, bands follow the rules, and reach reports included and removed", ctx do
      anti =
        group(ctx.conn, %{
          api_ref: "#{ctx.ref}.tg-3",
          title: "Keep out · Typical Daily Diet",
          marketer_id: ctx.marketer.id,
          parent_trait_id: ctx.diet.id,
          trait_ids: [ctx.vegan.id],
          role: "anti"
        })

      assert anti["trait_group"]["role"] == "anti"

      fixed =
        ctx.conn
        |> patch(~p"/api/admin/trait_groups/#{anti["trait_group"]["id"]}", %{role: "include"})
        |> json_response(422)

      assert fixed["error"] == "role_immutable"

      anti_only =
        ctx.conn
        |> post(~p"/api/admin/targets/builds", %{
          api_ref: "#{ctx.ref}.target-bad",
          marketer_id: ctx.marketer.id,
          title: "Nobody",
          bullseye: [anti["trait_group"]["id"]],
          dry_run: true
        })
        |> json_response(422)

      assert anti_only["error"] == "include_group_required"

      last_standing =
        ctx.conn
        |> post(~p"/api/admin/targets/builds", %{
          api_ref: "#{ctx.ref}.target-bad",
          marketer_id: ctx.marketer.id,
          title: "Nobody",
          bullseye: [ctx.burger_fans["id"], anti["trait_group"]["id"]],
          drop_order: [ctx.burger_fans["id"]],
          dry_run: true
        })
        |> json_response(422)

      assert last_standing["error"] == "include_group_required"

      vegan_fans =
        group(ctx.conn, %{
          api_ref: "#{ctx.ref}.tg-4",
          title: "Vegans",
          marketer_id: ctx.marketer.id,
          parent_trait_id: ctx.diet.id,
          trait_ids: [ctx.vegan.id]
        })

      both =
        ctx.conn
        |> post(~p"/api/admin/targets/builds", %{
          api_ref: "#{ctx.ref}.target-bad",
          marketer_id: ctx.marketer.id,
          title: "Contradiction",
          bullseye: [vegan_fans["trait_group"]["id"], anti["trait_group"]["id"]],
          dry_run: true
        })
        |> json_response(422)

      assert both["error"] == "trait_in_both_roles"
      assert both["message"] =~ to_string(ctx.vegan.id)

      preview =
        ctx.conn
        |> post(~p"/api/admin/targets/builds", %{
          api_ref: "#{ctx.ref}.target",
          marketer_id: ctx.marketer.id,
          title: "Phoenix burger fans",
          bullseye: [ctx.burger_fans["id"], ctx.phoenix["id"], anti["trait_group"]["id"]],
          drop_order: [anti["trait_group"]["id"], ctx.burger_fans["id"]],
          dry_run: true
        })
        |> json_response(200)

      [bullseye, ring1, ring2] = preview["bands"]
      assert bullseye["anti_group_ids"] == [anti["trait_group"]["id"]]
      assert bullseye["include_group_ids"] == [ctx.burger_fans["id"], ctx.phoenix["id"]]
      assert %{"included" => 3, "removed" => 1, "estimated_reach" => 2} = bullseye
      assert %{"included" => 3, "removed" => 0, "estimated_reach" => 3} = ring1
      assert ring2["trait_group_ids"] == [ctx.phoenix["id"]]
      assert ring2["estimated_reach"] == 3

      created =
        ctx.conn
        |> post(~p"/api/admin/targets/builds", %{
          api_ref: "#{ctx.ref}.target",
          marketer_id: ctx.marketer.id,
          title: "Phoenix burger fans",
          bullseye: [ctx.burger_fans["id"], ctx.phoenix["id"], anti["trait_group"]["id"]],
          drop_order: [anti["trait_group"]["id"], ctx.burger_fans["id"]]
        })
        |> json_response(201)

      [bullseye | _] = created["target"]["bands"]
      assert bullseye["label"] == "Bullseye"
      assert bullseye["anti_groups"] == [anti["trait_group"]["id"]]
      assert length(created["target"]["bands"]) == 3

      clone =
        ctx.conn
        |> post(~p"/api/admin/targets/#{created["target"]["id"]}/clone", %{
          api_ref: "#{ctx.ref}.target-v2"
        })
        |> json_response(201)

      assert hd(clone["target"]["bands"])["anti_groups"] == [anti["trait_group"]["id"]]
    end

    test "suggestions follow excludes rows, dismiss per target, and attach anti-groups", ctx do
      target =
        ctx.conn
        |> post(~p"/api/admin/targets/builds", %{
          api_ref: "#{ctx.ref}.target",
          marketer_id: ctx.marketer.id,
          title: "Phoenix burger fans",
          bullseye: [ctx.burger_fans["id"], ctx.phoenix["id"]],
          drop_order: [ctx.burger_fans["id"]]
        })
        |> json_response(201)

      target_id = target["target"]["id"]

      suggestions =
        ctx.conn |> get(~p"/api/admin/targets/#{target_id}/suggestions") |> json_response(200)

      assert suggestions["count"] == 1
      assert suggestions["frozen"] == false
      [topic] = suggestions["topics"]
      assert topic["parent_trait_id"] == ctx.diet.id

      assert [
               %{
                 "trait_id" => vegan_id,
                 "severity" => "hard",
                 "because" => ["Hamburgers"],
                 "note" => "Vegans eat no meat"
               }
             ] = topic["traits"]

      assert vegan_id == ctx.vegan.id

      # A vegan restaurant targeting Vegans is never told to keep out burger eaters.
      vegans =
        group(ctx.conn, %{
          api_ref: "#{ctx.ref}.tg-vegans",
          title: "Vegans",
          marketer_id: ctx.marketer.id,
          parent_trait_id: ctx.diet.id,
          trait_ids: [ctx.vegan.id]
        })

      vegan_target =
        ctx.conn
        |> post(~p"/api/admin/targets/builds", %{
          api_ref: "#{ctx.ref}.target-vegan",
          marketer_id: ctx.marketer.id,
          title: "Vegans",
          bullseye: [vegans["trait_group"]["id"]]
        })
        |> json_response(201)

      assert ctx.conn
             |> get(~p"/api/admin/targets/#{vegan_target["target"]["id"]}/suggestions")
             |> json_response(200)
             |> Map.fetch!("count") == 0

      missing =
        ctx.conn
        |> post(~p"/api/admin/targets/#{target_id}/suggestions/dismiss", %{})
        |> json_response(422)

      assert missing["error"] == "parent_trait_id_required"

      dismissed =
        ctx.conn
        |> post(~p"/api/admin/targets/#{target_id}/suggestions/dismiss", %{
          parent_trait_id: ctx.diet.id
        })
        |> json_response(200)

      assert dismissed["result"] == "dismissed"
      assert dismissed["count"] == 0
      assert [%{"parent_trait_id" => _}] = dismissed["dismissed"]

      reopened =
        ctx.conn
        |> post(~p"/api/admin/targets/#{target_id}/suggestions/reopen", %{
          parent_trait_id: ctx.diet.id
        })
        |> json_response(200)

      assert reopened["result"] == "reopened"
      assert reopened["count"] == 1

      anti =
        group(ctx.conn, %{
          api_ref: "#{ctx.ref}.tg-anti",
          title: "Keep out · Typical Daily Diet",
          marketer_id: ctx.marketer.id,
          parent_trait_id: ctx.diet.id,
          trait_ids: [ctx.vegan.id],
          role: "anti"
        })

      refused =
        ctx.conn
        |> post(~p"/api/admin/targets/#{target_id}/anti_groups", %{
          trait_group_id: ctx.burger_fans["id"]
        })
        |> json_response(422)

      assert refused["error"] == "anti_group_required"

      [bullseye_band, _ring] = target["target"]["bands"]

      attached =
        ctx.conn
        |> post(~p"/api/admin/targets/#{target_id}/anti_groups", %{
          trait_group_id: anti["trait_group"]["id"],
          band_ids: [bullseye_band["id"]]
        })
        |> json_response(200)

      assert attached == %{
               "result" => "attached",
               "trait_group_id" => anti["trait_group"]["id"],
               "band_ids" => [bullseye_band["id"]]
             }

      bands = Targets.get_bands_for_target(target_id)
      bullseye = Enum.find(bands, &(&1.id == bullseye_band["id"]))
      assert Enum.any?(bullseye.trait_groups, &TraitGroup.anti?/1)
      ring = Enum.find(bands, &(&1.id != bullseye_band["id"]))
      refute Enum.any?(ring.trait_groups, &TraitGroup.anti?/1)

      assert ctx.conn
             |> get(~p"/api/admin/targets/#{target_id}/suggestions")
             |> json_response(200)
             |> Map.fetch!("count") == 0
    end

    test "the one-call PTP build from the guide carries roles and multi-topic groups", ctx do
      base = "ptp-2610-joes#{ctx.n}-phx"

      params = %{
        api_ref_base: base,
        marketer: %{business_name: "Joe's Burgers", business_url: "https://joes#{ctx.n}.example"},
        media_piece: %{
          title: "Joe's Burgers",
          media_piece_type_id: 1,
          ad_category_row_id: ctx.row.row_id,
          display_url: "joes.example",
          jump_url: "https://joes.example",
          banner_image: banner()
        },
        trait_groups: [
          %{title: "Burger fans", parent_trait_id: ctx.food.id, trait_ids: [ctx.burgers.id]},
          %{title: "Phoenix", trait_ids: [ctx.home.id, ctx.work.id]},
          %{
            title: "Keep out · Typical Daily Diet",
            role: "anti",
            parent_trait_id: ctx.diet.id,
            trait_ids: [ctx.vegan.id]
          }
        ],
        target: %{title: "Phoenix burger fans", drop_order: [2, 0]},
        sequence: %{title: "Joe's"},
        campaign: %{title: "Joe's PTP"}
      }

      built = ctx.conn |> post(~p"/api/admin/ptp_campaigns/builds", params) |> json_response(201)
      assert built["result"] == "created"

      [bullseye, ring1, ring2] = built["bands"]
      assert %{"included" => 2, "removed" => 1, "estimated_reach" => 1} = bullseye
      assert %{"included" => 2, "removed" => 0, "estimated_reach" => 2} = ring1
      assert ring2["estimated_reach"] == 3

      groups =
        built["trait_group_ids"]
        |> Enum.map(&Repo.get!(TraitGroup, &1))

      assert Enum.map(groups, & &1.role) == ["include", "include", "anti"]
      assert Enum.map(groups, & &1.parent_trait_id) == [ctx.food.id, nil, ctx.diet.id]
    end
  end
end
