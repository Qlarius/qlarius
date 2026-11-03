defmodule QlariusWeb.Admin.PromoSequenceLiveTest do
  use QlariusWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Qlarius.Repo
  alias Qlarius.Sponster.PromoSequence

  setup %{conn: conn} do
    {:ok, %{user: user}} =
      Qlarius.Accounts.register_new_user(%{
        alias: "promo-ui-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01]
      })

    user = user |> Ecto.Changeset.change(role: "admin") |> Repo.update!()
    %{conn: log_in_user(conn, user)}
  end

  test "lists the seeded sequence by name and opens it", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/admin/promo_sequences")

    assert html =~ "Sponster"
    assert html =~ "Global"
    assert html =~ "Default"

    sequence = Repo.get_by!(PromoSequence, api_ref: "sponster")
    {:ok, view, html} = live(conn, ~p"/admin/promo_sequences/#{sequence.id}")
    assert html =~ "Sponster"
    assert html =~ "Wide track"
    assert html =~ "Narrow track"
    assert html =~ "500px by up to 80px"
    assert html =~ "216px by up to 80px"
    assert html =~ "w-[500px]"
    assert html =~ "w-[216px]"
    assert html =~ "h-[50px]"
    assert html =~ "Bounce image"
    assert html =~ "/images/sponster_us_quarter.png"
    assert html =~ "hero-chevron-up"
    assert html =~ "hero-chevron-down"
    assert html =~ "hero-trash"
    assert html =~ "max-w-6xl"
    assert has_element?(view, "#promo-sequence-form")
  end

  test "renames a sequence", %{conn: conn} do
    sequence = Repo.get_by!(PromoSequence, api_ref: "sponster")
    {:ok, view, _html} = live(conn, ~p"/admin/promo_sequences/#{sequence.id}")

    view
    |> form("#promo-sequence-form", promo_sequence: %{name: "Sponster home", max_height: "80"})
    |> render_submit()

    assert Repo.get!(PromoSequence, sequence.id).name == "Sponster home"
  end
end
