defmodule QlariusWeb.MediaSequenceController do
  use QlariusWeb, :controller

  alias Qlarius.Media
  alias Qlarius.Sponster.Campaigns.MediaRun

  def index(conn, _params) do
    media_sequences = Media.list_media_sequences()
    render(conn, "index.html", media_sequences: media_sequences)
  end

  def new(conn, _params) do
    changeset =
      Media.change_media_run(%MediaRun{})

    media_pieces = Media.list_media_pieces_for_select()
    render(conn, "new.html", changeset: changeset, media_pieces: media_pieces)
  end

  def create(conn, %{"media_run" => media_run_params}) do
    case Media.create_media_run_with_sequence(media_run_params) do
      {:ok, _run} ->
        conn
        |> put_flash(:info, "Media sequence created successfully.")
        |> redirect(to: ~p"/media_sequences")

      {:error, _reason} ->
        changeset = Media.change_media_run(%MediaRun{}, media_run_params)
        media_pieces = Media.list_media_pieces_for_select()

        conn
        |> put_flash(:error, "Failed to create media sequence.")
        |> render("new.html", changeset: changeset, media_pieces: media_pieces)
    end
  end
end
