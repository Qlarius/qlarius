defmodule QlariusWeb.Creators.ContentPieceController do
  use QlariusWeb, :controller

  alias Qlarius.Arcade

  plug :put_new_layout, {QlariusWeb.Layouts, :arcade}

  def show(conn, %{"id" => id}) do
    content = Arcade.get_content_piece!(id)
    render(conn, :show, content: content)
  end

  def delete(conn, %{"id" => id}) do
    content = Arcade.get_content_piece!(id)
    {:ok, _content} = Arcade.delete_content(content)

    conn
    |> put_flash(:info, "Content deleted successfully.")
    |> redirect(to: ~p"/admin/content")
  end
end
