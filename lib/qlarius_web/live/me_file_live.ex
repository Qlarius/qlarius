defmodule QlariusWeb.MeFileLive do
  use QlariusWeb, :sponster_live_view

  alias Qlarius.MeFile

  import QlariusWeb.MeFileHTML

  @impl true
  def handle_event("delete_trait", %{"id" => trait_id}, socket) do
    {trait_id, _} = Integer.parse(trait_id)
    MeFile.delete_trait_tags(trait_id, socket.assigns.current_user.id)

    socket =
      socket
      |> assign_stats()
      |> assign_categories()

    {:noreply, socket}
  end

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "MeFile")
      |> assign_stats()
      |> assign_categories()

    {:ok, socket}
  end

  defp assign_stats(socket) do
    user_id = socket.assigns.current_user.id

    socket
    |> assign(:trait_count, MeFile.count_traits_with_values(user_id))
    |> assign(:tag_count, MeFile.count_user_tags(user_id))
  end

  defp assign_categories(socket) do
    user_id = socket.assigns.current_user.id
    categories = MeFile.list_categories_with_traits(user_id)
    assign(socket, :categories, categories)
  end
end
