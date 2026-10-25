defmodule QlariusWeb.Live.Marketers.TargetsManagerLiveTest do
  use QlariusWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Qlarius.TargetingFixtures

  alias Qlarius.Accounts
  alias Qlarius.Repo
  alias Qlarius.Sponster.Campaigns.Targets
  alias Qlarius.YouData.TraitRelationships

  setup %{conn: conn} do
    {:ok, %{user: user}} =
      Accounts.register_new_user(%{
        alias: "targets-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01]
      })

    user = user |> Ecto.Changeset.change(role: "admin") |> Repo.update!()
    marketer = marketer_fixture()

    conn =
      conn
      |> log_in_user(user)
      |> post(~p"/marketer/select/#{marketer.id}?#{[return_to: "/marketer/targets"]}")

    %{conn: conn, marketer: marketer}
  end

  test "adds a group to the bullseye and expands a ring", %{conn: conn, marketer: marketer} do
    parent = parent_trait_fixture("Diet")
    group_a = trait_group_fixture(%{marketer_id: marketer.id}, [trait_fixture(parent, "Vegan")])
    group_b = trait_group_fixture(%{marketer_id: marketer.id}, [trait_fixture(parent, "Keto")])
    target = target_fixture(%{marketer_id: marketer.id}, [])

    {:ok, view, html} = live(conn, ~p"/marketer/targets/#{target.id}/edit")
    assert html =~ "No bullseye yet"

    view |> element("button[phx-value-trait_group_id='#{group_a.id}']") |> render_click()
    view |> element("button[phx-value-trait_group_id='#{group_b.id}']") |> render_click()

    [bullseye] = Targets.get_bands_for_target(target.id)

    assert Enum.map(bullseye.trait_groups, & &1.id) |> Enum.sort() ==
             Enum.sort([group_a.id, group_b.id])

    view |> element("button", "Expand Target") |> render_click()

    view
    |> element(
      "button[phx-click='create_outer_band'][phx-value-excluded_trait_group_id='#{group_b.id}']"
    )
    |> render_click()

    bands = Targets.get_bands_for_target(target.id)
    assert length(bands) == 2
    ring = Targets.outermost_band(bands)
    assert Enum.map(ring.trait_groups, & &1.id) == [group_a.id]
    assert render(view) =~ "Ring created"
  end

  test "anti-groups are marked on the picker and on band chips", %{conn: conn, marketer: marketer} do
    diet = parent_trait_fixture("Diet")
    include = trait_group_fixture(%{marketer_id: marketer.id}, [trait_fixture(diet, "Keto")])
    anti = anti_trait_group_fixture(%{marketer_id: marketer.id}, [trait_fixture(diet, "Vegan")])
    target = target_fixture(%{marketer_id: marketer.id}, [])

    {:ok, view, _html} = live(conn, ~p"/marketer/targets/#{target.id}/edit")

    assert has_element?(
             view,
             "button[phx-value-trait_group_id='#{anti.id}'] [aria-label='keep out']"
           )

    refute has_element?(
             view,
             "button[phx-value-trait_group_id='#{include.id}'] [aria-label='keep out']"
           )

    view |> element("button[phx-value-trait_group_id='#{anti.id}']") |> render_click()
    assert render(view) =~ "Add a trait group that includes people first"

    view |> element("button[phx-value-trait_group_id='#{include.id}']") |> render_click()
    view |> element("button[phx-value-trait_group_id='#{anti.id}']") |> render_click()

    [bullseye] = Targets.get_bands_for_target(target.id)
    assert Enum.map(bullseye.trait_groups, & &1.role) |> Enum.sort() == ["anti", "include"]
    assert has_element?(view, "span[title='Anti-Trait Group: removes anyone with these answers']")
  end

  test "inspect uses the keep-out styling on anti-groups", %{conn: conn, marketer: marketer} do
    diet = parent_trait_fixture("Diet")
    include = trait_group_fixture(%{marketer_id: marketer.id}, [trait_fixture(diet, "Keto")])
    anti = anti_trait_group_fixture(%{marketer_id: marketer.id}, [trait_fixture(diet, "Vegan")])
    target = target_fixture(%{marketer_id: marketer.id}, [[include, anti]])

    {:ok, view, _html} = live(conn, ~p"/marketer/targets/#{target.id}/inspect")

    assert has_element?(view, "span[class*='border-error/40']", anti.title)
    assert has_element?(view, "span[class*='border-error/40'] [aria-label='keep out']")
    refute has_element?(view, "span[class*='border-error/40']", include.title)
  end

  test "done on an empty target explains what is missing", %{conn: conn, marketer: marketer} do
    target = target_fixture(%{marketer_id: marketer.id}, [])
    {:ok, view, _html} = live(conn, ~p"/marketer/targets/#{target.id}/edit")

    view |> element("button", "Done") |> render_click()
    assert render(view) =~ "Create at least a bullseye before finishing"
  end

  describe "anti-trait group suggestions" do
    setup %{marketer: marketer} do
      food = parent_trait_fixture("Fast Food Preferences")
      burgers = trait_fixture(food, "Hamburgers")
      diet = parent_trait_fixture("Typical Daily Diet")
      vegan = trait_fixture(diet, "Vegan")
      vegetarian = trait_fixture(diet, "Vegetarian")

      for to <- [vegan, vegetarian] do
        {:ok, _} =
          TraitRelationships.create(%{
            "trait_id" => burgers.id,
            "related_trait_id" => to.id,
            "kind" => "excludes"
          })
      end

      burger_group = trait_group_fixture(%{marketer_id: marketer.id}, [burgers])
      target = target_fixture(%{marketer_id: marketer.id}, [[burger_group]])

      %{target: target, diet: diet, vegan: vegan, vegetarian: vegetarian}
    end

    test "a target with no excludes rows shows no prompt", %{conn: conn, marketer: marketer} do
      parent = parent_trait_fixture("Pets")
      group = trait_group_fixture(%{marketer_id: marketer.id}, [trait_fixture(parent, "Dogs")])
      target = target_fixture(%{marketer_id: marketer.id}, [[group]])

      {:ok, _view, html} = live(conn, ~p"/marketer/targets/#{target.id}/edit")
      refute html =~ "anti-suggestion-line"
      refute html =~ "keep out"
    end

    test "review, trim the selection, and confirm", ctx do
      {:ok, view, html} = live(ctx.conn, ~p"/marketer/targets/#{ctx.target.id}/edit")
      assert html =~ "2 answers you may want to keep out"

      view |> element("#anti-suggestion-line button", "Review") |> render_click()
      assert has_element?(view, "#suggestion-topic-#{ctx.diet.id}")
      assert has_element?(view, "button", "Keep out 2")

      view
      |> form("#suggestion-review-form", %{
        "trait_ids" => [to_string(ctx.vegan.id)],
        "titles" => %{to_string(ctx.diet.id) => "No vegans"}
      })
      |> render_change()

      assert has_element?(view, "button", "Keep out 1")

      view |> form("#suggestion-review-form") |> render_submit()

      [bullseye] = Targets.get_bands_for_target(ctx.target.id)
      [anti] = Enum.filter(bullseye.trait_groups, &(&1.role == "anti"))
      assert anti.title == "No vegans"
      assert Enum.map(anti.traits, & &1.id) == [ctx.vegan.id]

      html = render(view)
      assert html =~ "1 Anti-Trait Group added"
      assert html =~ "1 answer you may want to keep out"
      refute has_element?(view, "#suggestion-review-form")
    end

    test "dismissing a topic quiets the line and leaves a way back", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/marketer/targets/#{ctx.target.id}/edit")

      view |> element("#anti-suggestion-line button", "Review") |> render_click()

      view
      |> element("#suggestion-topic-#{ctx.diet.id} button", "Not for this target")
      |> render_click()

      html = render(view)
      refute html =~ "you may want to keep out"
      assert html =~ "Dismissed for this target"
      assert has_element?(view, "button", "Reopen")

      view |> element("button", "Reopen") |> render_click()
      assert has_element?(view, "button", "Keep out 2")

      view
      |> element("#suggestion-topic-#{ctx.diet.id} button", "Not for this target")
      |> render_click()

      view |> element("button", "Not now") |> render_click()

      html = render(view)
      refute html =~ "you may want to keep out"
      assert has_element?(view, "button", "Suggestions")
    end
  end
end
