defmodule QlariusWeb.Creators.ContentPieceController do
  use QlariusWeb, :controller

  alias Qlarius.Tiqit.Arcade.Creators

  plug :put_new_layout, {QlariusWeb.Layouts, :arcade}

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
    {:ok, _piece} = Creators.delete_content_piece(piece)

    conn
    |> put_flash(:info, "Deleted content piece.")
    |> redirect(to: ~p"/creators/content_groups/#{group}")
  end
end
