defmodule QlariusWeb.WalletLiveTest do
  use QlariusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Qlarius.Accounts
  alias Qlarius.Repo
  alias Qlarius.Wallets
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

  test "shows spendable, activity, and credit float", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/wallet")

    assert html =~ "spendable"
    assert html =~ "$2.00"
    assert html =~ "activity"
    assert html =~ "credit float"
    refute html =~ "tip-able"

    view
    |> element("button[aria-label='Show wallet details']")
    |> render_click()

    html = render(view)
    assert html =~ "in-app"
    assert html =~ "cashable"
    assert html =~ "tip-able"
  end

  test "refreshes ledger and available-to-spend on wallet balance PubSub", %{
    conn: conn,
    user: user
  } do
    {:ok, view, html} = live(conn, ~p"/wallet")
    refute html =~ "PUBSUB AD"
    refute html =~ "$2.50"

    user = Repo.preload(user, :me_file)
    header = Wallets.get_me_file_ledger_header(user.me_file)

    Repo.transaction(fn ->
      Wallets.apply_credit!(header, Decimal.new("0.50"), %{
        description: "PUBSUB AD",
        meta_1: "Banner Tap"
      })
    end)

    send(view.pid, :update_balance)

    html = render(view)
    assert html =~ "PUBSUB AD"
    assert html =~ "$2.50"
  end

  test "header pill does not double-count credit after stacked balance PubSub", %{
    conn: conn,
    user: user
  } do
    {:ok, view, html} = live(conn, ~p"/wallet")
    refute html =~ "$2.50"
    refute html =~ "$4.50"

    user = Repo.preload(user, :me_file)
    header = Wallets.get_me_file_ledger_header(user.me_file)

    Repo.transaction(fn ->
      Wallets.apply_credit!(header, Decimal.new("0.50"), %{
        description: "PUBSUB AD",
        meta_1: "Banner Tap"
      })
    end)

    send(view.pid, {:me_file_balance_updated, Decimal.new("2.50")})
    send(view.pid, :update_balance)

    html = render(view)
    assert html =~ "$2.50"
    refute html =~ "$4.50"
  end
end
