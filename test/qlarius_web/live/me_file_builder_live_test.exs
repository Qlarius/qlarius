defmodule QlariusWeb.MeFileBuilderLiveTest do
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
        alias: "builder-lv-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01],
        sex_trait_id: 200_001,
        age_trait_id: 200_093
      })

    %{conn: log_in_user(conn, user)}
  end

  test "the first paint is the index skeleton; the index replaces it once loaded", %{
    conn: conn
  } do
    dead = conn |> get(~p"/me_file_builder") |> html_response(200)
    assert dead =~ ~s(id="builder-index-skeleton")
    assert dead =~ ~s(aria-busy="true")
    assert dead =~ "Tap a topic to add or update its tags."

    {:ok, view, _html} = live(conn, ~p"/me_file_builder")
    html = render_async(view)

    refute html =~ "builder-index-skeleton"
    assert html =~ ~s(class="builder-index pt-2")
  end
end
