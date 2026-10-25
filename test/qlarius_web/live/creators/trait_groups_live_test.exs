defmodule QlariusWeb.Creators.TraitGroupsLiveTest do
  use QlariusWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Qlarius.MeCPFixtures
  import Qlarius.TargetingFixtures

  alias Qlarius.Accounts
  alias Qlarius.Creators
  alias Qlarius.Repo
  alias Qlarius.YouData.Surveys.{SurveyAnswer, SurveyQuestion}
  alias Qlarius.YouData.Traits
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

  setup %{conn: conn} do
    user = initialized_user()
    creator = creator_fixture()
    {:ok, _} = Creators.create_creator_membership(creator.id, user.id, :owner)

    %{conn: log_in_user(conn, user), creator: creator}
  end

  test "trait browser search finds a parent from a child answer", %{conn: conn, creator: creator} do
    token = "dnc#{System.unique_integer([:positive])}"
    category = insert_category!("Hobbies")
    pastimes = insert_trait!(category, "Pastimes #{token}")
    insert_trait!(nil, "#{token}dance", parent_trait_id: pastimes.id)
    decoy = insert_trait!(category, "College Attendance #{token}")

    {:ok, view, _html} = live(conn, ~p"/creators/#{creator.id}/trait-groups")

    html =
      view
      |> element("form[phx-change='search_traits']")
      |> render_change(%{"search" => "#{token}dance"})

    assert html =~ pastimes.trait_name
    refute html =~ decoy.trait_name
  end

  test "first trait checkbox change stays selected", %{conn: conn, creator: creator} do
    parent = parent_trait_fixture("Home Properties")
    basement = trait_fixture(parent, "Basement")

    {:ok, view, html} =
      live(conn, ~p"/creators/#{creator.id}/trait-groups/new?parent_trait_id=#{parent.id}")

    assert html =~ "Create Trait Group"
    assert html =~ "Basement"
    refute html =~ ~r/id="trait-#{basement.id}"[^>]*checked/

    html =
      view
      |> element("#trait-group-form")
      |> render_change(%{
        "_target" => ["trait_ids"],
        "trait_ids" => [Integer.to_string(basement.id)]
      })

    assert html =~ ~r/id="trait-#{basement.id}"[^>]*checked/
    assert has_element?(view, "#trait-#{basement.id}[checked]")
  end

  test "a group gains and loses a second topic from its card", %{conn: conn, creator: creator} do
    diet = parent_trait_fixture("Diet")
    vegan = trait_fixture(diet, "Vegan")
    pets = parent_trait_fixture("Pets")
    dog = trait_fixture(pets, "Dog")
    group = trait_group_fixture(%{creator_id: creator.id}, [vegan])

    {:ok, view, html} = live(conn, ~p"/creators/#{creator.id}/trait-groups")
    refute html =~ "Matches anyone with any of these answers"

    view |> element("#trait-group-#{group.id} button", "Add topic") |> render_click()
    assert has_element?(view, "#adding-topic-banner", group.title)

    view
    |> element(
      "a[href='/creators/#{creator.id}/trait-groups/#{group.id}/topics/#{diet.id}']",
      "Edit"
    )
    |> render_click()

    assert render(view) =~ "Edit #{group.title}"
    view |> element("#trait-group-form button", "Cancel") |> render_click()

    view |> element("#trait-group-#{group.id} button", "Add topic") |> render_click()
    render_patch(view, ~p"/creators/#{creator.id}/trait-groups/#{group.id}/topics/#{pets.id}")
    assert render(view) =~ "Add topic to #{group.title}"

    view
    |> form("#trait-group-form", %{"trait_group" => %{"title" => group.title}})
    |> render_submit(%{"trait_ids" => [Integer.to_string(dog.id)]})

    html = render(view)
    assert html =~ "Matches anyone with any of these answers"
    assert has_element?(view, "#trait-group-#{group.id}-topic-#{pets.id}")
    assert is_nil(Repo.reload!(group).parent_trait_id)

    view
    |> element("#trait-group-#{group.id}-topic-#{pets.id} button[phx-click='remove_topic']")
    |> render_click()

    refute has_element?(view, "#trait-group-#{group.id}-topic-#{pets.id}")
    assert Repo.reload!(group).parent_trait_id == diet.id
  end

  test "editing a topic preselects its answers", %{conn: conn, creator: creator} do
    diet = parent_trait_fixture("Diet")
    vegan = trait_fixture(diet, "Vegan")
    _keto = trait_fixture(diet, "Keto")
    group = trait_group_fixture(%{creator_id: creator.id}, [vegan])

    {:ok, view, _html} =
      live(conn, ~p"/creators/#{creator.id}/trait-groups/#{group.id}/topics/#{diet.id}")

    assert render(view) =~ "Edit #{group.title}"
    assert has_element?(view, "#trait-#{vegan.id}[checked]")
  end

  test "the new-group modal can create an Anti-Trait Group; topic edits cannot change the role",
       %{conn: conn, creator: creator} do
    diet = parent_trait_fixture("Diet")
    vegan = trait_fixture(diet, "Vegan")

    {:ok, view, html} =
      live(conn, ~p"/creators/#{creator.id}/trait-groups/new?parent_trait_id=#{diet.id}")

    assert html =~ "Create as Anti-Trait Group"

    view
    |> form("#trait-group-form", %{"trait_group" => %{"title" => "No vegans", "role" => "anti"}})
    |> render_submit(%{"trait_ids" => [Integer.to_string(vegan.id)]})

    [group] = Traits.list_trait_groups_for_owner({:creator, creator.id})
    assert group.role == "anti"

    html = render(view)
    assert html =~ ~s(aria-label="keep out")
    assert html =~ "Removes anyone with one of these answers"
    assert html =~ "MeFiles removed"

    render_patch(view, ~p"/creators/#{creator.id}/trait-groups/#{group.id}/topics/#{diet.id}")
    refute render(view) =~ "Create as Anti-Trait Group"
  end

  test "the role filter appears once an anti-group exists", %{conn: conn, creator: creator} do
    diet = parent_trait_fixture("Diet")
    include = trait_group_fixture(%{creator_id: creator.id}, [trait_fixture(diet, "Keto")])

    {:ok, _view, html} = live(conn, ~p"/creators/#{creator.id}/trait-groups")
    refute html =~ "Filter by role"

    anti = anti_trait_group_fixture(%{creator_id: creator.id}, [trait_fixture(diet, "Vegan")])

    {:ok, view, html} = live(conn, ~p"/creators/#{creator.id}/trait-groups")
    assert html =~ "Filter by role"

    view |> element("button[phx-value-role='anti']") |> render_click()
    assert has_element?(view, "#trait-group-#{anti.id}")
    refute has_element?(view, "#trait-group-#{include.id}")

    view |> element("button[phx-value-role='include']") |> render_click()
    assert has_element?(view, "#trait-group-#{include.id}")
    refute has_element?(view, "#trait-group-#{anti.id}")
  end

  test "answers start as the short trait name and expand to the survey wording", %{
    conn: conn,
    creator: creator
  } do
    parent = parent_trait_fixture("Daily Diet")
    variety = trait_fixture(parent, "Variety eater")

    question =
      Repo.insert!(%SurveyQuestion{
        text: "Describe your daily meal.",
        trait_id: parent.id,
        active: "1",
        display_order: 1,
        added_by: 0,
        modified_by: 0
      })

    Repo.insert!(%SurveyAnswer{
      text: "Mixes a variety of foods without strict rules.",
      survey_question_id: question.id,
      trait_id: variety.id,
      display_order: 1,
      added_by: 0,
      modified_by: 0
    })

    {:ok, view, _html} =
      live(conn, ~p"/creators/#{creator.id}/trait-groups/new?parent_trait_id=#{parent.id}")

    assert has_element?(view, "#trait-#{variety.id} ~ div", "Variety eater")
    refute has_element?(view, "#trait-#{variety.id} ~ div .text-sm", "Mixes a variety")
    assert has_element?(view, "button", "Simple")

    view |> element("button", "Expanded") |> render_click()

    assert has_element?(
             view,
             "#trait-#{variety.id} ~ div .text-sm",
             "Mixes a variety of foods without strict rules."
           )
  end
end
