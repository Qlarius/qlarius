defmodule QlariusWeb.Widgets.ContentController do
  use QlariusWeb, :controller

  alias Qlarius.Tiqit.Arcade.Arcade

  def show(conn, %{"id" => id} = params) do
    piece = Arcade.get_content_piece!(id)
    force_theme = Map.get(params, "force_theme")

    if tiqit = Arcade.get_valid_tiqit(conn.assigns.current_scope, piece) do
      render(conn, "show.html", content: piece, tiqit: tiqit, force_theme: force_theme)
    else
      conn
      |> put_flash(:error, "You don't have access to this content")
      |> redirect(to: ~p"/widgets/arcade/group/#{piece.content_group}?content_id=#{piece}")
    end
  end
end
