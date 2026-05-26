defmodule QlariusWeb.MeFileLive do
  use QlariusWeb, :live_view

  alias Qlarius.YouData.Traits
  alias Qlarius.YouData.MeFiles
  alias QlariusWeb.Live.Helpers.ZipCodeLookup

  import QlariusWeb.MeFileHTML
  import QlariusWeb.PWAHelpers

  on_mount {QlariusWeb.DetectMobile, :detect_mobile}

  @impl true
  def render(assigns) do
    ~H"""
    <div id="mefile-pwa-detect" phx-hook="HiPagePWADetect MeFilePanelScroll">
      <Layouts.mobile {assigns}>
        <:modals>
          <.tag_edit_modal
            trait_in_edit={@trait_in_edit}
            me_file_id={@current_scope.user.me_file.id}
            selected_ids={@selected_child_trait_ids || []}
            show_modal={@show_modal}
            show_delete_confirm={@show_delete_confirm}
            zip_lookup_input={@zip_lookup_input}
            zip_lookup_trait={@zip_lookup_trait}
            zip_lookup_valid={@zip_lookup_valid}
            zip_lookup_error={@zip_lookup_error}
            dual_pane={true}
            show_expanded_tags={@show_expanded_tags}
            is_pwa={@is_pwa}
          />
        </:modals>

        <Layouts.mobile_page_intro>
          Manage your tags below.
        </Layouts.mobile_page_intro>

        <div class="pt-2">
          <.tags_display
            tag_display_map={@tag_display_map}
            tag_display_mode={@tag_display_mode}
            tag_search={@tag_search}
            tag_search_epoch={@tag_search_epoch}
          />
        </div>

        <:floating_actions>
          <.mefile_floating_toolbar
            tag_search={@tag_search}
            tag_display_mode={@tag_display_mode}
            show_tag_search={@show_tag_search}
            show_view_menu={@show_view_menu}
          />
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
      |> assign(:show_delete_confirm, false)
      |> ZipCodeLookup.initialize_zip_lookup_assigns()
      |> push_event("scroll-tag-list-to-top", %{})

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, socket |> assign(:show_modal, false) |> assign(:show_delete_confirm, false)}
  end

  def handle_event("request_delete_confirm", _params, socket) do
    if (socket.assigns.selected_child_trait_ids || []) == [] do
      {:noreply, socket}
    else
      {:noreply, assign(socket, :show_delete_confirm, !socket.assigns.show_delete_confirm)}
    end
  end

  def handle_event("cancel_delete_confirm", _params, socket) do
    {:noreply, assign(socket, :show_delete_confirm, false)}
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
      |> assign(:show_delete_confirm, false)
      |> assign_filtered_tag_display()
      |> push_event("animate_trait", %{trait_id: trait_id, delay_ms: 250, value: "update_pulse"})

    {:noreply, socket}
  end

  def handle_event("lookup_zip_code", %{"zip_code_input" => zip_code}, socket) do
    socket = ZipCodeLookup.handle_zip_lookup(socket, zip_code)
    {:noreply, socket}
  end

  def handle_event("confirm_delete_tags", _params, socket) do
    trait_id = socket.assigns.trait_in_edit.id
    child_trait_ids = socket.assigns.selected_child_trait_ids || []

    if child_trait_ids == [] do
      {:noreply, socket}
    else
      socket =
        socket
        |> push_event("animate_trait", %{trait_id: trait_id, delay_ms: 0, value: "delete_fade"})
        |> assign(:show_modal, false)
        |> assign(:show_delete_confirm, false)

      Process.send_after(
        self(),
        {:perform_tag_deletion, trait_id, child_trait_ids, socket.assigns.current_scope},
        950
      )

      {:noreply, socket}
    end
  end

  def handle_event("pwa_detected", params, socket) do
    handle_pwa_detection(socket, params)
  end

  def handle_event("referral_code_from_storage", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("set_tag_view", %{"expanded" => expanded}, socket) do
    {:noreply, assign(socket, :show_expanded_tags, expanded == "true")}
  end

  def handle_event("toggle_tag_search", _params, socket) do
    show = !socket.assigns.show_tag_search

    {:noreply,
     socket
     |> assign(:show_tag_search, show)
     |> assign(:show_view_menu, false)}
  end

  def handle_event("hide_tag_search", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_tag_search, false)
     |> assign(:show_view_menu, false)}
  end

  def handle_event("toggle_view_menu", _params, socket) do
    show = !socket.assigns.show_view_menu

    {:noreply,
     socket
     |> assign(:show_view_menu, show)
     |> assign(:show_tag_search, false)}
  end

  def handle_event("tag_search_changed", params, socket) do
    search = Map.get(params, "tag_search", "")

    {:noreply,
     socket
     |> assign(:tag_search, search)
     |> assign_filtered_tag_display()
     |> bump_tag_search_epoch()
     |> push_event("scroll-mefile-tags-to-top", %{})}
  end

  def handle_event("clear_tag_search", _params, socket) do
    {:noreply,
     socket
     |> assign(:tag_search, "")
     |> assign(:show_view_menu, false)
     |> assign_me_file_tags()
     |> assign_filtered_tag_display()
     |> bump_tag_search_epoch()
     |> push_event("scroll-mefile-tags-to-top", %{})}
  end

  def handle_event("set_tag_display_mode", %{"mode" => mode}, socket)
      when mode in ~w(tag block list) do
    me_file = socket.assigns.current_scope.user.me_file

    case MeFiles.update_tag_display_mode(me_file, mode) do
      {:ok, updated_me_file} ->
        {:noreply,
         socket
         |> assign(:tag_display_mode, updated_me_file.tag_display_mode)
         |> assign(:show_view_menu, false)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not update display mode")}
    end
  end

  def handle_event("sync_tag_selection", params, socket) do
    case socket.assigns.trait_in_edit do
      %{input_type: type} when type in ["multi_select", "single_select"] ->
        ids = child_trait_ids_from_form_params(params)
        {:noreply, assign(socket, :selected_child_trait_ids, ids)}

      _ ->
        {:noreply, socket}
    end
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

    me_file_id = current_scope.user.me_file.id
    updated_parent_tuple = MeFiles.parent_trait_with_tags_for_mefile(me_file_id, trait_id)

    socket =
      socket
      |> update(:me_file_tag_map_by_category_trait_tag, fn cat_map ->
        cat_map
        |> Enum.map(fn {category, parent_traits} ->
          {category,
           Enum.map(parent_traits, fn
             {id, _name, _order, _tags} when id == trait_id -> updated_parent_tuple
             other -> other
           end)}
        end)
        |> Enum.reject(fn {_category, parent_traits} -> parent_traits == [] end)
      end)
      |> assign(:selected_child_trait_ids, [])
      |> assign_filtered_tag_display()

    {:noreply, socket}
  end

  @impl true
  def mount(_params, session, socket) do
    socket
    |> assign(:title, "MeFile")
    |> assign(:current_path, "/me_file")
    |> assign_me_file_tags()
    |> assign(:trait_in_edit, nil)
    |> assign(:selected_child_trait_ids, [])
    |> assign(:show_modal, false)
    |> assign(:show_delete_confirm, false)
    |> assign(:zip_lookup_input, "")
    |> assign(:zip_lookup_trait, nil)
    |> assign(:zip_lookup_valid, false)
    |> assign(:zip_lookup_error, nil)
    |> assign(:show_expanded_tags, false)
    |> assign(:tag_search, "")
    |> assign(:tag_search_epoch, 0)
    |> assign(:show_tag_search, false)
    |> assign(:show_view_menu, false)
    |> assign_tag_display_mode()
    |> assign_filtered_tag_display()
    |> init_pwa_assigns(session)
    |> ok()
  end

  defp assign_tag_display_mode(socket) do
    mode =
      case socket.assigns.current_scope.user.me_file do
        %{tag_display_mode: mode} when mode in ~w(tag block list) -> mode
        _ -> "tag"
      end

    assign(socket, :tag_display_mode, mode)
  end

  defp assign_me_file_tags(socket) do
    me_file_id = socket.assigns.current_scope.user.me_file.id

    assign(
      socket,
      :me_file_tag_map_by_category_trait_tag,
      MeFiles.me_file_tag_map_by_category_trait_tag(me_file_id)
    )
  end

  defp assign_filtered_tag_display(socket) do
    display_map =
      filter_tag_map_by_search(
        socket.assigns.me_file_tag_map_by_category_trait_tag,
        socket.assigns.tag_search
      )

    assign(socket, :tag_display_map, display_map)
  end

  defp bump_tag_search_epoch(socket) do
    assign(socket, :tag_search_epoch, socket.assigns.tag_search_epoch + 1)
  end

  defp child_trait_ids_from_form_params(params) do
    params
    |> Map.get("child_trait_ids")
    |> List.wrap()
    |> Enum.flat_map(fn raw ->
      case Integer.parse(to_string(raw)) do
        {id, _} -> [id]
        :error -> []
      end
    end)
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
