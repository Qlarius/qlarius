defmodule QlariusWeb.MediaPieceController do
  use QlariusWeb, :controller
  require Logger

  alias Qlarius.Sponster.Marketing
  alias Qlarius.Sponster.Ads.MediaPiece

  @debug true

  def index(conn, _params) do
    media_pieces = Marketing.list_media_pieces()
    render(conn, :index, media_pieces: media_pieces, debug: @debug)
  end

  def new(conn, _params) do
    changeset = Marketing.change_media_piece(%MediaPiece{})
    ad_categories = Marketing.list_ad_categories()
    render(conn, :new, changeset: changeset, ad_categories: ad_categories, debug: @debug)
  end

  def create(conn, %{"media_piece" => media_piece_params}) do
    case Marketing.create_media_piece(media_piece_params) do
      {:ok, _media_piece} ->
        conn
        |> put_flash(:info, "Media piece created successfully.")
        |> redirect(to: ~p"/marketer/media_pieces")

      {:error, %Ecto.Changeset{} = changeset} ->
        ad_categories = Marketing.list_ad_categories()
        render(conn, :new, changeset: changeset, ad_categories: ad_categories, debug: @debug)
    end
  end

  def edit(conn, %{"id" => id}) do
    media_piece = Marketing.get_media_piece!(id)
    changeset = Marketing.change_media_piece(media_piece)
    ad_categories = Marketing.list_ad_categories()

    render(conn, :edit,
      media_piece: media_piece,
      changeset: changeset,
      ad_categories: ad_categories,
      debug: true
    )
  end

  def update(conn, %{"id" => id, "media_piece" => media_piece_params}) do
    media_piece = Marketing.get_media_piece!(id)
    Logger.info("Updating media piece #{id} with params: #{inspect(media_piece_params)}")

    case Marketing.update_media_piece(media_piece, media_piece_params) do
      {:ok, _media_piece} ->
        conn
        |> put_flash(:info, "Media piece updated successfully.")
        |> redirect(to: ~p"/marketer/media_pieces")

      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.error("Failed to update media piece #{id}. Errors: #{inspect(changeset.errors)}")
        ad_categories = Marketing.list_ad_categories()

        render(conn, :edit,
          media_piece: media_piece,
          changeset: changeset,
          ad_categories: ad_categories,
          debug: @debug
        )
    end
  end

  def delete(conn, %{"id" => id}) do
    media_piece = Marketing.get_media_piece!(id)
    {:ok, _media_piece} = Marketing.delete_media_piece(media_piece)

    conn
    |> put_flash(:info, "Media piece deleted successfully.")
    |> redirect(to: ~p"/marketer/media_pieces")
  end
end
