defmodule Qlarius.WidgetAuthFixtures do
  @moduledoc """
  A fully registered user (sex/age traits + MeFile) for widget auth tests.
  `Qlarius.AccountsFixtures.user_fixture/0` predates the mobile-number
  registration flow and no longer works; `Accounts.register_new_user/1`
  needs the two seed traits to exist.
  """

  alias Qlarius.Accounts
  alias Qlarius.Repo
  alias Qlarius.YouData.Traits.Trait

  @traits [
    %{id: 1, trait_name: "Sex"},
    %{id: 93, trait_name: "Age"},
    %{id: 200_001, parent_trait_id: 1, trait_name: "Male"},
    %{id: 200_093, parent_trait_id: 93, trait_name: "25-34"}
  ]

  def registered_user_fixture(attrs \\ %{}) do
    ensure_traits!()

    {:ok, %{user: user}} =
      attrs
      |> Enum.into(%{
        alias: "widget-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01],
        sex_trait_id: 200_001,
        age_trait_id: 200_093
      })
      |> Accounts.register_new_user()

    user
  end

  defp ensure_traits! do
    Enum.each(@traits, fn attrs ->
      unless Repo.get(Trait, attrs.id) do
        Repo.insert!(
          struct(
            Trait,
            Map.merge(%{input_type: "text", display_order: 1, modified_by: 0, added_by: 0}, attrs)
          )
        )
      end
    end)
  end
end
