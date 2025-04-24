defmodule Qlarius.Creators do
  import Ecto.Query

  alias Qlarius.Accounts.User
  alias Qlarius.Accounts.Scope
  alias Qlarius.Arcade.ContentGroup
  alias Qlarius.Arcade.ContentPiece
  alias Qlarius.Arcade.Tiqit
  alias Qlarius.Arcade.TiqitType
  alias Qlarius.Wallets.LedgerEntry
  alias Qlarius.Wallets.LedgerHeader
  alias Qlarius.Repo
  alias Qlarius.Arcade.Creator
  alias Qlarius.Arcade.Catalog

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

  def create_creator(%Scope{} = scope, attrs \\ %{}) do
    %Creator{}
    |> Creator.changeset(attrs, scope)
    |> Repo.insert()
  end

  def update_creator(%Scope{} = scope, %Creator{} = creator, attrs) do
    creator
    |> Creator.changeset(attrs, scope)
    |> Repo.update()
  end

  def delete_creator(%Creator{} = creator) do
    Repo.delete(creator)
  end

  def change_creator(%Creator{} = creator, attrs \\ %{}, scope \\ nil) do
    Creator.changeset(creator, attrs, scope)
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
  end

  def create_catalog(%Scope{} = scope, attrs \\ %{}, %Creator{} = creator) do
    %Catalog{creator_id: creator.id}
    |> Catalog.changeset(attrs, scope)
    |> Repo.insert()
  end

  def update_catalog(%Scope{} = scope, %Catalog{} = catalog, attrs) do
    catalog
    |> Catalog.changeset(attrs, scope)
    |> Repo.update()
  end

  def delete_catalog(%Catalog{} = catalog) do
    Repo.delete(catalog)
  end

  def change_catalog(%Catalog{} = catalog, attrs \\ %{}, scope \\ nil) do
    Catalog.changeset(catalog, attrs, scope)
  end

  # ---------------------------------------
  #             CONTENT GROUPS
  # ---------------------------------------

  def list_content_groups(%Scope{} = scope) do
    Repo.all(
      from g in ContentGroup,
        where: g.creator_id == ^scope.user.id,
        preload: :content_pieces,
        order_by: [asc: g.title]
    )
  end

  def change_content_group(%ContentGroup{} = group, attrs \\ %{}) do
    ContentGroup.changeset(group, attrs)
  end

  def create_content_group(%Scope{} = scope, attrs \\ %{}) do
    %ContentGroup{creator: scope.user}
    |> ContentGroup.changeset(attrs)
    |> Repo.insert()
  end

  def get_content_group!(%Scope{} = scope, id) do
    Repo.one!(from ContentGroup, where: [id: ^id, creator_id: ^scope.user.id])
    |> Repo.preload(content_pieces: :tiqit_types)
  end

  def update_content_group(
        %Scope{user: %{id: uid}},
        %ContentGroup{creator_id: uid} = group,
        attrs
      ) do
    group
    |> ContentGroup.changeset(attrs)
    |> Repo.update()
  end

  def delete_content_group(%Scope{user: %{id: uid}}, %ContentGroup{creator_id: uid} = group) do
    Repo.delete(group)
  end

  # ---------------------------------------
  #             CONTENT PIECES
  # ---------------------------------------

  def change_content_piece(%ContentPiece{} = piece, attrs \\ %{}) do
    ContentPiece.changeset(piece, attrs)
  end

  def create_content_piece(%Scope{} = scope, %ContentGroup{} = group, attrs \\ %{}) do
    if group.creator_id != scope.user.id do
      raise "not allowed"
    end

    %ContentPiece{creator: scope.user, content_groups: [group]}
    |> ContentPiece.changeset(attrs)
    |> Repo.insert()
  end

  def update_content_piece(%Scope{} = scope, %ContentPiece{} = piece, attrs) do
    if piece.creator_id != scope.user.id do
      raise "not allowed"
    end

    piece
    |> ContentPiece.changeset(attrs)
    |> Repo.update()
  end
end
