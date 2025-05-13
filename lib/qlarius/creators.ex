defmodule Qlarius.Creators do
  import Ecto.Query

  alias Qlarius.Arcade.Catalog
  alias Qlarius.Arcade.ContentGroup
  alias Qlarius.Arcade.ContentPiece
  alias Qlarius.Arcade.Creator
  alias Qlarius.Repo

  # ---------------------------------------
  #                CREATORS
  # ---------------------------------------

  def list_creators do
    Repo.all(from c in Creator, order_by: [asc: c.name])
  end

  def get_creator!(id) do
    Repo.get!(Creator, id)
    |> Repo.preload([:catalogs])
  end

  def create_creator(attrs \\ %{}) do
    %Creator{}
    |> Creator.changeset(attrs)
    |> Repo.insert()
  end

  def update_creator(%Creator{} = creator, attrs) do
    creator
    |> Creator.changeset(attrs)
    |> Repo.update()
  end

  def delete_creator(%Creator{} = creator) do
    Repo.delete(creator)
  end

  def change_creator(%Creator{} = creator, attrs \\ %{}) do
    Creator.changeset(creator, attrs)
  end

  # ---------------------------------------
  #                CATALOGS
  # ---------------------------------------

  def list_catalogs_by_creator(creator_id) do
    Repo.all(
      from c in Catalog,
        where: c.creator_id == ^creator_id,
        order_by: [asc: c.name]
    )
  end

  def get_catalog!(id) do
    Repo.get!(Catalog, id)
    |> Repo.preload([:content_groups, :creator])
  end

  def create_catalog(%Creator{} = creator, attrs \\ %{}) do
    %Catalog{creator_id: creator.id}
    |> Catalog.changeset(attrs)
    |> Repo.insert()
  end

  def update_catalog(%Catalog{} = catalog, attrs) do
    catalog
    |> Catalog.changeset(attrs)
    |> Repo.update()
  end

  def delete_catalog(%Catalog{} = catalog) do
    Repo.delete(catalog)
  end

  def change_catalog(%Catalog{} = catalog, attrs \\ %{}) do
    Catalog.changeset(catalog, attrs)
  end

  # ---------------------------------------
  #             CONTENT GROUPS
  # ---------------------------------------

  def list_content_groups_for_catalog(%Catalog{} = catalog) do
    Repo.all(
      from g in ContentGroup,
        where: g.catalog_id == ^catalog.id,
        preload: :content_pieces,
        order_by: [asc: g.title]
    )
  end

  def change_content_group(%ContentGroup{} = group, attrs \\ %{}) do
    ContentGroup.changeset(group, attrs)
  end

  def create_content_group(%Catalog{} = catalog, attrs \\ %{}) do
    %ContentGroup{catalog: catalog}
    |> ContentGroup.changeset(attrs)
    |> Repo.insert()
    |> maybe_update_image(attrs["image"])
  end

  defp maybe_update_image({:ok, group}, image) when not is_nil(image) do
    group
    |> ContentGroup.image_changeset(image)
    |> Repo.update()
  end

  defp maybe_update_image(result, _image), do: result

  def get_content_group!(id) do
    Repo.one!(from ContentGroup, where: [id: ^id])
    |> Repo.preload([:content_pieces, catalog: :creator])
    # FIXME preload the real tiqit types
    |> Map.put(:tiqit_types, [])
  end

  def update_content_group(%ContentGroup{} = group, attrs) do
    group
    |> ContentGroup.changeset(attrs)
    |> Repo.update()
    |> maybe_update_image(attrs["image"])
  end

  def delete_content_group(%ContentGroup{} = group) do
    Repo.delete(group)
  end

  # ---------------------------------------
  #             CONTENT PIECES
  # ---------------------------------------

  def get_content_piece!(id) do
    ContentPiece
    |> Repo.get!(id)
    |> Repo.preload([:tiqit_types, content_group: [catalog: :creator]])
  end

  def change_content_piece(%ContentPiece{} = piece, attrs \\ %{}) do
    ContentPiece.changeset(piece, attrs)
  end

  def create_content_piece(%ContentGroup{} = group, attrs \\ %{}) do
    %ContentPiece{content_group: group}
    |> ContentPiece.changeset(attrs)
    |> Repo.insert()
  end

  def update_content_piece(%ContentPiece{} = piece, attrs) do
    piece
    |> ContentPiece.changeset(attrs)
    |> Repo.update()
  end

  def delete_content_piece(%ContentPiece{} = piece) do
    Repo.delete(piece)
  end
end
