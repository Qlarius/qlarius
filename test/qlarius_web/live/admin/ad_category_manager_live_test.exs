defmodule QlariusWeb.Admin.AdCategoryManagerLiveTest do
  use QlariusWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Qlarius.AdCategoryFixtures

  alias Qlarius.Repo
  alias Qlarius.Sponster.Ads.{AdCategories, AdCategory, MediaPiece}

  setup %{conn: conn} do
    Repo.delete_all(AdCategory)

    {:ok, %{user: user}} =
      Qlarius.Accounts.register_new_user(%{
        alias: "ad-cat-admin-#{System.unique_integer([:positive])}"
      })

    user = user |> Ecto.Changeset.change(role: "admin") |> Repo.update!()
    %{conn: log_in_user(conn, user)}
  end

  defp rows! do
    %{
      shoes:
        row_fixture(
          row_id: "SP01-01",
          category_id: "SP01",
          ad_label: "Shoe Stores",
          meta_1: "Footwear|Sneakers",
          sort_order: 10
        ),
      boots:
        row_fixture(row_id: "SP01-02", category_id: "SP01", ad_label: "Boots", sort_order: 20),
      soap:
        row_fixture(
          row_id: "SP02-01",
          category_id: "SP02",
          ad_label: "Soap Shops",
          sort_order: 30,
          cohort: "261002-aaaa"
        )
    }
  end

  test "lists every row grouped by category with attribution", %{conn: conn} do
    rows!()
    {:ok, _view, html} = live(conn, ~p"/admin/ad_categories")

    assert html =~ "Showing 3 of 3 rows in 2 categories"
    assert html =~ "Shoe Stores" and html =~ "Boots" and html =~ "Soap Shops"
    assert html =~ ~s(href="#cat-SP01")
    assert html =~ "CC BY 3.0"
  end

  test "collapse and expand categories, and show meta details", %{conn: conn} do
    %{shoes: shoes} = rows!()
    {:ok, view, _html} = live(conn, ~p"/admin/ad_categories")

    html = view |> element("button", "Collapse all") |> render_click()
    refute html =~ "Shoe Stores"

    html = view |> element("button", "Expand all") |> render_click()
    assert html =~ "Shoe Stores"

    html = view |> element("button[aria-label='Toggle SP01']") |> render_click()
    refute html =~ "Shoe Stores"
    assert html =~ "Soap Shops"
    view |> element("button[aria-label='Toggle SP01']") |> render_click()

    html = view |> element("#row-#{shoes.id} button", "Details") |> render_click()
    assert html =~ "Sneakers"
  end

  test "filters by search and cohort", %{conn: conn} do
    rows!()
    {:ok, view, _html} = live(conn, ~p"/admin/ad_categories")

    html = view |> form("#ad-category-filters", filters: %{q: "sneakers"}) |> render_change()
    assert html =~ "Shoe Stores"
    refute html =~ "Soap Shops"

    html =
      view
      |> form("#ad-category-filters", filters: %{q: "", cohort: "261002-aaaa"})
      |> render_change()

    assert html =~ "Soap Shops"
    refute html =~ "Boots"
  end

  test "edits a row", %{conn: conn} do
    %{boots: boots} = rows!()
    {:ok, view, _html} = live(conn, ~p"/admin/ad_categories/#{boots.id}/edit")

    view
    |> form("#ad-category-form", ad_category: %{ad_label: "Boot Shops"})
    |> render_submit()

    assert_patch(view, ~p"/admin/ad_categories")
    assert Repo.get!(AdCategory, boots.id).ad_label == "Boot Shops"
  end

  test "creates rows in a category with a shared cohort", %{conn: conn} do
    rows!()
    {:ok, view, _html} = live(conn, ~p"/admin/ad_categories/new")

    view
    |> form("#new-rows-form", new: %{category_id: "SP02", labels: "Bath Bombs\nCandles"})
    |> render_submit()

    assert_patch(view, ~p"/admin/ad_categories")

    assert %AdCategory{row_id: "SP02-02", cohort: cohort} =
             Repo.get_by!(AdCategory, ad_label: "Bath Bombs")

    assert %AdCategory{row_id: "SP02-03", cohort: ^cohort} =
             Repo.get_by!(AdCategory, ad_label: "Candles")
  end

  test "remaps a row's media pieces to a picked target", %{conn: conn} do
    %{shoes: shoes, boots: boots} = rows!()
    piece = media_piece_fixture(shoes)
    {:ok, view, _html} = live(conn, ~p"/admin/ad_categories")

    html = view |> element("#row-#{shoes.id} button", "Remap") |> render_click()
    assert html =~ "Moves all 1 media piece(s)"

    view |> element("#remap-target input[role=combobox]") |> render_keyup(%{"value" => "boots"})
    view |> element("#remap-target-opt-#{boots.id}") |> render_click()
    view |> element("#remap-modal button", "Move 1 media piece(s)") |> render_click()

    assert Repo.get!(MediaPiece, piece.id).ad_category_id == boots.id
  end

  test "deletes unused rows within the filters after a confirm", %{conn: conn} do
    %{shoes: shoes, boots: boots, soap: soap} = rows!()
    media_piece_fixture(shoes)
    {:ok, view, _html} = live(conn, ~p"/admin/ad_categories")

    view |> form("#ad-category-filters", filters: %{category_id: "SP01"}) |> render_change()
    html = view |> element("button", "Delete unused") |> render_click()
    assert html =~ "1 row(s) matching the current filters"

    view |> element("#prune-modal button", "Delete 1 row(s)") |> render_click()

    refute Repo.get(AdCategory, boots.id)
    assert Repo.get(AdCategory, shoes.id)
    assert Repo.get(AdCategory, soap.id)
  end

  test "moves selected rows to a new cohort", %{conn: conn} do
    %{boots: boots} = rows!()
    {:ok, view, _html} = live(conn, ~p"/admin/ad_categories")

    view |> element("#row-#{boots.id} input[type=checkbox]") |> render_click()
    view |> form("#bulk-cohort-form") |> render_submit()

    assert Repo.get!(AdCategory, boots.id).cohort =~ ~r/^\d{6}-[a-z0-9]{4}$/
  end

  test "renames a category", %{conn: conn} do
    rows!()
    {:ok, view, _html} = live(conn, ~p"/admin/ad_categories")

    view |> element("button[phx-value-id=SP02]", "Edit category") |> render_click()

    view
    |> form("#category-form", category: %{category_name: "Beauty", category_label: "Beauty Care"})
    |> render_submit()

    assert [%{category_label: "Beauty Care"}] = AdCategories.list_rows(%{"category_id" => "SP02"})
  end
end
