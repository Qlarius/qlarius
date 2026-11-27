defmodule QlariusWeb.Admin.MeFileInspectorLiveTest do
  use QlariusWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Qlarius.Accounts
  alias Qlarius.Repo
  alias Qlarius.YouData.MeFiles.MeFileTag
  alias Qlarius.YouData.Traits.Trait

  setup %{conn: conn} do
    admin =
      register!("inspector-admin")
      |> Ecto.Changeset.change(role: "admin")
      |> Repo.update!()

    user = register!("tagged")
    user = Repo.preload(user, :me_file)

    for _ <- 1..5 do
      parent =
        Repo.insert!(%Trait{
          trait_name: "Parent #{System.unique_integer([:positive])}",
          input_type: "text",
          display_order: 1,
          modified_by: 0,
          added_by: 0
        })

      child =
        Repo.insert!(%Trait{
          parent_trait_id: parent.id,
          trait_name: "Child #{System.unique_integer([:positive])}",
          input_type: "text",
          display_order: 1,
          modified_by: 0,
          added_by: 0
        })

      Repo.insert!(%MeFileTag{
        me_file_id: user.me_file.id,
        trait_id: child.id,
        added_by: user.id,
        modified_by: user.id
      })
    end

    %{conn: log_in_user(conn, admin), user: user}
  end

  test "lists a MeFile with its tag count and the rich-file average", %{conn: conn, user: user} do
    {:ok, view, html} = live(conn, ~p"/admin/mefile_inspector")

    assert html =~ "6.0"
    assert row_text(html, user.alias) =~ "6"

    sorted = view |> element("button", "Tags") |> render_click()
    assert row_text(sorted, user.alias) =~ "6"

    by_offers = view |> element("button", "Active offers") |> render_click()
    assert row_text(by_offers, user.alias) =~ "6"
  end

  defp row_text(html, alias) do
    html
    |> Floki.parse_document!()
    |> Floki.find("tbody tr")
    |> Enum.find(fn row -> Floki.text(row) =~ alias end)
    |> Floki.text()
  end

  defp register!(prefix) do
    {:ok, %{user: user}} =
      Accounts.register_new_user(%{
        alias: "#{prefix}-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01]
      })

    user
  end
end
