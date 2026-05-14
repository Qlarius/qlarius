defmodule Qlarius.Tiqit.Arcade.Creators do
  import Ecto.Query

  alias Qlarius.Tiqit.Arcade.Catalog
  alias Qlarius.Tiqit.Arcade.ContentGroup
  alias Qlarius.Tiqit.Arcade.ContentPiece
  alias Qlarius.Tiqit.Arcade.Creator
  alias Qlarius.Tiqit.Arcade.TiqitClass
  alias Qlarius.Tiqit.Arcade.Tiqit
  alias Qlarius.Wallets.LedgerEntry
  alias Qlarius.Repo

  # ---------------------------------------
  #                CREATORS
  # ---------------------------------------

  def list_creators do
    Repo.all(from c in Creator, order_by: [asc: c.name])
  end

  def get_creator!(id) do
    Repo.get!(Creator, id)
    |> Repo.preload(
      catalogs: [
        :content_groups,
        :tiqit_classes,
        content_groups: [:content_pieces, :tiqit_classes]
      ]
    )
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

  def delete_creator_image(%Creator{} = creator) do
    creator
    |> Ecto.Changeset.change(%{image: nil})
    |> Repo.update()
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
    |> Repo.preload([
      :content_groups,
      :creator,
      :tiqit_classes,
      content_groups: [:tiqit_classes, content_pieces: :tiqit_classes]
    ])
  end

  def create_catalog(%Creator{} = creator, attrs \\ %{}) do
    changeset_fn =
      if Map.has_key?(attrs, "image"),
        do: &Catalog.changeset_with_image/2,
        else: &Catalog.changeset/2

    %Catalog{creator_id: creator.id}
    |> changeset_fn.(attrs)
    |> Repo.insert()
  end

  def update_catalog(%Catalog{} = catalog, attrs) do
    changeset_fn =
      if Map.has_key?(attrs, "image"),
        do: &Catalog.changeset_with_image/2,
        else: &Catalog.changeset/2

    catalog
    |> changeset_fn.(attrs)
    |> Repo.update()
  end

  def delete_catalog(%Catalog{} = catalog) do
    Repo.delete(catalog)
  end

  def delete_catalog_image(%Catalog{} = catalog) do
    catalog
    |> Ecto.Changeset.change(%{image: nil})
    |> Repo.update()
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
    changeset_fn =
      if Map.has_key?(attrs, "image"),
        do: &ContentGroup.changeset_with_image/2,
        else: &ContentGroup.changeset/2

    %ContentGroup{catalog: catalog}
    |> changeset_fn.(attrs)
    |> Repo.insert()
  end

  def get_content_group!(id) do
    ContentGroup
    |> Repo.get!(id)
    |> Repo.preload([:tiqit_classes, content_pieces: [:tiqit_classes], catalog: :creator])
  end

  def update_content_group(%ContentGroup{} = group, attrs) do
    changeset_fn =
      if Map.has_key?(attrs, "image"),
        do: &ContentGroup.changeset_with_image/2,
        else: &ContentGroup.changeset/2

    group
    |> changeset_fn.(attrs)
    |> Repo.update()
  end

  def delete_content_group(%ContentGroup{} = group) do
    Repo.delete(group)
  end

  def delete_content_group_image(%ContentGroup{} = group) do
    group
    |> Ecto.Changeset.change(%{image: nil})
    |> Repo.update()
  end

  # ---------------------------------------
  #             CONTENT PIECES
  # ---------------------------------------

  def get_content_piece!(id) do
    ContentPiece
    |> Repo.get!(id)
    |> Repo.preload([:tiqit_classes, content_group: [catalog: :creator]])
  end

  def change_content_piece(%ContentPiece{} = piece, attrs \\ %{}) do
    ContentPiece.changeset(piece, attrs)
  end

  def create_content_piece(%ContentGroup{} = group, attrs \\ %{}) do
    changeset_fn =
      if Map.has_key?(attrs, "image"),
        do: &ContentPiece.changeset_with_image/2,
        else: &ContentPiece.changeset/2

    attrs = put_next_display_order_if_absent(group, attrs)

    %ContentPiece{content_group: group}
    |> changeset_fn.(attrs)
    |> Repo.insert()
  end

  @doc """
  Next `display_order` for a new piece in this group (max + 1, or 0 if empty).
  """
  def next_content_piece_display_order(%ContentGroup{id: gid}) do
    agg =
      Repo.one(
        from p in ContentPiece,
          where: p.content_group_id == ^gid and is_nil(p.archived_at),
          select: max(p.display_order)
      )

    (agg || -1) + 1
  end

  @doc """
  Persists `display_order` as 0..n-1 for the given list order (must match
  the group's current pieces exactly).
  """
  def restripe_content_pieces(%ContentGroup{id: gid} = group, ordered_pieces)
      when is_list(ordered_pieces) do
    active = Enum.reject(group.content_pieces, & &1.archived_at)
    expected = active |> Enum.map(& &1.id) |> MapSet.new()
    ids = ordered_pieces |> Enum.map(& &1.id) |> MapSet.new()

    cond do
      MapSet.size(ids) != MapSet.size(expected) ->
        {:error, :invalid_piece_set}

      not MapSet.equal?(ids, expected) ->
        {:error, :invalid_piece_set}

      not Enum.all?(ordered_pieces, fn p ->
        p.content_group_id == gid and is_nil(p.archived_at)
      end) ->
        {:error, :invalid_piece_set}

      true ->
        Repo.transaction(fn ->
          Enum.each(Enum.with_index(ordered_pieces), fn {piece, idx} ->
            {1, _} =
              Repo.update_all(
                from(p in ContentPiece,
                  where: p.id == ^piece.id and p.content_group_id == ^gid
                ),
                set: [display_order: idx]
              )
          end)

          get_content_group!(gid)
        end)
    end
  end

  defp put_next_display_order_if_absent(%ContentGroup{} = group, attrs) do
    if Map.has_key?(attrs, "display_order") || Map.has_key?(attrs, :display_order) do
      attrs
    else
      Map.put(attrs, :display_order, next_content_piece_display_order(group))
    end
  end

  def update_content_piece(%ContentPiece{} = piece, attrs) do
    changeset_fn =
      if Map.has_key?(attrs, "image"),
        do: &ContentPiece.changeset_with_image/2,
        else: &ContentPiece.changeset/2

    piece
    |> changeset_fn.(attrs)
    |> Repo.update()
  end

  @doc """
  Returns true when the piece may be hard-deleted: never had a tiqit
  purchase for its piece-scoped classes and no ledger line references
  a tiqit tied to those classes. Archived pieces are never deletable.
  """
  def content_piece_hard_deletable?(%ContentPiece{} = piece) do
    is_nil(piece.archived_at) and not piece_has_tiqit_or_ledger_activity?(piece.id)
  end

  defp piece_has_tiqit_or_ledger_activity?(piece_id) do
    has_tiqit? =
      Repo.exists?(
        from t in Tiqit,
          join: tc in assoc(t, :tiqit_class),
          where: tc.content_piece_id == ^piece_id
      )

    has_ledger? =
      Repo.exists?(
        from le in LedgerEntry,
          join: t in assoc(le, :tiqit),
          join: tc in assoc(t, :tiqit_class),
          where: tc.content_piece_id == ^piece_id,
          where: not is_nil(le.tiqit_id)
      )

    has_tiqit? or has_ledger?
  end

  @doc """
  Soft-removes a content piece from catalog surfaces while preserving rows
  needed for purchase history. Deactivates piece-scoped `tiqit_classes`.
  """
  def archive_content_piece(%ContentPiece{archived_at: at} = piece) when not is_nil(at),
    do: {:ok, get_content_piece!(piece.id)}

  def archive_content_piece(%ContentPiece{} = piece) do
    Repo.transaction(fn ->
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      case piece
           |> Ecto.Changeset.change(%{archived_at: now})
           |> Repo.update() do
        {:ok, updated} ->
          Repo.update_all(
            from(tc in TiqitClass, where: tc.content_piece_id == ^updated.id),
            set: [active: false]
          )

          get_content_piece!(updated.id)

        {:error, cs} ->
          Repo.rollback(cs)
      end
    end)
  end

  def delete_content_piece(%ContentPiece{} = piece) do
    cond do
      not is_nil(piece.archived_at) ->
        {:error, :already_archived}

      not content_piece_hard_deletable?(piece) ->
        {:error, :requires_archive}

      true ->
        Repo.delete(piece)
    end
  end

  def delete_content_piece_image(%ContentPiece{} = piece) do
    piece
    |> Ecto.Changeset.change(%{image: nil})
    |> Repo.update()
  end

  # ---------------------------------------
  #             TIQIT CLASSES
  # ---------------------------------------

  def delete_tiqit_class(id) do
    Repo.get!(TiqitClass, id)
    |> Repo.delete()
  end
end
