defmodule Qlarius.MeCPFixtures do
  @moduledoc """
  Test helpers for MeCP: seed a MeFile with categorized tags plus a client
  and grant. Legacy YouData tables carry audit NOT NULLs, so these insert
  structs directly rather than going through changesets.
  """

  alias Qlarius.MeCP.{Clients, Grants}
  alias Qlarius.Repo
  alias Qlarius.YouData.MeFiles.{MeFile, MeFileTag}
  alias Qlarius.YouData.Traits.{Trait, TraitCategory}

  def insert_category!(name) do
    Repo.insert!(%TraitCategory{
      name: "#{name} #{System.unique_integer([:positive])}",
      display_order: 1,
      modified_by: 0,
      added_by: 0
    })
  end

  def insert_trait!(category, name, opts \\ []) do
    Repo.insert!(%Trait{
      trait_name: name,
      input_type: "text",
      display_order: Keyword.get(opts, :display_order, 1),
      trait_category_id: category && category.id,
      parent_trait_id: Keyword.get(opts, :parent_trait_id),
      modified_by: 0,
      added_by: 0
    })
  end

  def insert_tag!(me_file, trait, value) do
    Repo.insert!(%MeFileTag{
      me_file_id: me_file.id,
      trait_id: trait.id,
      tag_value: value,
      modified_by: 0,
      added_by: 0
    })
  end

  def insert_client!(attrs \\ %{}) do
    {:ok, client} =
      attrs
      |> Enum.into(%{name: "Test Client", client_type: "qai", status: "active"})
      |> Clients.create_client()

    client
  end

  def insert_grant!(me_file, client, attrs) do
    {:ok, grant} =
      attrs
      |> Enum.into(%{me_file_id: me_file.id, mecp_client_id: client.id, tier: 3})
      |> Grants.create_grant()

    grant
  end

  @doc """
  One MeFile with two categories: Demographics (Housing trait, value "Renter")
  and Lifestyle (Pets trait, value "Dog"). Grant built with `grant_attrs`;
  pass `client:` to control the client record.
  """
  def seed!(grant_attrs, opts \\ []) do
    me_file = Repo.insert!(%MeFile{})
    demo = insert_category!("Demographics")
    lifestyle = insert_category!("Lifestyle")
    housing = insert_trait!(demo, "Housing")
    pets = insert_trait!(lifestyle, "Pets")
    insert_tag!(me_file, housing, "Renter")
    insert_tag!(me_file, pets, "Dog")

    client = Keyword.get_lazy(opts, :client, fn -> insert_client!() end)
    grant = insert_grant!(me_file, client, grant_attrs)

    %{
      me_file: me_file,
      housing: housing,
      pets: pets,
      demo: demo,
      lifestyle: lifestyle,
      client: client,
      grant: grant
    }
  end
end
