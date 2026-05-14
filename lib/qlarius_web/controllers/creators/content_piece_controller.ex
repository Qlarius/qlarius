defmodule QlariusWeb.Creators.ContentPieceController do
  use QlariusWeb, :controller

  alias Qlarius.Tiqit.Arcade.Creators

  def show(conn, %{"id" => id}) do
    piece = Creators.get_content_piece!(id)
    group = piece.content_group
    catalog = group.catalog
    creator = catalog.creator
    render(conn, :show, piece: piece, content_group: group, catalog: catalog, creator: creator)
  end

  def delete(conn, %{"id" => id}) do
    piece = Creators.get_content_piece!(id)
    group = piece.content_group

    case Creators.delete_content_piece(piece) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Deleted content piece.")
        |> redirect(to: ~p"/creators_cont/content_groups/#{group}")

      {:error, :requires_archive} ->
        conn
        |> put_flash(
          :error,
          "This piece cannot be deleted because it has purchase or ledger history. Open it in the app and use Archive."
        )
        |> redirect(to: ~p"/creators_cont/content_pieces/#{piece}")

      {:error, :already_archived} ->
        conn
        |> put_flash(:error, "This content piece is already archived.")
        |> redirect(to: ~p"/creators_cont/content_pieces/#{piece}")

      {:error, _} ->
        conn
        |> put_flash(:error, "Could not delete this content piece.")
        |> redirect(to: ~p"/creators_cont/content_pieces/#{piece}")
    end
  end
end
