defmodule QlariusWeb.WalletLiveTest do
  use QlariusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Qlarius.Accounts
  alias Qlarius.Repo
  alias Qlarius.YouData.Traits.Trait

  setup %{conn: conn} do
    Repo.insert!(%Trait{
      id: 1,
      trait_name: "Sex",
      input_type: "text",
      display_order: 1,
      modified_by: 0,
      added_by: 0
    })

    Repo.insert!(%Trait{
      id: 93,
      trait_name: "Age",
      input_type: "text",
      display_order: 1,
      modified_by: 0,
      added_by: 0
    })

    male =
      Repo.insert!(%Trait{
        id: 200_001,
        parent_trait_id: 1,
        trait_name: "Male",
        input_type: "text",
        display_order: 1,
        modified_by: 0,
        added_by: 0
      })

    age =
      Repo.insert!(%Trait{
        id: 200_093,
        parent_trait_id: 93,
        trait_name: "25-34",
        input_type: "text",
        display_order: 1,
        modified_by: 0,
        added_by: 0
      })

    {:ok, %{user: user}} =
      Accounts.register_new_user(%{
        alias: "wallet-lv-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01],
        sex_trait_id: male.id,
        age_trait_id: age.id
      })

    %{conn: log_in_user(conn, user), user: user}
  end

  test "shows available to spend and the activity plus allowance equation", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/wallet")

    assert html =~ "Available to spend"
    assert html =~ "$2.00"
    assert html =~ "activity"
    assert html =~ "credit allowance"
    assert html =~ "Available to tip"

    view
    |> element("button", "Show details")
    |> render_click()

    assert render(view) =~ "Non-payable"
    assert render(view) =~ "Payable"
  end
end
