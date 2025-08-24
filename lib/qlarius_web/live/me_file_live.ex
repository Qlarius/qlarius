defmodule QlariusWeb.MeFileLive do
  use QlariusWeb, :live_view

  alias Qlarius.YouData.Traits
  alias Qlarius.YouData.MeFiles

  import QlariusWeb.MeFileHTML

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.sponster {assigns}>

      <%!-- <.tag_and_trait_count_badges trait_count={@trait_count} tag_count={@tag_count} /> --%>
      <.tag_and_trait_count_badges trait_count={@current_scope.trait_count} tag_count={@current_scope.tag_count} />

      <div class="space-y-8 py-6">
        <div :for={{category, parent_traits} <- @me_file_tag_map_by_category_trait_tag}>
          <div class="flex flex-row justify-between items-baseline mb-4">
            <h2 class="text-xl font-medium">{category.name}</h2>
            <span class="text-sm text-gray-500">
              {length(parent_traits)} traits
            </span>
          </div>

          <div class="flex flex-row flex-wrap gap-4">
            <div
              :for={{parent_trait_id, parent_trait_name, tags_traits} <- parent_traits}
              class="h-full border rounded-lg overflow-hidden border-youdata-500 dark:border-youdata-700 bg-base-100"
            >
              <div class="bg-youdata-300/80 dark:bg-youdata-800/80 text-base-content px-4 py-2 font-medium flex justify-between items-center">
                <span>{parent_trait_name}</span>
                <div class="ms-4 flex gap-3">
                  <button
                    class="text-base-content/20 hover:text-base-content/80 cursor-pointer"
                    phx-value-id={parent_trait_id}
                  >
                    <.icon name="hero-pencil" class="h-4 w-4" />
                  </button>
                  <button
                    class="text-base-content/20 hover:text-base-content/80 cursor-pointer"
                    phx-click="delete_trait"
                    phx-value-id={parent_trait_id}
                    data-confirm="Are you sure you want to remove all values for this trait?"
                  >
                    <.icon name="hero-trash" class="h-4 w-4" />
                  </button>
                </div>
              </div>
              <div class="p-0 space-y-1 max-h-[245px] overflow-y-auto">
                <div :for={tag <- tags_traits} class="mx-0 my-2 text-sm [&:not(:last-child)]:border-b border-dashed border-base-content/10">
                  <div class="px-4 py-1">{tag}</div>
                </div>
              </div>
            </div>
          </div>

          <div class="mt-8 border-b border-neutral-300 dark:border-neutral-500"></div>
        </div>
      </div>

      <.link
        navigate={~p"/me_file"}
        class="fixed bottom-20 right-6 px-6 py-3 bg-blue-500 text-white rounded-full shadow-xl hover:bg-blue-600 font-medium flex items-center gap-1 z-10"
      >
        <.icon name="hero-plus" class="h-5 w-5" /> Builder
      </.link>
    </Layouts.sponster>
    """
  end

  @impl true
  def handle_event("delete_trait", %{"id" => trait_id}, socket) do
    {trait_id, _} = Integer.parse(trait_id)
    IO.inspect(trait_id)
    # Traits.delete_trait_tags(trait_id, socket.assigns.current_scope.user.id)

    # socket =
    #   socket
    #   |> assign_stats()
    #   |> assign_categories()

    {:noreply, socket}
  end

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:title, "MeFile")
    # |> assign_stats()
    |> assign_me_file_tags()
    |> ok()
  end

  # defp assign_stats(socket) do
  #   user = socket.assigns.current_scope.user

  #   socket
  #   |> assign(:trait_count, Traits.count_traits_with_values(user.id))
  #   |> assign(:tag_count, Traits.count_me_file_tags(user.me_file.id))
  # end

  defp assign_categories(socket) do
    # user_id = socket.assigns.current_scope.user.id
    # categories = Traits.list_categories_with_user_traits(user_id)
    assign(socket, :categories, Traits.list_trait_categories_with_traits())
  end

  defp assign_me_file_tags(socket) do
    me_file_id = socket.assigns.current_scope.user.me_file.id
    assign(socket, :me_file_tag_map_by_category_trait_tag, MeFiles.me_file_tag_map_by_category_trait_tag(me_file_id))
  end
end
