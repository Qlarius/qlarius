defmodule QlariusWeb.Widgets.ContentController do
  use QlariusWeb, :controller

  alias Qlarius.Tiqit.Arcade.Arcade
  alias Qlarius.Widgets.Theme

  # This controller serves two contexts:
  # - /widgets/content/:id (embedded widget)
  # - /content/:id (main app)
  # The base_path is detected from the request path so that
  # fallback redirects stay within the correct context.
  def show(conn, %{"id" => id} = params) do
    piece = Arcade.get_content_piece!(id)
    explicit = Theme.explicit(Map.get(params, "force_theme"))
    base = if String.starts_with?(conn.request_path, "/widgets/"), do: "/widgets", else: ""

    force_theme =
      if base == "/widgets" do
        Theme.for_piece(piece.id, explicit)
      else
        explicit || "system"
      end

    conn = assign(conn, :widget_document_theme, Theme.widget_attr(base, force_theme))

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
        if explicit do
          "#{base}/arqade/group/#{group_id}?content_id=#{piece.id}&force_theme=#{explicit}"
        else
          "#{base}/arqade/group/#{group_id}?content_id=#{piece.id}"
        end

      conn
      |> put_flash(:error, "No active tiqits found for this content. Ready for fresh purchases.")
      |> redirect(to: redirect_path)
    end
  end
end
