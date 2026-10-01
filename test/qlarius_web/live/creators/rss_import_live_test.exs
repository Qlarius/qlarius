defmodule QlariusWeb.Creators.RssImportLiveTest do
  use QlariusWeb.ConnCase, async: false

  import Ecto.Query
  import Phoenix.LiveViewTest
  import Qlarius.ContentImportHelpers

  alias Qlarius.Accounts
  alias Qlarius.Repo
  alias Qlarius.Tiqit.Arcade.{ContentGroup, ContentPiece, RssImporter}
  alias Qlarius.YouData.Traits.Trait

  setup %{conn: conn} do
    Req.Test.set_req_test_to_shared()
    stub_feed()
    %{conn: conn, catalog: podcast_catalog_fixture()}
  end

  test "non-admins are sent away", %{conn: conn, catalog: catalog} do
    conn = log_in_user(conn, initialized_user("user"))

    assert {:error, {:redirect, %{to: "/creators"}}} =
             live(conn, ~p"/creators/#{catalog.creator_id}/rss_import")
  end

  test "an admin imports one season into a new group", %{conn: conn, catalog: catalog} do
    conn = log_in_user(conn, initialized_user("admin"))
    {:ok, view, _html} = live(conn, ~p"/creators/#{catalog.creator_id}/rss_import")

    view |> form("form[phx-submit=lookup]", feed_url: feed_url()) |> render_submit()
    html = render_async(view)

    assert html =~ "Texas Monthly True Crime"
    assert html =~ "Episode 1: The Crime"
    assert html =~ "No https audio"
    refute html =~ "An older season."

    view |> element("button", "Continue") |> render_click()

    view
    |> form("form[phx-submit=continue_to_confirm]", group_title: "Shane and Sally")
    |> render_change()

    html = view |> form("form[phx-submit=continue_to_confirm]") |> render_submit()
    assert html =~ "Confirm import"

    view |> element("button", "Import now") |> render_click()
    html = render_async(view)
    assert html =~ "Import complete"
    assert html =~ "3 new"

    group = Repo.get_by!(ContentGroup, catalog_id: catalog.id, title: "Shane and Sally")
    assert group.feed_season == 3

    assert Repo.aggregate(from(p in ContentPiece, where: p.content_group_id == ^group.id), :count) ==
             3
  end

  test "a group with a feed can sync and toggle daily sync", %{conn: conn, catalog: catalog} do
    {:ok, detail} =
      RssImporter.import_feed(%{
        "feed_url" => feed_url(),
        "catalog_id" => catalog.id,
        "season" => 3,
        "guids" => ["tm-s3-trailer"]
      })

    conn = log_in_user(conn, initialized_user("admin"))
    {:ok, view, html} = live(conn, ~p"/creators/content_groups/#{detail.content_group.id}")
    assert html =~ "Podcast feed"
    assert html =~ "Import from RSS"

    view |> element("button", "Sync now") |> render_click()
    assert render_async(view) =~ "Feed synced: 2 new"

    view |> element("input[phx-click=toggle_feed_auto_sync]") |> render_click()
    assert Repo.get!(ContentGroup, detail.content_group.id).feed_auto_sync
  end

  defp initialized_user(role) do
    male = child_trait(ensure_trait(1, "Sex"), "Male")
    age = child_trait(ensure_trait(93, "Age"), "25-34")

    {:ok, %{user: user}} =
      Accounts.register_new_user(%{
        alias: "rss-#{role}-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01],
        sex_trait_id: male.id,
        age_trait_id: age.id
      })

    user |> Ecto.Changeset.change(role: role) |> Repo.update!()
  end

  defp ensure_trait(id, name) do
    Repo.get(Trait, id) ||
      Repo.insert!(%Trait{
        id: id,
        trait_name: name,
        input_type: "text",
        display_order: 1,
        modified_by: 0,
        added_by: 0
      })
  end

  defp child_trait(parent, name) do
    Repo.insert!(%Trait{
      parent_trait_id: parent.id,
      trait_name: "#{name}-#{System.unique_integer([:positive])}",
      input_type: "text",
      display_order: 1,
      modified_by: 0,
      added_by: 0
    })
  end
end
