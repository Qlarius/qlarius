defmodule QlariusWeb.Creators.ContentPieceLive.Form do
  use QlariusWeb, :live_view

  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}
  alias Qlarius.Tiqit.Arcade.ContentPiece
  alias Qlarius.Tiqit.Arcade.Creators

  alias QlariusWeb.TiqitClassHTML
  alias QlariusWeb.Uploaders.CreatorImage
  alias QlariusWeb.LiveView.ImageUpload

  # EDIT
  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    piece = Creators.get_content_piece!(id)
    group = piece.content_group
    catalog = group.catalog
    creator = catalog.creator

    changeset = Creators.change_content_piece(piece)

    socket
    |> assign(catalog: catalog, creator: creator, group: group)
    |> assign(
      form: to_form(changeset),
      page_title: "Edit Content Piece",
      piece: piece
    )
    |> ImageUpload.setup_upload(:image)
    |> noreply()
  end

  # NEW
  def handle_params(%{"content_group_id" => group_id}, _uri, socket) do
    changeset = Creators.change_content_piece(%ContentPiece{date_published: Date.utc_today()})

    group = Creators.get_content_group!(group_id)
    catalog = group.catalog
    creator = catalog.creator

    socket
    |> assign(catalog: catalog, creator: creator, group: group)
    |> assign(:page_title, "New Content Piece")
    |> assign(:piece, %ContentPiece{})
    |> assign(:form, to_form(changeset))
    |> ImageUpload.setup_upload(:image)
    |> noreply()
  end

  @impl true
  def handle_event("validate", %{"content_piece" => piece_params}, socket) do
    # If you remove all tiqit classes while editing, then change another input
    # triggering the "validate" handler, then `piece_params` contains no
    # 'tiqit_classes' key … and this resets the tiqit classes to what they
    # originally were in the unedited content piece. We can fix this be
    # ensuring a "tiqit_classes" key is always present although I'm not sure if
    # this is the "correct" idiomatic way to do it in Phoenix :shrug:
    piece_params = Map.put_new(piece_params, "tiqit_classes", %{})

    form =
      socket.assigns.piece
      |> Creators.change_content_piece(piece_params)
      |> to_form(action: :validate)

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"content_piece" => piece_params}, socket) do
    save_content(socket, socket.assigns.live_action, piece_params)
  end

  def handle_event("write_default_tiqit_classes", _params, socket) do
    # Call the arcade context function to write default tiqit classes for this piece
    Qlarius.Tiqit.Arcade.Arcade.write_default_piece_tiqit_classes(socket.assigns.piece)

    # Reload the piece to get updated tiqit classes
    piece = Creators.get_content_piece!(socket.assigns.piece.id)

    # Update both piece and form so the UI reflects the new tiqit classes
    changeset = Creators.change_content_piece(piece)

    {:noreply,
     socket
     |> assign(:piece, piece)
     |> assign(:form, to_form(changeset))}
  end

  def handle_event("delete_image", _params, socket) do
    case Creators.delete_content_piece_image(socket.assigns.piece) do
      {:ok, piece} ->
        socket
        |> assign(piece: piece)
        |> put_flash(:info, "Image deleted successfully")

      {:error, _changeset} ->
        put_flash(socket, :error, "Failed to delete image")
    end
    |> noreply()
  end

  defp save_content(socket, :edit, piece_params) do
    # Handle file upload for LiveView - store with Waffle directly
    piece_params_with_image =
      case consume_uploaded_entries(socket, :image, fn %{path: path}, entry ->
             upload = %Plug.Upload{
               path: path,
               filename: entry.client_name,
               content_type: entry.client_type
             }

             case CreatorImage.store({upload, socket.assigns.piece}) do
               {:ok, filename} -> {:ok, filename}
               error -> error
             end
           end) do
        [filename | _] -> Map.put(piece_params, "image", filename)
        [] -> piece_params
      end

    case Creators.update_content_piece(socket.assigns.piece, piece_params_with_image) do
      {:ok, _piece} ->
        socket
        |> put_flash(:info, "Content updated successfully")
        |> push_navigate(to: ~p"/creators/content_groups/#{socket.assigns.group.id}")

      {:error, %Ecto.Changeset{} = changeset} ->
        assign(socket, :form, to_form(changeset, action: :validate))
    end
    |> noreply()
  end

  defp save_content(socket, :new, piece_params) do
    group = socket.assigns.group
    temp_piece = %ContentPiece{content_group: group}

    piece_params_with_image =
      ImageUpload.consume_and_add_to_params(
        socket,
        :image,
        temp_piece,
        CreatorImage,
        piece_params
      )

    case Creators.create_content_piece(group, piece_params_with_image) do
      {:ok, _content} ->
        socket
        |> put_flash(:info, "Content created successfully")
        |> push_navigate(to: ~p"/creators/content_groups/#{group.id}")

      {:error, %Ecto.Changeset{} = changeset} ->
        assign(socket, :form, to_form(changeset, action: :validate))
    end
    |> noreply()
  end
end
