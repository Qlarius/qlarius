defmodule QlariusWeb.Live.Marketers.TraitsManagerLive do
  use QlariusWeb, :live_view

  import QlariusWeb.Components.MarketerUI

  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar, Targeting}
  alias Qlarius.YouData.TraitSearch
  alias Qlarius.YouData.Traits
  alias QlariusWeb.Live.Marketers.CurrentMarketer
  alias QlariusWeb.Live.{TopicEditing, TraitGroupEditorComponent}

  on_mount {CurrentMarketer, :load_current_marketer}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Traits")
     |> assign(:copy, Targeting.copy(:target))
     |> TopicEditing.close()
     |> assign_trait_data()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    TopicEditing.close(socket)
  end

  defp apply_action(socket, :new_trait_group, %{"parent_trait_id" => parent_trait_id}) do
    with_marketer(socket, fn socket ->
      TopicEditing.open_new(socket, to_id(parent_trait_id))
    end)
  end

  defp apply_action(socket, :new_trait_group, _params) do
    push_patch(socket, to: ~p"/marketer/traits")
  end

  defp apply_action(socket, :edit_topic, %{"id" => id, "parent_trait_id" => parent_trait_id}) do
    with_marketer(socket, fn socket ->
      group = Traits.get_trait_group_for_owner!(id, owner(socket))
      TopicEditing.open_topic(socket, group, to_id(parent_trait_id), socket.assigns.copy)
    end)
  end

  defp with_marketer(socket, fun) do
    if socket.assigns.current_marketer do
      fun.(socket)
    else
      socket
      |> put_flash(:error, "Please select a marketer first")
      |> push_patch(to: ~p"/marketer/traits")
    end
  end

  defp to_id(id) when is_integer(id), do: id
  defp to_id(id) when is_binary(id), do: String.to_integer(id)

  defp owner(socket), do: {:marketer, socket.assigns.current_marketer.id}

  defp topic_path(group, parent_trait_id) do
    ~p"/marketer/traits/#{group.id}/topics/#{parent_trait_id}"
  end

  defp browser_path(nil, parent_trait_id) do
    ~p"/marketer/traits/new?parent_trait_id=#{parent_trait_id}"
  end

  defp browser_path(group, parent_trait_id), do: topic_path(group, parent_trait_id)

  defp assign_trait_data(socket) do
    if socket.assigns.current_marketer do
      owner = owner(socket)
      search_term = socket.assigns[:search_term] || ""
      trait_groups = Traits.list_trait_groups_for_owner(owner)
      role_filter = socket.assigns[:role_filter] || "all"

      socket
      |> assign(:trait_groups, trait_groups)
      |> assign(:role_filter, role_filter)
      |> assign(:visible_trait_groups, Targeting.filter_by_role(trait_groups, role_filter))
      |> assign(:archived_trait_groups, Traits.list_archived_trait_groups_for_owner(owner))
      |> assign(:categories_with_traits, Traits.list_trait_categories_with_traits())
      |> assign(:search_term, search_term)
      |> assign(:trait_match_ids, TraitSearch.matching_parent_ids(search_term))
      |> assign(:show_archived, socket.assigns[:show_archived] || false)
    else
      socket
      |> assign(:trait_groups, [])
      |> assign(:role_filter, "all")
      |> assign(:visible_trait_groups, [])
      |> assign(:archived_trait_groups, [])
      |> assign(:categories_with_traits, [])
      |> assign(:search_term, "")
      |> assign(:trait_match_ids, nil)
      |> assign(:show_archived, false)
    end
  end

  @impl true
  def handle_info({TraitGroupEditorComponent, :saved, _group}, socket) do
    message =
      if socket.assigns.editor_group_id,
        do: "Trait group saved",
        else: "Trait group created successfully"

    {:noreply,
     socket
     |> put_flash(:info, message)
     |> assign_trait_data()
     |> push_patch(to: ~p"/marketer/traits")}
  end

  def handle_info({TraitGroupEditorComponent, :closed}, socket) do
    {:noreply, push_patch(socket, to: ~p"/marketer/traits")}
  end

  def handle_info({TraitGroupEditorComponent, :failed, message}, socket) do
    {:noreply,
     socket
     |> put_flash(:error, message)
     |> push_patch(to: ~p"/marketer/traits")}
  end

  @impl true
  def handle_event("add_topic", %{"group_id" => id}, socket) do
    with_marketer_event(socket, fn socket ->
      group = Traits.get_trait_group_for_owner!(id, owner(socket))
      assign(socket, :adding_topic_to, group)
    end)
  end

  def handle_event("cancel_add_topic", _params, socket) do
    {:noreply, assign(socket, :adding_topic_to, nil)}
  end

  def handle_event("remove_topic", %{"group_id" => id, "parent_trait_id" => parent_id}, socket) do
    with_marketer_event(socket, fn socket ->
      group = Traits.get_trait_group_for_owner!(id, owner(socket))
      {kind, message} = TopicEditing.remove_topic(group, to_id(parent_id), socket.assigns.copy)
      socket |> put_flash(kind, message) |> assign_trait_data()
    end)
  end

  def handle_event("delete_trait_group", %{"id" => id}, socket) do
    with_marketer_event(socket, fn socket ->
      trait_group = Traits.get_trait_group_for_owner!(id, owner(socket))

      cond do
        trait_group.target_band_count > 0 ->
          put_flash(
            socket,
            :error,
            "Cannot delete trait group that is in use. Please deactivate instead."
          )

        match?({:ok, _}, Traits.delete_trait_group(trait_group)) ->
          socket
          |> put_flash(:info, "Trait group deleted successfully")
          |> assign_trait_data()

        true ->
          put_flash(socket, :error, "Failed to delete trait group")
      end
    end)
  end

  def handle_event("deactivate_trait_group", %{"id" => id}, socket) do
    with_marketer_event(socket, fn socket ->
      trait_group = Traits.get_trait_group_for_owner!(id, owner(socket))

      case Traits.deactivate_trait_group(trait_group) do
        {:ok, _} ->
          socket
          |> put_flash(:info, "Trait group deactivated successfully")
          |> assign_trait_data()

        {:error, _} ->
          put_flash(socket, :error, "Failed to deactivate trait group")
      end
    end)
  end

  def handle_event("reactivate_trait_group", %{"id" => id}, socket) do
    with_marketer_event(socket, fn socket ->
      trait_group = Traits.get_trait_group_for_owner!(id, owner(socket))

      case Traits.reactivate_trait_group(trait_group) do
        {:ok, _} ->
          socket
          |> put_flash(:info, "Trait group reactivated successfully")
          |> assign_trait_data()

        {:error, _} ->
          put_flash(socket, :error, "Failed to reactivate trait group")
      end
    end)
  end

  def handle_event("toggle_archived", _params, socket) do
    {:noreply, assign(socket, :show_archived, !socket.assigns.show_archived)}
  end

  def handle_event("filter_role", %{"role" => role}, socket) when role in ~w(all include anti) do
    {:noreply,
     assign(socket,
       role_filter: role,
       visible_trait_groups: Targeting.filter_by_role(socket.assigns.trait_groups, role)
     )}
  end

  def handle_event("search_traits", %{"search" => search_term}, socket) do
    search_term = String.trim(search_term)

    {:noreply,
     assign(socket,
       search_term: search_term,
       trait_match_ids: TraitSearch.matching_parent_ids(search_term)
     )}
  end

  def handle_event("clear_search", _params, socket) do
    {:noreply, assign(socket, search_term: "", trait_match_ids: nil)}
  end

  defp with_marketer_event(socket, fun) do
    if socket.assigns.current_marketer do
      {:noreply, fun.(socket)}
    else
      {:noreply, put_flash(socket, :error, "No marketer selected")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin {assigns}>
      <div class="flex h-screen">
        <AdminSidebar.sidebar current_user={@current_scope.user} current_path={@current_path} />

        <div class="flex min-w-0 grow flex-col">
          <AdminTopbar.topbar current_user={@current_scope.user} />

          <div class="overflow-auto">
            <.current_marketer_bar
              current_marketer={@current_marketer}
              current_path={~p"/marketer/traits"}
            />

            <.live_component
              :if={@current_marketer}
              module={TraitGroupEditorComponent}
              id="trait-group-editor"
              owner={{:marketer, @current_marketer.id}}
              parent_trait_id={@editor_parent_trait_id}
              group_id={@editor_group_id}
              preselected_ids={@editor_preselected_ids}
              title={@editor_title}
              description={@editor_description}
              heading={@editor_heading}
              submit_label={@editor_submit_label}
              zip_seed={@editor_zip_seed}
              on_save={@editor_on_save}
            />

            <.no_marketer_notice
              :if={!@current_marketer}
              message="Choose a marketer to manage their trait groups."
            />

            <.page :if={@current_marketer}>
              <.page_header
                title="Trait groups"
                count={length(@trait_groups)}
                subtitle="Reusable bundles of traits for your targets. Pick a trait in the browser to start a group."
              />

              <div class="grid items-start gap-8 lg:grid-cols-[minmax(0,1fr)_360px]">
                <div class="min-w-0">
                  <div class="mb-3 flex justify-end">
                    <Targeting.role_filter groups={@trait_groups} value={@role_filter} />
                  </div>
                  <.panel flush>
                    <.empty_state
                      :if={@trait_groups == []}
                      icon="hero-squares-plus"
                      title="No trait groups yet"
                    >
                      Pick a trait in the browser to create your first trait group.
                    </.empty_state>
                    <p
                      :if={@trait_groups != [] and @visible_trait_groups == []}
                      class="px-6 py-4 text-sm text-base-content/60"
                    >
                      No groups with that role.
                    </p>
                    <Targeting.trait_group_list
                      :if={@visible_trait_groups != []}
                      trait_groups={@visible_trait_groups}
                      archived={false}
                      deactivate_confirm="Deactivate this trait group? It is used by a target."
                      topic_path={&topic_path/2}
                    />
                  </.panel>

                  <.archived_section
                    label="Archived trait groups"
                    count={length(@archived_trait_groups)}
                    open={@show_archived}
                    toggle="toggle_archived"
                  >
                    <.panel flush>
                      <Targeting.trait_group_list
                        trait_groups={@archived_trait_groups}
                        archived={true}
                        topic_path={&topic_path/2}
                      />
                    </.panel>
                  </.archived_section>
                </div>

                <Targeting.trait_browser
                  categories={@categories_with_traits}
                  search_term={@search_term}
                  trait_match_ids={@trait_match_ids}
                  adding_to={@adding_topic_to}
                  topic_path={&browser_path(@adding_topic_to, &1)}
                />
              </div>
            </.page>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end
end
