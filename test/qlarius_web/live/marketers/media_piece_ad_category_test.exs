defmodule QlariusWeb.Live.Marketers.MediaPieceAdCategoryTest do
  use QlariusWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Qlarius.AdCategoryFixtures

  alias Qlarius.Repo
  alias Qlarius.Sponster.Ads.MediaPiece

  setup %{conn: conn} do
    {:ok, %{user: user}} =
      Qlarius.Accounts.register_new_user(%{
        alias: "mp-picker-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01]
      })

    current = row_fixture(ad_label: "Picker Current #{System.unique_integer([:positive])}")

    target =
      row_fixture(
        ad_label: "Picker Target #{System.unique_integer([:positive])}",
        meta_2: "Zebra Grooming|Stripes"
      )

    %{conn: log_in_user(conn, user), piece: media_piece_fixture(current), target: target}
  end

  test "picks a label by meta search and saves it", %{conn: conn, piece: piece, target: target} do
    {:ok, view, _html} = live(conn, ~p"/marketer/media/#{piece.id}/edit")

    assert view |> element("#ad-category-picker-value") |> render() =~
             ~s(value="#{piece.ad_category_id}")

    html =
      view
      |> element("#ad-category-picker input[role=combobox]")
      |> render_keyup(%{"value" => "zebra stripes"})

    assert html =~ target.ad_label

    view |> element("#ad-category-picker-opt-#{target.id}") |> render_click()
    view |> form("#media-piece-form") |> render_submit()

    assert Repo.get!(MediaPiece, piece.id).ad_category_id == target.id
  end

  test "the media_old form embeds the picker", %{conn: conn, piece: piece} do
    html = conn |> get(~p"/marketer/media_old/#{piece.id}/edit") |> html_response(200)
    [form] = Regex.run(~r/<form action="\/marketer\/media_old.*?<\/form>/s, html)
    assert form =~ "data-phx-session"

    assert form =~
             ~s(name="media_piece[ad_category_id]" id="search-select-value" value="#{piece.ad_category_id}")

    refute form =~ ~s(<select id="media_piece_ad_category_id")
  end

  test "the embedded picker renders the hidden input with the current value", %{
    conn: conn,
    piece: piece
  } do
    {:ok, view, _html} =
      live_isolated(conn, QlariusWeb.SearchSelectLive,
        session: %{
          "source" => "ad_categories",
          "name" => "media_piece[ad_category_id]",
          "value" => to_string(piece.ad_category_id),
          "label" => "Ad Category"
        }
      )

    html = render(view)
    assert html =~ ~s(name="media_piece[ad_category_id]")
    assert html =~ ~s(value="#{piece.ad_category_id}")
  end
end
