defmodule QlariusWeb.Creators.ContentPieceLive.Form do
  use QlariusWeb, :live_view

  alias Qlarius.Creators
  alias Qlarius.Arcade.ContentPiece

  @impl true
  def mount(%{"content_group_id" => group_id}, _session, socket) do
    group = Creators.get_content_group!(socket.assigns.current_scope, group_id)

    socket
    |> assign(group: group)
    |> ok()
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    id = String.to_integer(id)
    group = socket.assigns.group
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

  def handle_params(_params, _uri, socket) do
    changeset = Creators.change_content_piece(%ContentPiece{})

    socket
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
    case Creators.update_content_piece(
           socket.assigns.current_scope,
           socket.assigns.piece,
           piece_params
         ) do
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

    case Creators.create_content_piece(
           socket.assigns.current_scope,
           group,
           piece_params
         ) do
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
