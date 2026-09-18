defmodule QlariusWeb.Creators.AudiencesLiveTest do
  use QlariusWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Qlarius.TargetingFixtures

  alias Qlarius.Accounts
  alias Qlarius.Accounts.Scope
  alias Qlarius.Creators
  alias Qlarius.Repo
  alias Qlarius.Tiqit.Arcade.Catalog
  alias Qlarius.Tiqit.ContentAudiences
  alias Qlarius.YouData.Traits.Trait

  defp initialized_user do
    ensure_trait(1, "Sex")
    ensure_trait(93, "Age")

    male = ensure_child_trait(1, "Male-#{System.unique_integer([:positive])}")
    age = ensure_child_trait(93, "25-34-#{System.unique_integer([:positive])}")

    {:ok, %{user: user}} =
      Accounts.register_new_user(%{
        alias: "user-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01],
        sex_trait_id: male.id,
        age_trait_id: age.id
      })

    user
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

  defp ensure_child_trait(parent_id, name) do
    Repo.insert!(%Trait{
      parent_trait_id: parent_id,
      trait_name: name,
      input_type: "text",
      display_order: 1,
      modified_by: 0,
      added_by: 0
    })
  end

  defp catalog!(creator) do
    %Catalog{creator_id: creator.id}
    |> Catalog.changeset(%{
      name: "Cat #{System.unique_integer([:positive])}",
      url: "https://example.com/#{System.unique_integer([:positive])}",
      type: :catalog,
      group_type: :show,
      piece_type: :episode
    })
    |> Repo.insert!()
  end

  setup %{conn: conn} do
    user = initialized_user()
    creator = creator_fixture()
    {:ok, _} = Creators.create_creator_membership(creator.id, user.id, :owner)

    %{conn: log_in_user(conn, user), user: user, creator: creator, scope: Scope.for_user(user)}
  end

  test "edit renders Audience copy, not Target", %{conn: conn, creator: creator, scope: scope} do
    {:ok, target} =
      ContentAudiences.create_audience(scope, creator.id, %{title: "Show fans"})

    {:ok, _view, html} = live(conn, ~p"/creators/#{creator.id}/audiences/#{target.id}/edit")

    assert html =~ "Audience"
    assert html =~ "Show fans"
    refute html =~ "Freeze and Populate Target"
    refute html =~ "Expand Target"
  end

  test "attach query params still show attach actions", %{
    conn: conn,
    creator: creator,
    scope: scope
  } do
    {:ok, target} =
      ContentAudiences.create_audience(scope, creator.id, %{title: "Show fans"})

    catalog = catalog!(creator)

    {:ok, _view, html} =
      live(
        conn,
        ~p"/creators/#{creator.id}/audiences/#{target.id}/edit?attach=catalog&attach_id=#{catalog.id}"
      )

    assert html =~ "Attach as relevance"
    assert html =~ "Attach as restriction"
  end

  test "empty audience shows the media starter; skip hides it", %{
    conn: conn,
    creator: creator,
    scope: scope
  } do
    formats = parent_trait_fixture("Formats")
    Qlarius.System.set_global_variable("CREATOR_CONTENT_TAG_PARENT_TRAIT_IDS", "#{formats.id}")
    Qlarius.System.set_global_variable("CREATOR_AUDIENCE_TAG_PARENT_TRAIT_IDS", "")

    {:ok, target} =
      ContentAudiences.create_audience(scope, creator.id, %{title: "New audience"})

    {:ok, view, html} = live(conn, ~p"/creators/#{creator.id}/audiences/#{target.id}/edit")

    assert html =~ "Tag your content"
    assert html =~ "Add a tag"
    assert has_element?(view, "#starter-trait-#{formats.id}")

    html = view |> element("button", "Skip tagging") |> render_click()
    refute html =~ "Tag your content"
    refute has_element?(view, "#starter-trait-#{formats.id}")
  end

  test "saving Formats from the starter creates a bullseye trait group", %{
    conn: conn,
    creator: creator,
    scope: scope
  } do
    formats = parent_trait_fixture("Formats")
    podcast = trait_fixture(formats, "Podcast", 1)
    Qlarius.System.set_global_variable("CREATOR_CONTENT_TAG_PARENT_TRAIT_IDS", "#{formats.id}")
    Qlarius.System.set_global_variable("CREATOR_AUDIENCE_TAG_PARENT_TRAIT_IDS", "")

    {:ok, target} =
      ContentAudiences.create_audience(scope, creator.id, %{title: "New audience"})

    {:ok, view, _html} = live(conn, ~p"/creators/#{creator.id}/audiences/#{target.id}/edit")

    view
    |> element("#starter-trait-#{formats.id}")
    |> render_click()

    view
    |> form("form[phx-submit=save_trait_group]", %{
      "trait_group" => %{"title" => "Formats"},
      "trait_ids" => [Integer.to_string(podcast.id)]
    })
    |> render_submit()

    target = ContentAudiences.get_audience!(creator.id, target.id)
    [band] = target.target_bands
    assert band.is_bullseye == "1"
    [group] = band.trait_groups
    assert group.creator_id == creator.id
    assert group.parent_trait_id == formats.id
    assert Enum.map(group.traits, & &1.id) == [podcast.id]
  end

  test "legacy audience URL still opens the editor", %{conn: conn, creator: creator, scope: scope} do
    {:ok, target} =
      ContentAudiences.create_audience(scope, creator.id, %{title: "Legacy"})

    {:ok, _view, html} = live(conn, ~p"/creators/#{creator.id}/audiences/#{target.id}")
    assert html =~ "Audience"
    assert html =~ "Legacy"
  end
end
