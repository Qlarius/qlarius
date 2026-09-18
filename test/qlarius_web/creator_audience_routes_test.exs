defmodule QlariusWeb.CreatorAudienceRoutesTest do
  use QlariusWeb.ConnCase, async: false

  import Qlarius.TargetingFixtures

  alias Qlarius.Accounts
  alias Qlarius.Creators
  alias Qlarius.Repo
  alias Qlarius.YouData.Traits.Trait

  defp initialized_user do
    ensure_trait(1, "Sex")
    ensure_trait(93, "Age")

    male =
      ensure_child_trait(1, "Male-#{System.unique_integer([:positive])}")

    age =
      ensure_child_trait(93, "25-34-#{System.unique_integer([:positive])}")

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

  test "insights and audiences pages render for a creator member", %{conn: conn} do
    user = initialized_user()
    creator = creator_fixture()
    {:ok, _} = Creators.create_creator_membership(creator.id, user.id, :owner)

    conn = log_in_user(conn, user)

    audiences = get(conn, ~p"/creators/#{creator.id}/audiences")
    assert html_response(audiences, 200) =~ "Audiences"
    assert html_response(audiences, 200) =~ "Insights"
    assert html_response(audiences, 200) =~ "Trait groups"

    trait_groups = get(conn, ~p"/creators/#{creator.id}/trait-groups")
    assert html_response(trait_groups, 200) =~ "Trait groups"
    assert html_response(trait_groups, 200) =~ "Audiences"

    insights = get(conn, ~p"/creators/#{creator.id}/insights")
    assert html_response(insights, 200) =~ "Insights"
    assert html_response(insights, 200) =~ "Recommended vs organic"
    assert html_response(insights, 200) =~ "Per-audience conversion"
    assert html_response(insights, 200) =~ "Totals only"
  end

  test "a non-member is denied", %{conn: conn} do
    user = initialized_user()
    creator = creator_fixture()

    assert_error_sent 404, fn ->
      conn
      |> log_in_user(user)
      |> get(~p"/creators/#{creator.id}/insights")
    end
  end
end
