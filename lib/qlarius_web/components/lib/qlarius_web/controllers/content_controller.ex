defmodule QlariusWeb.ContentController do
  use QlariusWeb, :controller

  alias Qlarius.Arcade

  def show(conn, %{"id" => id}) do
    content = Arcade.get_content!(id)

    if Arcade.has_valid_tiqit?(content, conn.assigns.current_user) do
      render(conn, "show.html", content: content)
    else
      conn
      |> put_flash(:error, "You don't have access to this content")
      |> redirect(to: ~p"/arcade?content_id=#{id}")
    end
  end
end
