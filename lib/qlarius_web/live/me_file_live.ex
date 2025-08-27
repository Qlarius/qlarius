defmodule QlariusWeb.MeFileLive do
  use QlariusWeb, :live_view

  alias Qlarius.YouData.Traits
  alias Qlarius.YouData.MeFiles

  import QlariusWeb.MeFileHTML

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.sponster {assigns}>
      <.tag_edit_modal
        trait_in_edit={@trait_in_edit}
        me_file_id={@current_scope.user.me_file.id}
        selected_ids={@selected_child_trait_ids || []}
      />

      <%!-- <.tag_and_trait_count_badges trait_count={@trait_count} tag_count={@tag_count} /> --%>
      <.tag_and_trait_count_badges
        trait_count={@current_scope.trait_count}
        tag_count={@current_scope.tag_count}
      />

      <div class="space-y-8 py-6">
        <div :for={
          {{_id, name, _display_order}, parent_traits} <- @me_file_tag_map_by_category_trait_tag
        }>
          <div class="flex flex-row justify-between items-baseline mb-4">
            <h2 class="text-xl font-medium">{name}</h2>
            <span class="text-sm text-gray-500">
              {length(parent_traits)} traits
            </span>
          </div>

          <div class="flex flex-row flex-wrap gap-4">
            <div
              :for={
                {parent_trait_id, parent_trait_name, parent_trait_display_order, tags_traits} <-
                  parent_traits
              }
              class="h-full border rounded-lg overflow-hidden border-youdata-500 dark:border-youdata-700 bg-base-100"
            >
              <div class="bg-youdata-300/80 dark:bg-youdata-800/80 text-base-content px-4 py-2 font-medium flex justify-between items-center">
                <span>{parent_trait_name}</span>
                <div
                  :if={parent_trait_name not in ["Birthdate", "Age", "Sex"]}
                  class="ms-4 flex gap-3"
                >
                  <button
                    class="text-base-content/20 hover:text-base-content/80 cursor-pointer"
                    phx-click="edit_tags"
                    phx-value-id={parent_trait_id}
                  >
                    <.icon name="hero-pencil" class="h-4 w-4" />
                  </button>
                  <button
                    class="text-base-content/20 hover:text-base-content/80 cursor-pointer"
                    phx-click="delete_trait"
                    onclick="tag_edit_modal.showModal()"
                    phx-value-id={parent_trait_id}
                  >
                    <.icon name="hero-trash" class="h-4 w-4" />
                  </button>
                </div>
              </div>
              <div class="p-0 space-y-1 max-h-[245px] overflow-y-auto">
                <div
                  :for={{tag_id, tag_value, _display_order} <- tags_traits}
                  class="mx-0 my-2 text-sm [&:not(:last-child)]:border-b border-dashed border-base-content/10"
                >
                  <div class="px-4 py-1">{tag_value}</div>
                </div>
              </div>
            </div>
          </div>

          <div class="mt-8 border-b border-neutral-300 dark:border-neutral-500"></div>
        </div>
      </div>

      <.link
        navigate={~p"/me_file"}
        class="fixed bottom-20 right-6 px-4 py-2 bg-blue-500 text-white rounded-full shadow-xl hover:bg-blue-600 font-medium flex items-center gap-1 z-10"
      >
        <.icon name="hero-plus" class="h-5 w-5" /> Builder
      </.link>
    </Layouts.sponster>
    """
  end

  def handle_event("edit_tags", %{"id" => trait_id}, socket) do
    {trait_id, _} = Integer.parse(trait_id)
    {:ok, trait} = Traits.get_trait_with_full_survey_data!(trait_id)

    selected_ids =
      selected_child_trait_ids_from_map(
        socket.assigns.me_file_tag_map_by_category_trait_tag,
        trait.id
      )

    socket =
      socket
      |> assign(:trait_in_edit, trait)
      |> assign(:selected_child_trait_ids, selected_ids)
      |> push_event("show_modal", %{id: "tag_edit_modal"})

    {:noreply, socket}
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

  def handle_event(
        "save_tags",
        %{
          "me_file_id" => me_file_id,
          "trait_id" => trait_id,
          "child_trait_ids" => child_trait_ids
        },
        socket
      ) do
    {trait_id, _} = Integer.parse(trait_id)
    child_trait_ids = List.wrap(child_trait_ids)

    Traits.create_user_trait_values(
      socket.assigns.current_scope.user.id,
      trait_id,
      child_trait_ids
    )

    socket =
      socket
      |> assign_me_file_tags()
      |> push_event("hide_modal", %{id: "tag_edit_modal"})

    {:noreply, socket}
  end

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:title, "MeFile")
    |> assign_me_file_tags()
    |> assign(:trait_in_edit, nil)
    |> assign(:selected_child_trait_ids, [])
    |> ok()
  end

  defp assign_me_file_tags(socket) do
    me_file_id = socket.assigns.current_scope.user.me_file.id

    assign(
      socket,
      :me_file_tag_map_by_category_trait_tag,
      MeFiles.me_file_tag_map_by_category_trait_tag(me_file_id)
    )
  end

  defp selected_child_trait_ids_from_map(me_file_tag_map_by_category_trait_tag, parent_trait_id) do
    me_file_tag_map_by_category_trait_tag
    |> Enum.find_value(fn {_category, parent_traits} ->
      Enum.find_value(parent_traits, fn
        {id, _name, _display_order, tags} when id == parent_trait_id ->
          Enum.map(tags, fn {child_id, _label, _order} -> child_id end)
        _ ->
          nil
      end)
    end) || []
  end

  defp assign_existing_tags_per_trait_in_edit(socket) do
    me_file_id = socket.assigns.current_scope.user.me_file.id
    trait_id = socket.assigns.trait_in_edit.id

    assign(
      socket,
      :existing_tags_per_trait_in_edit,
      MeFiles.existing_tags_per_parent_trait(me_file_id)
    )
  end
end
