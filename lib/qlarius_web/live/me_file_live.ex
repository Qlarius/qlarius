defmodule QlariusWeb.MeFileLive do
  use QlariusWeb, :live_view

  alias Qlarius.YouData.Traits
  alias Qlarius.YouData.MeFiles

  import QlariusWeb.MeFileHTML

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.mobile {assigns}>
      <.tag_edit_modal
        trait_in_edit={@trait_in_edit}
        me_file_id={@current_scope.user.me_file.id}
        selected_ids={@selected_child_trait_ids || []}
        show_modal={@show_modal}
        tag_edit_mode={@tag_edit_mode || "update"}
      />

      <div class="mb-6 flex gap-2 justify-end items-center">
          <div class="text-lg font-bold bg-youdata-500 dark:bg-youdata-700 text-white px-3 py-1 rounded-full">
            {@current_scope.tag_count} tags
          </div>
        </div>

      <div class="space-y-8 py-6">
        <div :for={
          {{_id, name, _display_order}, parent_traits} <- @me_file_tag_map_by_category_trait_tag
        }>
          <div class="flex flex-row justify-between items-baseline mb-4">
            <h2 class="text-xl font-medium">{name}</h2>
            <span class="text-sm text-gray-500">
              {length(parent_traits)} tags
            </span>
          </div>

          <div class="flex flex-row flex-wrap gap-4">
            <div
              :for={
                {parent_trait_id, parent_trait_name, parent_trait_display_order, tags_traits} <-
                  parent_traits
              }
              id={"trait-card-#{parent_trait_id}"}
              phx-hook="AnimateTrait"
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
                    phx-click="delete_tags"
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
        navigate={~p"/me_file_builder"}
        class="fixed bottom-20 right-6 px-4 py-2 bg-blue-500 text-white rounded-full shadow-xl hover:bg-blue-600 font-medium flex items-center gap-1 z-10"
      >
        <.icon name="hero-plus" class="h-5 w-5" /> Builder
      </.link>
    </Layouts.mobile>
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
      |> assign(:show_modal, true)
      |> assign(:tag_edit_mode, "update")

    {:noreply, socket}
  end

  def handle_event("delete_tags", %{"id" => trait_id}, socket) do
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
      |> assign(:show_modal, true)
      |> assign(:tag_edit_mode, "delete")

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :show_modal, false)}
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
          "me_file_id" => _me_file_id,
          "trait_id" => trait_id,
          "child_trait_ids" => child_trait_ids
        },
        socket
      ) do
    {trait_id, _} = Integer.parse(trait_id)
    child_trait_ids = List.wrap(child_trait_ids)

    # to capture the tag_value snapshot for me_file_tag
    id_to_name_map =
      (socket.assigns.trait_in_edit.child_traits || [])
      |> Enum.reduce(%{}, fn ct, acc ->
        Map.put(acc, ct.id, (ct.survey_answer && ct.survey_answer.text) || ct.trait_name)
      end)

    :ok =
      MeFiles.create_replace_mefile_tags(
        socket.assigns.current_scope.user.me_file.id,
        trait_id,
        child_trait_ids,
        socket.assigns.current_scope.user.id,
        id_to_name_map
      )

    me_file_id = socket.assigns.current_scope.user.me_file.id
    updated_parent_tuple = MeFiles.parent_trait_with_tags_for_mefile(me_file_id, trait_id)

    socket =
      socket
      |> update(:me_file_tag_map_by_category_trait_tag, fn cat_map ->
        Enum.map(cat_map, fn {category, parent_traits} ->
          {category,
           Enum.map(parent_traits, fn
             {id, _name, _order, _tags} when id == trait_id -> updated_parent_tuple
             other -> other
           end)}
        end)
      end)
      |> assign(:selected_child_trait_ids, Enum.map(elem(updated_parent_tuple, 3), &elem(&1, 0)))
      |> assign(:show_modal, false)
      |> push_event("animate_trait", %{trait_id: trait_id, delay_ms: 250, value: "update_pulse"})

    {:noreply, socket}
  end

  def handle_event(
        "delete_tags",
        %{
          "me_file_id" => _me_file_id,
          "trait_id" => trait_id,
          "child_trait_ids" => child_trait_ids
        },
        socket
      ) do
    {trait_id, _} = Integer.parse(trait_id)
    child_trait_ids = List.wrap(child_trait_ids)

    # Start the delete animation immediately
    socket =
      push_event(socket, "animate_trait", %{trait_id: trait_id, delay_ms: 0, value: "delete_fade"})

    # Close modal immediately for better UX
    socket = assign(socket, :show_modal, false)

    # Delay the actual deletion and UI updates to allow animation to complete
    Process.send_after(
      self(),
      {:perform_tag_deletion, trait_id, child_trait_ids, socket.assigns.current_scope},
      1000
    )

    {:noreply, socket}
  end

  @impl true
  def handle_info({:perform_tag_deletion, trait_id, child_trait_ids, current_scope}, socket) do
    # Remove the selected tags from the me_file
    :ok =
      MeFiles.delete_mefile_tags(
        current_scope.user.me_file.id,
        trait_id,
        child_trait_ids
      )

    # Remove the parent trait entirely from the assigns since deletion was successful
    socket =
      socket
      |> update(:me_file_tag_map_by_category_trait_tag, fn cat_map ->
        Enum.map(cat_map, fn {category, parent_traits} ->
          {category,
           Enum.reject(parent_traits, fn {id, _name, _order, _tags} ->
             id == trait_id
           end)}
        end)
        |> Enum.reject(fn {_category, parent_traits} ->
          parent_traits == []
        end)
        |> Map.new()
      end)
      |> assign(:selected_child_trait_ids, [])

    {:noreply, socket}
  end

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:title, "MeFile")
    |> assign_me_file_tags()
    |> assign(:trait_in_edit, nil)
    |> assign(:selected_child_trait_ids, [])
    |> assign(:show_modal, false)
    |> assign(:tag_edit_mode, "update")
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
end
