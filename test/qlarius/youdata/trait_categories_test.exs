defmodule Qlarius.YouData.TraitCategoriesTest do
  use Qlarius.DataCase, async: true

  alias Qlarius.Accounts.{Scope, User}
  alias Qlarius.YouData.TraitCategories

  test "create and update stamp added_by and modified_by with the acting user" do
    user = Repo.insert!(%User{alias: "admin-#{System.unique_integer([:positive])}"})
    scope = %Scope{true_user: user, user: user}

    assert {:ok, category} =
             TraitCategories.create_trait_category(scope, %{
               "name" => "Regression category",
               "display_order" => 1
             })

    assert category.added_by == scope.true_user.id
    assert category.modified_by == scope.true_user.id

    assert {:ok, updated} =
             TraitCategories.update_trait_category(scope, category, %{"name" => "Renamed"})

    assert updated.name == "Renamed"
    assert updated.modified_by == scope.true_user.id
  end
end
