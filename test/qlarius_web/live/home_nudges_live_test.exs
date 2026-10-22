defmodule QlariusWeb.HomeNudgesLiveTest do
  use QlariusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Qlarius.Accounts
  alias Qlarius.Repo
  alias Qlarius.YouData.Traits.Trait

  setup %{conn: conn} do
    trait = fn attrs ->
      Repo.insert!(
        struct(
          Trait,
          Map.merge(%{input_type: "text", display_order: 1, modified_by: 0, added_by: 0}, attrs)
        )
      )
    end

    trait.(%{id: 1, trait_name: "Sex"})
    trait.(%{id: 93, trait_name: "Age"})
    trait.(%{id: 200_001, parent_trait_id: 1, trait_name: "Male"})
    trait.(%{id: 200_093, parent_trait_id: 93, trait_name: "25-34"})

    Qlarius.System.set_global_variable("STRONG_START_TAG_GOAL", "25")

    {:ok, %{user: user}} =
      Accounts.register_new_user(%{
        alias: "nudge-lv-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01],
        sex_trait_id: 200_001,
        age_trait_id: 200_093
      })

    %{conn: log_in_user(conn, user)}
  end

  test "next steps show under the overview as small cards", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/home")
    html = render_async(view)

    assert has_element?(view, "#home-nudges-tag_goal", "Reach 25 tags")
    assert has_element?(view, "#home-nudges-invite", "Invite friends")
    assert html =~ ~s(src="/images/nudges/tag_goal.svg")
    refute html =~ "Finish setting up"
  end

  test "tapping a card opens its page", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/home")
    render_async(view)

    assert {:error, {:live_redirect, %{to: "/referrals"}}} =
             view
             |> element("#home-nudges-invite .nudge-card__open")
             |> render_click()
  end

  test "a dismissed card stays gone after reload", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/home")
    render_async(view)

    view |> element("#home-nudges-notifications .nudge-card__dismiss") |> render_click()
    refute has_element?(view, "#home-nudges-notifications")

    {:ok, view, _html} = live(conn, ~p"/home")
    render_async(view)

    refute has_element?(view, "#home-nudges-notifications")
    assert has_element?(view, "#home-nudges-invite")
  end
end
