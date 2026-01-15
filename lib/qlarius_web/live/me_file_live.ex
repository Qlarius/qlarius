defmodule QlariusWeb.MeFileLive do
  use QlariusWeb, :live_view

  alias Qlarius.YouData.Traits
  alias Qlarius.YouData.MeFiles
  alias QlariusWeb.Live.Helpers.ZipCodeLookup

  import QlariusWeb.MeFileHTML
  import QlariusWeb.PWAHelpers

  @impl true
  def render(assigns) do
    ~H"""
    <div id="mefile-pwa-detect" phx-hook="HiPagePWADetect">
      <Layouts.mobile {assigns}>
        <:modals>
          <.tag_edit_modal
            trait_in_edit={@trait_in_edit}
            me_file_id={@current_scope.user.me_file.id}
            selected_ids={@selected_child_trait_ids || []}
            show_modal={@show_modal}
            tag_edit_mode={@tag_edit_mode || "update"}
            zip_lookup_input={@zip_lookup_input}
            zip_lookup_trait={@zip_lookup_trait}
            zip_lookup_valid={@zip_lookup_valid}
            zip_lookup_error={@zip_lookup_error}
            dual_pane={true}
          />
        </:modals>

        <div class="mb-8 flex gap-2 justify-start items-center">
          <div class="text-xl">
            Edit/delete existing tags below. Add more tags via the Tagger.
          </div>
        </div>

        <div class="space-y-8 py-6 pb-24">
          <div :for={
            {{_id, name, _display_order}, parent_traits} <- @me_file_tag_map_by_category_trait_tag
          }>
            <div class="flex flex-row justify-between items-baseline mb-4">
              <h2 class="text-xl font-medium">{name}</h2>
              <span class="text-lg text-gray-500">
                {length(parent_traits)} tags
              </span>
            </div>

            <div class="flex flex-row flex-wrap gap-4">
              <.trait_card
                :for={
                  {parent_trait_id, parent_trait_name, parent_trait_display_order, tags_traits} <-
                    parent_traits
                }
                parent_trait_id={parent_trait_id}
                parent_trait_name={parent_trait_name}
                tags_traits={tags_traits}
                clickable={false}
              />
            </div>

            <div class="mt-8 border-b border-neutral-300 dark:border-neutral-500"></div>
          </div>

          <%!-- Inline Tagger button at bottom of list --%>
          <div
            id="inline-tagger-btn"
            class="flex justify-center mt-8"
            phx-hook="TaggerButtonObserver"
          >
            <.link
              navigate={~p"/me_file_builder"}
              class="btn btn-primary btn-lg rounded-full flex items-center gap-2 px-6 py-5 shadow-lg"
            >
              <.icon name="hero-plus" class="h-5 w-5" /> Add more tags
            </.link>
          </div>
        </div>

        <:floating_actions>
          <%!-- Floating Tagger button (hidden by default, shows when inline scrolls out) --%>
          <.link
            id="floating-tagger-btn"
            navigate={~p"/me_file_builder"}
            class="floating-action-btn btn btn-primary btn-lg rounded-full flex items-center gap-1 px-4 py-5 shadow-lg opacity-0 pointer-events-none transition-opacity duration-300"
          >
            <.icon name="hero-plus" class="h-5 w-5" /> Tagger
          </.link>
        </:floating_actions>
      </Layouts.mobile>
    </div>
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
      |> ZipCodeLookup.initialize_zip_lookup_assigns()
      |> push_event("scroll-tag-list-to-top", %{})

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
      |> ZipCodeLookup.initialize_zip_lookup_assigns()

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
      case socket.assigns.trait_in_edit.child_traits do
        %Ecto.Association.NotLoaded{} ->
          %{}

        child_traits when is_list(child_traits) ->
          Enum.reduce(child_traits, %{}, fn ct, acc ->
            Map.put(acc, ct.id, (ct.survey_answer && ct.survey_answer.text) || ct.trait_name)
          end)

        _ ->
          %{}
      end

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

  def handle_event("lookup_zip_code", %{"zip_code_input" => zip_code}, socket) do
    socket = ZipCodeLookup.handle_zip_lookup(socket, zip_code)
    {:noreply, socket}
  end

  def handle_event(
        "perform_delete_tags",
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

  def handle_event("pwa_detected", params, socket) do
    handle_pwa_detection(socket, params)
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
    |> assign(:current_path, "/me_file")
    |> assign_me_file_tags()
    |> assign(:trait_in_edit, nil)
    |> assign(:selected_child_trait_ids, [])
    |> assign(:show_modal, false)
    |> assign(:tag_edit_mode, "update")
    |> assign(:zip_lookup_input, "")
    |> assign(:zip_lookup_trait, nil)
    |> assign(:zip_lookup_valid, false)
    |> assign(:zip_lookup_error, nil)
    |> init_pwa_assigns()
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
