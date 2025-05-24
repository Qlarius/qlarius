defmodule QlariusWeb.Creators.ContentPieceController do
  use QlariusWeb, :controller

  alias Qlarius.Tiqit.Creators

  plug :put_new_layout, {QlariusWeb.Layouts, :arcade}

  def delete(conn, %{"id" => id}) do
    piece = Creators.get_content_piece!(id)
    group = piece.content_group
    {:ok, _piece} = Creators.delete_content_piece(piece)

    conn
    |> put_flash(:info, "Deleted content piece.")
    |> redirect(to: ~p"/creators/content_groups/#{group}")
  end
end
