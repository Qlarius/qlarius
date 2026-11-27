defmodule QlariusWeb.Widgets.AdsExtDrawerPreloadTest do
  use QlariusWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Qlarius.Accounts
  alias Qlarius.Repo
  alias Qlarius.Sponster.Recipient

  setup %{conn: conn} do
    {:ok, %{user: user}} =
      Accounts.register_new_user(%{
        alias: "drawer-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01]
      })

    recipient =
      Repo.insert!(%Recipient{
        user_id: user.id,
        name: "Drawer publisher",
        split_code: Ecto.UUID.generate(),
        referral_code: "drawer-#{System.unique_integer([:positive])}"
      })

    %{conn: log_in_user(conn, user), recipient: recipient}
  end

  test "the first open shows the drawer before the offer query finishes", %{
    conn: conn,
    recipient: recipient
  } do
    {:ok, view, html} = live(conn, "/widgets/ads_ext/#{recipient.split_code}")

    refute html =~ "bottom-[50px]"

    opened = view |> element("#ads-ext-sponster-drawer-toggle") |> render_click()

    assert opened =~ "bottom-[50px]"

    settled = wait_until(view, 20, &(&1 =~ "No ads available right now."))
    assert settled =~ "bottom-[50px]"
    refute settled =~ "loading-spinner"
  end

  defp wait_until(view, 0, _ready?), do: render(view)

  defp wait_until(view, attempts, ready?) do
    html = render(view)

    if ready?.(html) do
      html
    else
      Process.sleep(50)
      wait_until(view, attempts - 1, ready?)
    end
  end
end
