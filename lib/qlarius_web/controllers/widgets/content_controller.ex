defmodule QlariusWeb.Widgets.ContentController do
  use QlariusWeb, :controller

  alias Qlarius.Tiqit.Arcade.Arcade

  def show(conn, %{"id" => id}) do
    piece = Arcade.get_content_piece!(id)

    if tiqit = Arcade.get_valid_tiqit(conn.assigns.current_scope, piece) do
      render(conn, "show.html", content: piece, tiqit: tiqit)
    else
      conn
      |> put_flash(:error, "You don't have access to this content")
      |> redirect(to: ~p"/widgets/arcade/group/#{piece.content_group}?content_id=#{piece}")
    end
  end
end
