defmodule QlariusWeb.Creators.TraitGroupsLive do
  use QlariusWeb, :live_view

  alias Qlarius.Creators
  alias Qlarius.Repo
  alias Qlarius.Sponster.Campaigns.TraitGroup
  alias Qlarius.YouData.Traits
  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar, Targeting}

  @impl true
  def mount(%{"creator_id" => creator_id}, _session, socket) do
    creator = Creators.accessible_creator!(socket.assigns.current_scope, creator_id)

    {:ok,
     socket
     |> assign(:creator, creator)
     |> assign(:page_title, "Trait groups")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Trait groups")
    |> assign(:show_modal, false)
    |> assign(:selected_parent_trait, nil)
    |> assign(:trait_group_form, nil)
    |> assign(:zip_search_term, "")
    |> assign(:selected_zips, [])
    |> assign(:zip_search_results, [])
    |> assign_trait_data()
  end

  defp apply_action(socket, :new_trait_group, %{"parent_trait_id" => parent_trait_id}) do
    parent_id = parent_trait_id_from_param(parent_trait_id)

    if socket.assigns[:show_modal] &&
         match?(%{id: ^parent_id}, socket.assigns[:selected_parent_trait]) do
      socket
    else
      open_new_trait_group_modal(socket, parent_id)
    end
  end

  defp apply_action(socket, :new_trait_group, _params) do
    push_navigate(socket, to: ~p"/creators/#{socket.assigns.creator.id}/trait-groups")
  end

  defp parent_trait_id_from_param(id) when is_integer(id), do: id
  defp parent_trait_id_from_param(id) when is_binary(id), do: String.to_integer(id)

  defp open_new_trait_group_modal(socket, parent_trait_id) do
    parent_trait = Traits.get_trait_with_full_survey_data!(parent_trait_id)

    case parent_trait do
      {:ok, trait} ->
        form =
          %TraitGroup{}
          |> TraitGroup.changeset(%{"creator_id" => socket.assigns.creator.id})
          |> to_form(as: :trait_group, id: "trait-group-form")

        socket
        |> assign(:show_modal, true)
        |> assign(:selected_parent_trait, trait)
        |> assign(:trait_group_form, form)
        |> assign(:selected_ids, [])
        |> assign(:zip_search_term, "")
        |> assign(:selected_zips, [])
        |> assign(:zip_search_results, [])
        |> assign(:zip_search_limit, 1000)
        |> assign_trait_data()

      {:error, _} ->
        socket
        |> put_flash(:error, "Selected trait is not a parent trait")
        |> push_navigate(to: ~p"/creators/#{socket.assigns.creator.id}/trait-groups")
    end
  end

  defp assign_trait_group_form(socket, params) do
    trait_group_params = Map.get(params, "trait_group", %{})

    form =
      %TraitGroup{}
      |> TraitGroup.changeset(trait_group_params)
      |> Map.put(:action, :validate)
      |> to_form(as: :trait_group, id: "trait-group-form")

    assign(socket, :trait_group_form, form)
  end

  defp assign_zip_search(socket, params) do
    search_term = params |> Map.get("search", "") |> to_string() |> String.trim()
    trait_group_params = Map.get(params, "trait_group", %{})

    form =
      %TraitGroup{}
      |> TraitGroup.changeset(trait_group_params)
      |> Map.put(:action, :validate)
      |> to_form(as: :trait_group, id: "trait-group-form")

    socket = assign(socket, :trait_group_form, form)

    if socket.assigns.selected_parent_trait &&
         socket.assigns.selected_parent_trait.input_type == "single_select_zip" &&
         String.length(search_term) >= 2 do
      limit = Map.get(socket.assigns, :zip_search_limit, 1000)

      results =
        Traits.search_zip_codes(socket.assigns.selected_parent_trait.id, search_term, limit)

      socket
      |> assign(:zip_search_term, search_term)
      |> assign(:zip_search_results, results)
    else
      socket
      |> assign(:zip_search_term, search_term)
      |> assign(:zip_search_results, [])
    end
  end

  defp assign_trait_data(socket) do
    owner = {:creator, socket.assigns.creator.id}

    socket
    |> assign(:trait_groups, Traits.list_trait_groups_for_owner(owner))
    |> assign(:archived_trait_groups, Traits.list_archived_trait_groups_for_owner(owner))
    |> assign(:categories_with_traits, Traits.list_trait_categories_with_traits())
    |> assign(:search_term, socket.assigns[:search_term] || "")
    |> assign(:show_archived, socket.assigns[:show_archived] || false)
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/creators/#{socket.assigns.creator.id}/trait-groups")}
  end

  def handle_event("validate_trait_group", params, socket) do
    socket = assign(socket, :selected_ids, Targeting.trait_ids_from_params(params))
    target = List.wrap(params["_target"])

    cond do
      List.first(target) == "search" ->
        {:noreply, assign_zip_search(socket, params)}

      List.first(target) == "trait_group" ->
        {:noreply, assign_trait_group_form(socket, params)}

      true ->
        {:noreply, socket}
    end
  end

  def handle_event("change_zip_limit", %{"limit" => limit_value}, socket) do
    limit =
      case limit_value do
        "all" -> :all
        value -> String.to_integer(value)
      end

    socket = assign(socket, :zip_search_limit, limit)
    search_term = Map.get(socket.assigns, :zip_search_term, "")

    socket =
      if socket.assigns.selected_parent_trait.input_type == "single_select_zip" &&
           String.length(String.trim(search_term)) >= 2 do
        parent_trait_id = socket.assigns.selected_parent_trait.id
        results = Traits.search_zip_codes(parent_trait_id, search_term, limit)
        assign(socket, :zip_search_results, results)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event(
        "save_trait_group",
        %{"trait_group" => trait_group_params, "trait_ids" => trait_ids},
        socket
      ) do
    trait_ids_list = if is_list(trait_ids), do: trait_ids, else: []

    if trait_ids_list == [] do
      {:noreply,
       socket
       |> put_flash(:error, "Please select at least one trait")
       |> assign(
         :trait_group_form,
         to_form(
           TraitGroup.changeset(%TraitGroup{}, trait_group_params)
           |> Map.put(:action, :validate)
         )
       )}
    else
      attrs =
        trait_group_params
        |> Map.put("trait_ids", trait_ids_list)
        |> Map.put("creator_id", socket.assigns.creator.id)
        |> Map.put("parent_trait_id", socket.assigns.selected_parent_trait.id)

      case Traits.create_trait_group(attrs) do
        {:ok, _trait_group} ->
          {:noreply,
           socket
           |> put_flash(:info, "Trait group created successfully")
           |> push_navigate(to: ~p"/creators/#{socket.assigns.creator.id}/trait-groups")}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, :trait_group_form, to_form(changeset))}
      end
    end
  end

  def handle_event("save_trait_group", %{"trait_group" => trait_group_params}, socket) do
    if socket.assigns.selected_parent_trait.input_type == "single_select_zip" do
      if socket.assigns.selected_zips == [] do
        {:noreply,
         socket
         |> put_flash(:error, "Please select at least one zip code")
         |> assign(
           :trait_group_form,
           to_form(
             TraitGroup.changeset(%TraitGroup{}, trait_group_params)
             |> Map.put(:action, :validate)
           )
         )}
      else
        trait_ids_list = Enum.map(socket.assigns.selected_zips, &Integer.to_string(&1.id))

        attrs =
          trait_group_params
          |> Map.put("trait_ids", trait_ids_list)
          |> Map.put("creator_id", socket.assigns.creator.id)
          |> Map.put("parent_trait_id", socket.assigns.selected_parent_trait.id)

        case Traits.create_trait_group(attrs) do
          {:ok, _trait_group} ->
            {:noreply,
             socket
             |> put_flash(:info, "Trait group created successfully")
             |> push_navigate(to: ~p"/creators/#{socket.assigns.creator.id}/trait-groups")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :trait_group_form, to_form(changeset))}
        end
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "Please select at least one trait")
       |> assign(
         :trait_group_form,
         to_form(socket.assigns.trait_group_form.source |> Map.put(:action, :validate))
       )}
    end
  end

  def handle_event("delete_trait_group", %{"id" => id}, socket) do
    trait_group =
      Traits.get_trait_group_for_owner!(id, {:creator, socket.assigns.creator.id})

    if trait_group.target_band_count > 0 do
      {:noreply,
       put_flash(
         socket,
         :error,
         "Cannot delete trait group that is in use. Please deactivate instead."
       )}
    else
      case Traits.delete_trait_group(trait_group) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Trait group deleted successfully")
           |> assign_trait_data()}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete trait group")}
      end
    end
  end

  def handle_event("deactivate_trait_group", %{"id" => id}, socket) do
    trait_group =
      Traits.get_trait_group_for_owner!(id, {:creator, socket.assigns.creator.id})

    case Traits.deactivate_trait_group(trait_group) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Trait group deactivated successfully")
         |> assign_trait_data()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to deactivate trait group")}
    end
  end

  def handle_event("reactivate_trait_group", %{"id" => id}, socket) do
    trait_group =
      Traits.get_trait_group_for_owner!(id, {:creator, socket.assigns.creator.id})

    case Traits.reactivate_trait_group(trait_group) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Trait group reactivated successfully")
         |> assign_trait_data()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to reactivate trait group")}
    end
  end

  def handle_event("toggle_archived", _params, socket) do
    {:noreply, assign(socket, :show_archived, !socket.assigns.show_archived)}
  end

  def handle_event("search_traits", %{"search" => search_term}, socket) do
    {:noreply, assign(socket, :search_term, String.trim(search_term))}
  end

  def handle_event("clear_search", _params, socket) do
    {:noreply, assign(socket, :search_term, "")}
  end

  def handle_event("add_selected_zips", %{"selected_ids" => selected_ids}, socket) do
    selected_ids = if is_list(selected_ids), do: selected_ids, else: [selected_ids]
    new_zip_ids = Enum.map(selected_ids, &String.to_integer/1)

    new_zips =
      Enum.map(new_zip_ids, fn id ->
        Repo.get!(Qlarius.YouData.Traits.Trait, id)
        |> then(fn trait ->
          %{id: trait.id, zip_code: trait.trait_name, location: trait.meta_1}
        end)
      end)

    updated_zips =
      (socket.assigns.selected_zips ++ new_zips)
      |> Enum.uniq_by(& &1.id)
      |> Enum.sort_by(&String.to_integer(&1.zip_code))

    {:noreply, assign(socket, :selected_zips, updated_zips)}
  end

  def handle_event("add_selected_zips", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("add_all_visible_zips", _params, socket) do
    parent_trait_id = socket.assigns.selected_parent_trait.id
    search_term = socket.assigns.zip_search_term
    limit = Map.get(socket.assigns, :zip_search_limit, 1000)

    visible_zips = Traits.search_zip_codes(parent_trait_id, search_term, limit)

    updated_zips =
      (socket.assigns.selected_zips ++ visible_zips)
      |> Enum.uniq_by(& &1.id)
      |> Enum.sort_by(&String.to_integer(&1.zip_code))

    {:noreply, assign(socket, :selected_zips, updated_zips)}
  end

  def handle_event("remove_selected_zips", %{"selected_ids" => selected_ids}, socket) do
    selected_ids = if is_list(selected_ids), do: selected_ids, else: [selected_ids]
    remove_ids = Enum.map(selected_ids, &String.to_integer/1)
    updated_zips = Enum.reject(socket.assigns.selected_zips, &(&1.id in remove_ids))

    {:noreply, assign(socket, :selected_zips, updated_zips)}
  end

  def handle_event("remove_selected_zips", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("clear_all_zips", _params, socket) do
    {:noreply, assign(socket, :selected_zips, [])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin {assigns}>
      <div class="flex h-screen">
        <AdminSidebar.sidebar current_user={@current_scope.user} />

        <div class="flex min-w-0 grow flex-col page-canvas">
          <AdminTopbar.topbar current_user={@current_scope.user} />

          <div class="overflow-auto flex-1">
            <Targeting.trait_group_modal
              :if={@show_modal}
              show_modal={@show_modal}
              parent_trait={@selected_parent_trait}
              form={@trait_group_form}
              zip_search_term={Map.get(assigns, :zip_search_term, "")}
              zip_search_results={Map.get(assigns, :zip_search_results, [])}
              selected_zips={Map.get(assigns, :selected_zips, [])}
              zip_search_limit={Map.get(assigns, :zip_search_limit, 1000)}
              selected_ids={Map.get(assigns, :selected_ids, [])}
            />

            <div class="p-6">
              <div class="flex items-center justify-between mb-6">
                <div>
                  <h1 class="text-2xl font-bold">Trait groups</h1>
                  <p class="text-base-content/60">{@creator.name}</p>
                </div>
                <div class="flex gap-2">
                  <.link navigate={~p"/creators/#{@creator.id}/audiences"} class="btn btn-ghost">
                    Audiences
                  </.link>
                  <.link navigate={~p"/creators/#{@creator.id}"} class="btn btn-ghost">
                    Back
                  </.link>
                </div>
              </div>

              <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
                <div class="lg:col-span-2">
                  <div
                    :if={@trait_groups == []}
                    class="card bg-base-100 dark:bg-base-200 border border-base-300"
                  >
                    <div class="card-body text-center py-12">
                      <.icon
                        name="hero-document-plus"
                        class="w-16 h-16 mx-auto text-base-content/30 mb-4"
                      />
                      <p class="text-lg font-medium text-base-content/70">No trait groups yet</p>
                      <p class="text-sm text-base-content/50 mt-2">
                        Select a trait from the browser on the right to create your first trait group
                      </p>
                    </div>
                  </div>

                  <div :if={@trait_groups != []} class="overflow-x-auto">
                    <table class="table table-zebra">
                      <thead>
                        <tr>
                          <th>Trait Group Name</th>
                          <th>Traits</th>
                          <th class="text-center">MeFiles</th>
                          <th class="text-center">Audiences</th>
                          <th class="text-center"></th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr :for={group <- @trait_groups}>
                          <td class="font-medium !align-top">{group.title}</td>
                          <td class="text-sm !align-top">
                            <.trait_badges traits={group.traits} />
                          </td>
                          <td class="text-center !align-top">{group.me_file_count}</td>
                          <td class="text-center !align-top">{group.target_band_count}</td>
                          <td class="text-center !align-top">
                            <button
                              :if={group.target_band_count == 0}
                              phx-click="delete_trait_group"
                              phx-value-id={group.id}
                              class="btn btn-sm btn-error btn-outline"
                              data-confirm="Delete this trait group? This cannot be undone."
                            >
                              Delete
                            </button>
                            <button
                              :if={group.target_band_count > 0}
                              phx-click="deactivate_trait_group"
                              phx-value-id={group.id}
                              class="btn btn-sm btn-warning btn-outline"
                              data-confirm="Deactivate this trait group? It is currently in use."
                            >
                              Deactivate
                            </button>
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </div>

                  <div
                    :if={@archived_trait_groups != []}
                    class="mt-8 border-t border-base-300 pt-6"
                  >
                    <button phx-click="toggle_archived" class="btn btn-ghost btn-sm mb-4">
                      <.icon
                        name={if @show_archived, do: "hero-chevron-down", else: "hero-chevron-right"}
                        class="w-4 h-4"
                      /> Archived Trait Groups ({length(@archived_trait_groups)})
                    </button>

                    <div :if={@show_archived} class="overflow-x-auto">
                      <table class="table">
                        <thead>
                          <tr>
                            <th>Trait Group Name</th>
                            <th>Traits</th>
                            <th class="text-center">MeFiles</th>
                            <th class="text-center">Band Usage</th>
                            <th class="text-center">Actions</th>
                          </tr>
                        </thead>
                        <tbody>
                          <tr :for={group <- @archived_trait_groups} class="opacity-60">
                            <td class="font-medium !align-top">{group.title}</td>
                            <td class="text-sm !align-top">
                              <.trait_badges traits={group.traits} />
                            </td>
                            <td class="text-center !align-top">{group.me_file_count}</td>
                            <td class="text-center !align-top">{group.target_band_count}</td>
                            <td class="text-center !align-top">
                              <button
                                phx-click="reactivate_trait_group"
                                phx-value-id={group.id}
                                class="btn btn-sm btn-success btn-outline"
                              >
                                Reactivate
                              </button>
                            </td>
                          </tr>
                        </tbody>
                      </table>
                    </div>
                  </div>
                </div>

                <div class="lg:col-span-1">
                  <div class="sticky top-6">
                    <h2 class="text-xl font-bold mb-4">Trait Browser</h2>

                    <form phx-change="search_traits" class="mb-4">
                      <label class="input input-bordered flex items-center gap-2">
                        <.icon name="hero-magnifying-glass" class="w-5 h-5 opacity-70" />
                        <input
                          type="text"
                          phx-debounce="300"
                          name="search"
                          value={@search_term}
                          placeholder="Search traits..."
                          class="grow"
                          autocomplete="off"
                        />
                        <button
                          :if={@search_term != ""}
                          type="button"
                          phx-click="clear_search"
                          class="btn btn-ghost btn-xs btn-circle"
                        >
                          <.icon name="hero-x-mark" class="w-4 h-4" />
                        </button>
                      </label>
                    </form>

                    <div class="space-y-4 max-h-[calc(100vh-16rem)] overflow-y-auto">
                      <div :for={category <- filter_categories(@categories_with_traits, @search_term)}>
                        <div class="collapse collapse-arrow bg-base-200 dark:bg-base-300/70 border border-base-300 dark:border-base-content/10">
                          <input type="checkbox" checked />
                          <div class="collapse-title font-medium">
                            {category.name}
                            <span class="text-sm text-base-content/50 ml-2">
                              ({length(category.traits)})
                            </span>
                          </div>
                          <div class="collapse-content">
                            <div class="space-y-2">
                              <.link
                                :for={trait <- category.traits}
                                navigate={
                                  ~p"/creators/#{@creator.id}/trait-groups/new?parent_trait_id=#{trait.id}"
                                }
                                class="flex items-center justify-between p-2 hover:bg-base-100 dark:hover:bg-base-200 rounded cursor-pointer group"
                              >
                                <span class="text-sm">{trait.trait_name}</span>
                                <.icon
                                  name="hero-plus-circle"
                                  class="w-5 h-5 text-primary opacity-0 group-hover:opacity-100 transition-opacity"
                                />
                              </.link>
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  defp filter_categories(categories, search_term) do
    if search_term == "" do
      categories
    else
      search_term_lower = String.downcase(search_term)

      Enum.map(categories, fn category ->
        filtered_traits =
          Enum.filter(category.traits, fn trait ->
            String.contains?(String.downcase(trait.trait_name), search_term_lower) ||
              String.contains?(String.downcase(category.name), search_term_lower)
          end)

        %{category | traits: filtered_traits}
      end)
      |> Enum.filter(fn category -> category.traits != [] end)
    end
  end

  attr :traits, :list, required: true

  defp trait_badges(assigns) do
    traits_by_parent =
      assigns.traits
      |> Enum.group_by(fn trait ->
        if trait.parent_trait, do: trait.parent_trait.trait_name, else: nil
      end)
      |> Enum.sort_by(fn {parent_name, _} -> parent_name || "" end)

    assigns = assign(assigns, :traits_by_parent, traits_by_parent)

    ~H"""
    <div class="space-y-2">
      <div :for={{parent_name, traits} <- @traits_by_parent} class="space-y-1">
        <div :if={parent_name} class="text-xs font-semibold text-base-content/70">
          {parent_name}
        </div>
        <div class="flex flex-wrap gap-1">
          <span
            :for={trait <- traits}
            class="badge badge-outline badge-xs py-2 border border-base-content/30"
          >
            {trait.trait_name}
          </span>
        </div>
      </div>
    </div>
    """
  end
end
