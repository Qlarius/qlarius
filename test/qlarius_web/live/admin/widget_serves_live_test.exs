defmodule QlariusWeb.Admin.WidgetServesLiveTest do
  use QlariusWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Qlarius.Repo
  alias Qlarius.Sponster.Recipient
  alias Qlarius.Sponster.WidgetServeLog

  @chrome "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36"

  setup %{conn: conn} do
    {:ok, %{user: user}} =
      Qlarius.Accounts.register_new_user(%{
        alias: "serves-admin-#{System.unique_integer([:positive])}"
      })

    user = user |> Ecto.Changeset.change(role: "admin") |> Repo.update!()

    alpha = recipient!(user, "Alpha Gazette")
    zulu = recipient!(user, "Zulu Times")

    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    an_hour_ago = NaiveDateTime.add(now, -3_600, :second)

    insert_logs!(alpha, 1, an_hour_ago, %{host: "alpha.example.com", ip_address: "198.51.100.1"})

    insert_logs!(zulu, 3, an_hour_ago, %{host: "zulu.example.com", ip_address: "198.51.100.2"})

    insert_logs!(zulu, 1, an_hour_ago, %{
      host: "zulu.example.com",
      ip_address: "198.51.100.3",
      user_agent: "curl/8.4.0"
    })

    %{conn: log_in_user(conn, user), alpha: alpha, zulu: zulu}
  end

  defp recipient!(user, name) do
    Repo.insert!(%Recipient{
      user_id: user.id,
      name: name,
      split_code: Ecto.UUID.generate(),
      referral_code: "serves-#{System.unique_integer([:positive])}"
    })
  end

  defp insert_logs!(recipient, count, at, overrides) do
    rows =
      for _ <- 1..count do
        Map.merge(
          %{
            recipient_id: recipient.id,
            recipient_split_code: recipient.split_code,
            host_page_url: "https://#{overrides.host}/",
            user_agent: @chrome,
            device: "Desktop",
            authed: false,
            connect_count: 1,
            page_load_id: Ecto.UUID.generate(),
            created_at: at,
            updated_at: at
          },
          overrides
        )
      end

    Repo.insert_all(WidgetServeLog, rows)
  end

  test "renders KPIs, charts, and the publisher table", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/admin/widget_serves")

    assert html =~ "Widget serves"
    assert html =~ "Loads over time"
    assert html =~ "Top hosts"
    assert html =~ "zulu.example.com"
    assert html =~ "Alpha Gazette"
    assert html =~ "Zulu Times"
    assert html =~ ~s(id="widget-serves-chart")
  end

  test "sorting the publisher table changes the order", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/admin/widget_serves?tab=publishers&sort=loads&dir=desc")
    assert position(html, "Zulu Times") < position(html, "Alpha Gazette")

    {:ok, _view, html} = live(conn, ~p"/admin/widget_serves?tab=publishers&sort=name&dir=asc")
    assert position(html, "Alpha Gazette") < position(html, "Zulu Times")

    {:ok, _view, html} =
      live(conn, ~p"/admin/widget_serves?tab=publishers&sort=bogus&dir=sideways")

    assert position(html, "Zulu Times") < position(html, "Alpha Gazette")
  end

  test "each tab loads", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/widget_serves")

    html = view |> element("#widget-serves-tab-hosts") |> render_click()
    assert html =~ "alpha.example.com"

    html = view |> element("#widget-serves-tab-suspicious") |> render_click()
    assert html =~ "Bot agent (1)"
    assert html =~ "curl/8.4.0"

    html = view |> element("#widget-serves-tab-log") |> render_click()
    assert html =~ "198.51.100.3"
    assert html =~ "Anonymous"
  end

  test "filters narrow every view and can be cleared", %{conn: conn, alpha: alpha} do
    {:ok, view, html} = live(conn, ~p"/admin/widget_serves?tab=log&recipient_id=#{alpha.id}")

    assert html =~ "198.51.100.1"
    refute html =~ "198.51.100.2"
    assert html =~ "Publisher ##{alpha.id}"

    html = view |> element("#widget-serves-filter-recipient_id") |> render_click()
    assert html =~ "198.51.100.2"

    {:ok, _view, html} = live(conn, ~p"/admin/widget_serves?tab=log&flag=bot_agent")
    assert html =~ "198.51.100.3"
    refute html =~ "198.51.100.2"
  end

  test "the period select reloads the dashboard", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/widget_serves")

    html = view |> element("#widget-serves-period") |> render_change(%{"period" => "24h"})

    assert_patch(
      view,
      ~p"/admin/widget_serves?#{%{dir: "desc", period: "24h", sort: "loads", tab: "publishers"}}"
    )

    assert html =~ "per hour"
  end

  test "non-admin users are refused" do
    {:ok, %{user: normal}} =
      Qlarius.Accounts.register_new_user(%{
        alias: "serves-user-#{System.unique_integer([:positive])}"
      })

    conn = log_in_user(build_conn(), normal)
    assert {:error, {status, _}} = live(conn, ~p"/admin/widget_serves")
    assert status in [:redirect, :live_redirect]
  end

  defp position(html, text) do
    {index, _} = :binary.match(html, text)
    index
  end
end
