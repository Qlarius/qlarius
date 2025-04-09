defmodule QlariusWeb.Marketers.ContentLive.Form do
  use QlariusWeb, :live_view

  alias Qlarius.Arcade
  alias Qlarius.Arcade.ContentPiece

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    content = Arcade.get_content_piece!(id)
    changeset = Arcade.change_content(content)

    socket
    |> assign(:page_title, "Edit Content")
    |> assign(:content, content)
    |> assign(:form, to_form(changeset))
    |> noreply()
  end

  def handle_params(_params, _uri, socket) do
    changeset = Arcade.change_content(%ContentPiece{})

    socket
    |> assign(:page_title, "New Content")
    |> assign(:content, %ContentPiece{})
    |> assign(:form, to_form(changeset))
    |> noreply()
  end

  @impl true
  def handle_event("validate", %{"content" => content_params}, socket) do
    form =
      socket.assigns.content
      |> Arcade.change_content(content_params)
      |> to_form(action: :validate)

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"content" => content_params}, socket) do
    save_content(socket, socket.assigns.live_action, content_params)
  end

  defp save_content(socket, :edit, content_params) do
    case Arcade.update_content(socket.assigns.content, content_params) do
      {:ok, content} ->
        socket
        |> put_flash(:info, "Content updated successfully")
        |> push_navigate(to: ~p"/admin/content/#{content}")

      {:error, %Ecto.Changeset{} = changeset} ->
        assign(socket, :form, to_form(changeset, action: :validate))
    end
    |> noreply()
  end

  defp save_content(socket, :new, content_params) do
    case Arcade.create_content(content_params) do
      {:ok, content} ->
        socket
        |> put_flash(:info, "Content created successfully")
        |> push_navigate(to: ~p"/admin/content/#{content}")
        |> noreply()

      {:error, %Ecto.Changeset{} = changeset} ->
        assign(socket, :form, to_form(changeset, action: :validate))
    end
    |> noreply()
  end
end
