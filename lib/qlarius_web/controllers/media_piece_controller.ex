defmodule QlariusWeb.MediaPieceController do
  use QlariusWeb, :controller

  alias Qlarius.Marketing
  alias Qlarius.Marketing.MediaPiece

  def index(conn, _params) do
    media_pieces = Marketing.list_media_pieces()
    render(conn, :index, media_pieces: media_pieces)
  end

  def new(conn, _params) do
    changeset = Marketing.change_media_piece(%MediaPiece{})

    conn
    |> assign_form_dropdowns()
    |> render(:new, changeset: changeset)
  end

  def create(conn, %{"media_piece" => media_piece_params}) do
    case Marketing.create_media_piece(media_piece_params) do
      {:ok, _media_piece} ->
        conn
        |> put_flash(:info, "Media piece created successfully.")
        |> redirect(to: ~p"/media_pieces")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign_form_dropdowns()
        |> render(:new, changeset: changeset)
    end
  end

  def edit(conn, %{"id" => id}) do
    media_piece = Marketing.get_media_piece!(id)
    changeset = Marketing.change_media_piece(media_piece)

    conn
    |> assign_form_dropdowns()
    |> render(:edit, media_piece: media_piece, changeset: changeset)
  end

  def update(conn, %{"id" => id, "media_piece" => media_piece_params}) do
    media_piece = Marketing.get_media_piece!(id)

    case Marketing.update_media_piece(media_piece, media_piece_params) do
      {:ok, _media_piece} ->
        conn
        |> put_flash(:info, "Media piece updated successfully.")
        |> redirect(to: ~p"/media_pieces")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign_form_dropdowns()
        |> render(:edit, media_piece: media_piece, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    media_piece = Marketing.get_media_piece!(id)
    {:ok, _media_piece} = Marketing.delete_media_piece(media_piece)

    conn
    |> put_flash(:info, "Media piece deleted successfully.")
    |> redirect(to: ~p"/media_pieces")
  end

  defp assign_form_dropdowns(conn) do
    IO.inspect(Map.keys(conn.assigns))

    conn =
      merge_assigns(conn,
        ad_categories: Marketing.list_ad_categories(),
        marketers: Marketing.list_marketers()
      )

    IO.inspect(Map.keys(conn.assigns))
    conn
  end
end
