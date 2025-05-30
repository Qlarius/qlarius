defmodule QlariusWeb.Creators.ContentPieceLive.Form do
  use QlariusWeb, :live_view

  alias Qlarius.Tiqit.Arcade.ContentPiece
  alias Qlarius.Tiqit.Arcade.Creators

  alias QlariusWeb.TiqitClassHTML

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

  defp save_content(socket, :edit, piece_params) do
    case Creators.update_content_piece(socket.assigns.piece, piece_params) do
      {:ok, _piece} ->
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
      {:ok, _content} ->
        socket
        |> put_flash(:info, "Content created successfully")
        |> push_navigate(to: ~p"/creators/content_groups/#{group}")

      {:error, %Ecto.Changeset{} = changeset} ->
        assign(socket, :form, to_form(changeset, action: :validate))
    end
    |> noreply()
  end
end
