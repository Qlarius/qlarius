defmodule QlariusWeb.Admin.ProxyUsersLiveTest do
  use QlariusWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Qlarius.Accounts
  alias Qlarius.Accounts.{User, UserProxy}
  alias Qlarius.Repo
  alias Qlarius.YouData.MeFiles.MeFile

  setup %{conn: conn} do
    admin =
      register!("proxy-admin")
      |> Ecto.Changeset.change(role: "admin")
      |> Repo.update!()

    true_user = register!("owner")
    proxy_user = register!("persona", true_user_id: true_user.id)

    link =
      Repo.insert!(%UserProxy{
        true_user_id: true_user.id,
        proxy_user_id: proxy_user.id,
        active: true
      })

    %{conn: log_in_user(conn, admin), link: link, proxy_user: proxy_user, true_user: true_user}
  end

  test "lists proxies with throttle and offer counts", %{conn: conn} = ctx do
    {:ok, _view, html} = live(conn, ~p"/admin/proxy_users")

    assert html =~ ctx.proxy_user.alias
    assert html =~ ctx.true_user.alias
    assert html =~ "25 per 0 days"
    assert html =~ "0 active of 0"
  end

  test "saves alias and throttle", %{conn: conn, link: link, proxy_user: proxy_user} do
    {:ok, view, _html} = live(conn, ~p"/admin/proxy_users/#{link.id}")
    new_alias = "renamed-#{System.unique_integer([:positive])}"

    html =
      view
      |> form("#proxy-form",
        proxy: %{alias: new_alias, throttle_ad_count: "9", throttle_days: "3"}
      )
      |> render_submit()

    assert html =~ "Proxy saved."
    assert Repo.get!(User, proxy_user.id).alias == new_alias

    assert %{throttle_ad_count: 9, throttle_days: 3} =
             Repo.get_by!(MeFile, user_id: proxy_user.id)
  end

  test "shows an error for a taken alias", %{conn: conn, link: link, true_user: true_user} do
    {:ok, view, _html} = live(conn, ~p"/admin/proxy_users/#{link.id}")

    html =
      view
      |> form("#proxy-form",
        proxy: %{alias: true_user.alias, throttle_ad_count: "9", throttle_days: "3"}
      )
      |> render_submit()

    assert html =~ "has already been taken"
  end

  test "shows an error for an out-of-range throttle", %{conn: conn, link: link} do
    {:ok, view, _html} = live(conn, ~p"/admin/proxy_users/#{link.id}")

    html =
      view
      |> form("#proxy-form", proxy: %{throttle_ad_count: "-1", throttle_days: "3"})
      |> render_submit()

    assert html =~ "Check the fields and try again."
  end

  test "reset offers reports all and active counts", %{conn: conn, link: link} do
    {:ok, view, _html} = live(conn, ~p"/admin/proxy_users/#{link.id}")

    html = view |> element("#reset-offers") |> render_click()

    assert html =~ "Offers reset: 0 offers, 0 active."
    assert html =~ "All offers"
    assert html =~ "Active offers"
  end

  defp register!(prefix, extra \\ []) do
    {:ok, %{user: user}} =
      Accounts.register_new_user(
        Map.merge(
          %{
            alias: "#{prefix}-#{System.unique_integer([:positive])}",
            date_of_birth: ~D[1990-01-01]
          },
          Map.new(extra)
        )
      )

    user
  end
end
