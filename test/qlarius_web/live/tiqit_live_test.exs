defmodule QlariusWeb.TiqitLiveTest do
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

    {:ok, %{user: user}} =
      Accounts.register_new_user(%{
        alias: "stash-lv-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01],
        sex_trait_id: 200_001,
        age_trait_id: 200_093
      })

    %{conn: log_in_user(conn, user)}
  end

  test "the first paint is the skeleton; the stash replaces it once loaded", %{conn: conn} do
    dead = conn |> get(~p"/tiqits") |> html_response(200)
    assert dead =~ ~s(id="tiqit-stash-skeleton")
    assert dead =~ ~s(aria-busy="true")
    # The filters show straight away
    assert dead =~ "Fleeting"

    {:ok, view, _html} = live(conn, ~p"/tiqits")
    html = render_async(view)

    refute html =~ "tiqit-stash-skeleton"
    assert html =~ "No tiqits found for this filter."
  end

  test "a filter in the URL loads that filter", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/tiqits?status=fleeted")
    html = render_async(view)

    assert html =~ "tiqits have been fleeted"
  end

  test "changing filter reloads without the skeleton", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/tiqits")
    render_async(view)

    view |> element("button[phx-value-status='gifted']") |> render_click()
    html = render_async(view)

    refute html =~ "tiqit-stash-skeleton"
    assert html =~ "You haven&#39;t gifted any content yet."
  end
end
