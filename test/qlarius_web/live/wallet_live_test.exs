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

  test "leads with spendable and opens the breakdown on Details", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/wallet")
    html = render_async(view)

    assert html =~ "spendable"
    assert html =~ "$2.00"
    assert html =~ "Details"
    refute html =~ "wallet-details--open"

    view |> element("button.wallet-summary__toggle") |> render_click()

    html = render(view)
    assert html =~ "wallet-details--open"
    assert html =~ "in-app"
    assert html =~ "cashable"
    assert html =~ "spending allowance"

    view |> element("button.wallet-summary__toggle") |> render_click()
    refute render(view) =~ "wallet-details--open"
  end

  describe "Activity Ledger views" do
    setup %{user: user} do
      user = Repo.preload(user, :me_file)
      header = Wallets.get_me_file_ledger_header(user.me_file)

      Repo.transaction(fn ->
        for n <- 1..35 do
          Wallets.apply_credit!(header, Decimal.new("0.01"), %{
            description: "LEDGER AD #{n}",
            meta_1: "Banner Tap"
          })
        end
      end)

      :ok
    end

    test "By day shows 30 entries under day labels, and Show more adds the rest", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/wallet")
      html = render_async(view)

      assert html =~ "Today"
      assert length(Regex.scan(~r/class="ledger-row"/, html)) == 30
      assert html =~ "Show more"

      html = view |> element("button.ledger-more") |> render_click()

      assert length(Regex.scan(~r/class="ledger-row"/, html)) == 35
      refute html =~ "Show more"
    end

    test "By page is a pager of 20 that lives in the URL", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/wallet?view=pages&page=2")
      html = render_async(view)

      assert html =~ "Page 2 of 2"
      assert length(Regex.scan(~r/class="ledger-row"/, html)) == 15
      refute html =~ "Show more"

      view |> element("button[phx-value-mode='day']") |> render_click()
      assert_patch(view, ~p"/wallet")
    end
  end

  test "refreshes ledger and available-to-spend on wallet balance PubSub", %{
    conn: conn,
    user: user
  } do
    {:ok, view, _html} = live(conn, ~p"/wallet")
    html = render_async(view)
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
    {:ok, view, _html} = live(conn, ~p"/wallet")
    html = render_async(view)
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
