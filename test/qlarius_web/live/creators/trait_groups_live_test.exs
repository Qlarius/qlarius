defmodule QlariusWeb.Creators.TraitGroupsLiveTest do
  use QlariusWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Qlarius.TargetingFixtures

  alias Qlarius.Accounts
  alias Qlarius.Creators
  alias Qlarius.Repo
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

  test "first trait checkbox change stays selected", %{conn: conn, creator: creator} do
    parent = parent_trait_fixture("Home Properties")
    basement = trait_fixture(parent, "Basement")

    {:ok, view, html} =
      live(conn, ~p"/creators/#{creator.id}/trait-groups/new?parent_trait_id=#{parent.id}")

    assert html =~ "Create Trait Group"
    assert html =~ "Basement"
    refute html =~ ~r/id="trait-#{basement.id}"[^>]*checked/

    html =
      render_change(view, "validate_trait_group", %{
        "_target" => ["trait_ids"],
        "trait_ids" => [Integer.to_string(basement.id)]
      })

    assert html =~ ~r/id="trait-#{basement.id}"[^>]*checked/
    assert has_element?(view, "#trait-#{basement.id}[checked]")
  end
end
