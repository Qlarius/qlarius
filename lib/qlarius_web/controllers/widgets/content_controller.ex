defmodule QlariusWeb.Widgets.ContentController do
  use QlariusWeb, :controller

  alias Qlarius.Tiqit.Arcade.Arcade

  # This controller serves two contexts:
  # - /widgets/content/:id (embedded widget)
  # - /content/:id (main app)
  # The base_path is detected from the request path so that
  # fallback redirects stay within the correct context.
  def show(conn, %{"id" => id} = params) do
    piece = Arcade.get_content_piece!(id)
    force_theme = Map.get(params, "force_theme", "light")

    base = if String.starts_with?(conn.request_path, "/widgets/"), do: "/widgets", else: ""

    if tiqit = Arcade.get_valid_tiqit(conn.assigns.current_scope, piece) do
      render(conn, "show.html",
        content: piece,
        tiqit: tiqit,
        force_theme: force_theme,
        base_path: base
      )
    else
      group_id = piece.content_group_id || piece.content_group.id

      redirect_path =
        if force_theme do
          "#{base}/arqade/group/#{group_id}?content_id=#{piece.id}&force_theme=#{force_theme}"
        else
          "#{base}/arqade/group/#{group_id}?content_id=#{piece.id}"
        end

      conn
      |> put_flash(:error, "You don't have access to this content")
      |> redirect(to: redirect_path)
    end
  end
end
