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
