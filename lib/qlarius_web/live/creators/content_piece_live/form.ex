defmodule QlariusWeb.Creators.ContentPieceLive.Form do
  use QlariusWeb, :live_view

  alias Qlarius.Arcade.ContentPiece
  alias Qlarius.Creators

  # EDIT
  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    piece = Creators.get_content_piece!(id)
    group = piece.content_group
    piece = %ContentPiece{} = Enum.find(group.content_pieces, &(&1.id == id))

    changeset = Creators.change_content_piece(piece)

    socket
    |> assign(
      form: to_form(changeset),
      page_title: "Edit Content Piece",
      piece: piece
    )
    |> noreply()
  end

  # NEW
  def handle_params(%{"content_group_id" => group_id}, _uri, socket) do
    changeset = Creators.change_content_piece(%ContentPiece{})

    group = Creators.get_content_group!(group_id)
    catalog = group.catalog
    creator = catalog.creator

    socket
    |> assign(catalog: catalog, creator: creator, group: group)
    |> assign(:page_title, "New Content Piece")
    |> assign(:piece, %ContentPiece{})
    |> assign(:form, to_form(changeset))
    |> noreply()
  end

  @impl true
  def handle_event("validate", %{"content_piece" => piece_params}, socket) do
    form =
      socket.assigns.piece
      |> Creators.change_content_piece(piece_params)
      |> to_form(action: :validate)

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"content_piece" => piece_params}, socket) do
    save_content(socket, socket.assigns.live_action, piece_params)
  end

  defp save_content(socket, :edit, piece_params) do
    case Creators.update_content_piece(socket.assigns.piece, piece_params) do
      {:ok, piece} ->
        socket
        |> put_flash(:info, "Content updated successfully")
        |> push_navigate(to: ~p"/creators/content_groups/#{socket.assigns.group}")

      {:error, %Ecto.Changeset{} = changeset} ->
        assign(socket, :form, to_form(changeset, action: :validate))
    end
    |> noreply()
  end

  defp save_content(socket, :new, piece_params) do
    group = socket.assigns.group

    case Creators.create_content_piece(group, piece_params) do
      {:ok, content} ->
        socket
        |> put_flash(:info, "Content created successfully")
        |> push_navigate(to: ~p"/creators/content_groups/#{group}")

      {:error, %Ecto.Changeset{} = changeset} ->
        assign(socket, :form, to_form(changeset, action: :validate))
    end
    |> noreply()
  end
end
