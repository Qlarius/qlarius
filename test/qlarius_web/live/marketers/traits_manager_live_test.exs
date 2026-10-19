defmodule QlariusWeb.Live.Marketers.TraitsManagerLiveTest do
  use QlariusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Qlarius.MeCPFixtures

  alias Qlarius.Accounts
  alias Qlarius.Repo

  setup %{conn: conn} do
    {:ok, %{user: user}} =
      Accounts.register_new_user(%{
        alias: "trait-browser-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01]
      })

    user = user |> Ecto.Changeset.change(role: "admin") |> Repo.update!()
    %{conn: log_in_user(conn, user)}
  end

  test "trait browser search matches a search-term slug and a child answer", %{conn: conn} do
    marketer = Qlarius.AdCategoryFixtures.marketer_fixture()
    category = insert_category!("Work")
    token = "qslg#{System.unique_integer([:positive])}"

    insert_trait!(category, "Quiet Topic")
    |> Ecto.Changeset.change(search_terms: ["#{token}slug"])
    |> Repo.update!()

    holder = insert_trait!(category, "Holder Topic")
    insert_trait!(nil, "Answer #{token}child", parent_trait_id: holder.id)

    conn = post(conn, ~p"/marketer/select/#{marketer.id}?#{[return_to: "/marketer/traits"]}")
    {:ok, view, html} = live(conn, ~p"/marketer/traits")
    assert html =~ "Quiet Topic"
    assert html =~ "Holder Topic"

    html = render_search(view, "#{token}slug")
    assert html =~ "Quiet Topic"
    refute html =~ "Holder Topic"

    html = render_search(view, "#{token}child")
    assert html =~ "Holder Topic"
    refute html =~ "Quiet Topic"
  end

  defp render_search(view, query) do
    view
    |> element("form[phx-change='search_traits']")
    |> render_change(%{"search" => query})
  end
end
