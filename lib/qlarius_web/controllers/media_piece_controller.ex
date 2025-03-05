defmodule QlariusWeb.MediaPieceController do
  use QlariusWeb, :controller

  alias Qlarius.Marketing
  alias Qlarius.Marketing.MediaPiece

  plug :authenticate_marketer when action in [:index, :new, :create, :edit, :update, :delete]

  def index(conn, _params) do
    media_pieces = Marketing.list_media_pieces()
    render(conn, :index, media_pieces: media_pieces)
  end

  def new(conn, _params) do
    changeset = Marketing.change_media_piece(%MediaPiece{})
    ad_categories = Marketing.list_ad_categories()
    render(conn, :new, changeset: changeset, ad_categories: ad_categories)
  end

  def create(conn, %{"media_piece" => media_piece_params}) do
    case Marketing.create_media_piece(media_piece_params) do
      {:ok, _media_piece} ->
        conn
        |> put_flash(:info, "Media piece created successfully.")
        |> redirect(to: ~p"/media_pieces")

      {:error, %Ecto.Changeset{} = changeset} ->
        ad_categories = Marketing.list_ad_categories()
        render(conn, :new, changeset: changeset, ad_categories: ad_categories)
    end
  end

  def edit(conn, %{"id" => id}) do
    media_piece = Marketing.get_media_piece!(id)
    changeset = Marketing.change_media_piece(media_piece)
    ad_categories = Marketing.list_ad_categories()

    render(conn, :edit,
      media_piece: media_piece,
      changeset: changeset,
      ad_categories: ad_categories
    )
  end

  def update(conn, %{"id" => id, "media_piece" => media_piece_params}) do
    media_piece = Marketing.get_media_piece!(id)

    case Marketing.update_media_piece(media_piece, media_piece_params) do
      {:ok, _media_piece} ->
        conn
        |> put_flash(:info, "Media piece updated successfully.")
        |> redirect(to: ~p"/media_pieces")

      {:error, %Ecto.Changeset{} = changeset} ->
        ad_categories = Marketing.list_ad_categories()

        render(conn, :edit,
          media_piece: media_piece,
          changeset: changeset,
          ad_categories: ad_categories
        )
    end
  end

  def delete(conn, %{"id" => id}) do
    media_piece = Marketing.get_media_piece!(id)
    {:ok, _media_piece} = Marketing.delete_media_piece(media_piece)

    conn
    |> put_flash(:info, "Media piece deleted successfully.")
    |> redirect(to: ~p"/media_pieces")
  end

  # Basic auth for marketer access
  defp authenticate_marketer(conn, _opts) do
    username = "marketer"
    password = "password"

    case Plug.BasicAuth.parse_basic_auth(conn) do
      {^username, ^password} ->
        conn

      _ ->
        conn
        |> Plug.BasicAuth.request_basic_auth()
        |> halt()
    end
  end
end
