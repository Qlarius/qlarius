defmodule QlariusWeb.MeFileLive do
  use QlariusWeb, :live_view

  # alias Qlarius.YouData.Traits

  import QlariusWeb.MeFileHTML

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.sponster {assigns}>

      <%!-- <.tag_and_trait_count_badges trait_count={@trait_count} tag_count={@tag_count} /> --%>
      <.tag_and_trait_count_badges trait_count={33} tag_count={66} />

      <div class="space-y-8">
        <div :for={category <- @categories}>
          <div class="flex items-baseline gap-2 mb-4">
            <h2 class="text-xl font-medium">{category.name}</h2>
            <span class="text-sm text-gray-500">
              <%!-- {length(category.traits)} traits --%>
              {22} traits
            </span>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-6 max-w-4xl">
            <div
              :for={trait <- [%{id: 1, name: "Trait 1"}, %{id: 2, name: "Trait 2"}, %{id: 3, name: "Trait 3"}]}
              class="border rounded-lg overflow-hidden border-base-300 bg-base-100"
            >
              <div class="bg-youdata-500 text-white px-4 py-2 font-medium flex justify-between items-center">
                <span>{trait.name}</span>
                <button
                  class="text-gray-500 hover:text-red-600"
                  phx-click="delete_trait"
                  phx-value-id={trait.id}
                  data-confirm="Are you sure you want to remove all values for this trait?"
                >
                  <.icon name="hero-trash" class="h-4 w-4" />
                </button>
              </div>
              <div class="p-4 space-y-1">
                <%!-- <div :for={value <- trait.values} class="text-sm">{value.name}</div> --%>
                <div class="text-sm">Tag 1</div>
                <div class="text-sm">Tag 2</div>
                <div class="text-sm">Tag 3</div>
              </div>
            </div>
          </div>

          <div class="mt-8 border-b"></div>
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
    |> assign_categories()
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
    assign(socket, :categories, [%{id: 1, name: "Category 1"}, %{id: 2, name: "Category 2"}, %{id: 3, name: "Category 3"}])
  end
end
