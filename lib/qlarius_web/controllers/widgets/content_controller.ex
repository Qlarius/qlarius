defmodule QlariusWeb.Widgets.ContentController do
  use QlariusWeb, :controller

  alias Qlarius.Arcade

  def show(conn, %{"id" => id}) do
    content_piece = Arcade.get_content_piece!(id)

    if Arcade.has_valid_tiqit?(conn.assigns.current_scope, content_piece) do
      render(conn, "show.html", content: content_piece)
    else
      conn
      |> put_flash(:error, "You don't have access to this content")
      |> redirect(to: ~p"/arcade?content_id=#{id}")
    end
  end
end
