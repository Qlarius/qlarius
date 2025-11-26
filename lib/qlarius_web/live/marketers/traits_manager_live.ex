defmodule QlariusWeb.Live.Marketers.TraitsManagerLive do
  use QlariusWeb, :live_view

  alias Qlarius.Repo
  alias Qlarius.YouData.Traits
  alias Qlarius.Sponster.Campaigns.TraitGroup
  alias QlariusWeb.Live.Marketers.CurrentMarketer

  on_mount {CurrentMarketer, :load_current_marketer}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      socket
      |> assign(:page_title, "Traits")
      |> apply_action(socket.assigns.live_action, params)

    {:noreply, socket}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:show_modal, false)
    |> assign(:selected_parent_trait, nil)
    |> assign(:trait_group_form, nil)
    |> assign(:zip_search_term, "")
    |> assign(:selected_zips, [])
    |> assign(:zip_search_results, [])
    |> assign_trait_data()
  end

  defp apply_action(socket, :new_trait_group, %{"parent_trait_id" => parent_trait_id}) do
    if socket.assigns.current_marketer do
      parent_trait = Traits.get_trait_with_full_survey_data!(parent_trait_id)

      case parent_trait do
        {:ok, trait} ->
          form =
            %TraitGroup{}
            |> TraitGroup.changeset(%{
              "marketer_id" => socket.assigns.current_marketer.id
            })
            |> to_form()

          socket
          |> assign(:show_modal, true)
          |> assign(:selected_parent_trait, trait)
          |> assign(:trait_group_form, form)
          |> assign(:selected_trait_ids, [])
          |> assign(:zip_search_term, "")
          |> assign(:selected_zips, [])
          |> assign(:zip_search_results, [])
          |> assign(:zip_search_limit, 1000)
          |> assign_trait_data()

        {:error, _} ->
          socket
          |> put_flash(:error, "Selected trait is not a parent trait")
          |> push_navigate(to: ~p"/marketer/traits")
      end
    else
      socket
      |> put_flash(:error, "Please select a marketer first")
      |> push_navigate(to: ~p"/marketer/traits")
    end
  end

  defp apply_action(socket, :new_trait_group, _params) do
    push_navigate(socket, to: ~p"/marketer/traits")
  end

  defp assign_trait_data(socket) do
    if socket.assigns.current_marketer do
      trait_groups = Traits.list_trait_groups_for_marketer(socket.assigns.current_marketer.id)

      archived_trait_groups =
        Traits.list_archived_trait_groups_for_marketer(socket.assigns.current_marketer.id)

      categories_with_traits = Traits.list_trait_categories_with_traits()

      socket
      |> assign(:trait_groups, trait_groups)
      |> assign(:archived_trait_groups, archived_trait_groups)
      |> assign(:categories_with_traits, categories_with_traits)
      |> assign(:search_term, "")
      |> assign(:show_archived, false)
    else
      socket
      |> assign(:trait_groups, [])
      |> assign(:archived_trait_groups, [])
      |> assign(:categories_with_traits, [])
      |> assign(:search_term, "")
      |> assign(:show_archived, false)
    end
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/marketer/traits")}
  end

  def handle_event(
        "validate_trait_group",
        %{"_target" => ["search"], "search" => search_term, "trait_group" => trait_group_params} =
          params,
        socket
      ) do
    search_term = String.trim(search_term)

    if socket.assigns.selected_parent_trait.input_type == "single_select_zip" do
      parent_trait_id = socket.assigns.selected_parent_trait.id

      form =
        %TraitGroup{}
        |> TraitGroup.changeset(trait_group_params)
        |> Map.put(:action, :validate)
        |> to_form()

      updated_socket =
        if String.length(search_term) >= 2 do
          limit = Map.get(socket.assigns, :zip_search_limit, 1000)
          results = Traits.search_zip_codes(parent_trait_id, search_term, limit)

          socket
          |> assign(:trait_group_form, form)
          |> assign(:zip_search_term, search_term)
          |> assign(:zip_search_results, results)
        else
          socket
          |> assign(:trait_group_form, form)
          |> assign(:zip_search_term, search_term)
          |> assign(:zip_search_results, [])
        end

      {:noreply, updated_socket}
    else
      trait_group_params = Map.get(params, "trait_group", %{})

      form =
        %TraitGroup{}
        |> TraitGroup.changeset(trait_group_params)
        |> Map.put(:action, :validate)
        |> to_form()

      {:noreply, assign(socket, :trait_group_form, form)}
    end
  end

  def handle_event("validate_trait_group", %{"trait_group" => trait_group_params}, socket) do
    form =
      %TraitGroup{}
      |> TraitGroup.changeset(trait_group_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, :trait_group_form, form)}
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
    if !socket.assigns.current_marketer do
      {:noreply,
       socket
       |> put_flash(:error, "Please select a marketer first")
       |> push_navigate(to: ~p"/marketer/traits")}
    else
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
          |> Map.put("marketer_id", socket.assigns.current_marketer.id)
          |> Map.put("parent_trait_id", socket.assigns.selected_parent_trait.id)

        case Traits.create_trait_group(attrs) do
          {:ok, _trait_group} ->
            {:noreply,
             socket
             |> put_flash(:info, "Trait group created successfully")
             |> push_navigate(to: ~p"/marketer/traits")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :trait_group_form, to_form(changeset))}
        end
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
          |> Map.put("marketer_id", socket.assigns.current_marketer.id)
          |> Map.put("parent_trait_id", socket.assigns.selected_parent_trait.id)

        case Traits.create_trait_group(attrs) do
          {:ok, _trait_group} ->
            {:noreply,
             socket
             |> put_flash(:info, "Trait group created successfully")
             |> push_navigate(to: ~p"/marketer/traits")}

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
    if socket.assigns.current_marketer do
      trait_group = Traits.get_trait_group_for_marketer!(id, socket.assigns.current_marketer.id)

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
    else
      {:noreply, put_flash(socket, :error, "No marketer selected")}
    end
  end

  def handle_event("deactivate_trait_group", %{"id" => id}, socket) do
    if socket.assigns.current_marketer do
      trait_group = Traits.get_trait_group_for_marketer!(id, socket.assigns.current_marketer.id)

      case Traits.deactivate_trait_group(trait_group) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Trait group deactivated successfully")
           |> assign_trait_data()}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to deactivate trait group")}
      end
    else
      {:noreply, put_flash(socket, :error, "No marketer selected")}
    end
  end

  def handle_event("reactivate_trait_group", %{"id" => id}, socket) do
    if socket.assigns.current_marketer do
      trait_group = Traits.get_trait_group_for_marketer!(id, socket.assigns.current_marketer.id)

      case Traits.reactivate_trait_group(trait_group) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Trait group reactivated successfully")
           |> assign_trait_data()}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to reactivate trait group")}
      end
    else
      {:noreply, put_flash(socket, :error, "No marketer selected")}
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
      <.current_marketer_bar
        current_marketer={@current_marketer}
        current_path={~p"/marketer/traits"}
      />

      <.trait_group_modal
        :if={@show_modal}
        show_modal={@show_modal}
        parent_trait={@selected_parent_trait}
        form={@trait_group_form}
        zip_search_term={Map.get(assigns, :zip_search_term, "")}
        zip_search_results={Map.get(assigns, :zip_search_results, [])}
        selected_zips={Map.get(assigns, :selected_zips, [])}
        zip_search_limit={Map.get(assigns, :zip_search_limit, 1000)}
      />

      <div :if={!@current_marketer} class="p-6">
        <div class="alert alert-warning">
          <.icon name="hero-exclamation-circle" class="w-6 h-6" />
          <span>Please select a marketer to manage trait groups.</span>
        </div>
      </div>

      <div :if={@current_marketer} class="p-6">
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div class="lg:col-span-2">
            <div class="flex justify-between items-center mb-4">
              <h1 class="text-2xl font-bold">Trait Groups</h1>
            </div>

            <div :if={@trait_groups == []} class="card bg-base-100 border border-base-300">
              <div class="card-body text-center py-12">
                <.icon name="hero-document-plus" class="w-16 h-16 mx-auto text-base-content/30 mb-4" />
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
                    <th class="text-center">Active Targets</th>
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
              <button
                phx-click="toggle_archived"
                class="btn btn-ghost btn-sm mb-4"
              >
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
                  <div class="collapse collapse-arrow bg-base-200 border border-base-300">
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
                          navigate={~p"/marketer/traits/new?parent_trait_id=#{trait.id}"}
                          class="flex items-center justify-between p-2 hover:bg-base-100 rounded cursor-pointer group"
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

  attr :show_modal, :boolean, required: true
  attr :parent_trait, :any, required: true
  attr :form, :any, required: true
  attr :zip_search_term, :string, default: ""
  attr :zip_search_results, :list, default: []
  attr :selected_zips, :list, default: []
  attr :zip_search_limit, :integer, default: 1000

  defp trait_group_modal(assigns) do
    ~H"""
    <div class={[
      "modal modal-bottom sm:modal-middle",
      @show_modal && "modal-open bg-base-300/80 backdrop-blur-sm"
    ]}>
      <div class={[
        "flex flex-col modal-box border border-youdata-500 dark:border-youdata-700 bg-base-100 p-0 max-h-[90vh]",
        @parent_trait.input_type == "single_select_zip" && "!max-w-3xl"
      ]}>
        <div class="p-4 flex flex-row justify-between items-baseline bg-youdata-300/80 dark:bg-youdata-800/80 text-base-content shrink-0">
          <h3 class="text-lg font-bold">
            Create Trait Group: {@parent_trait.trait_name}
          </h3>
          <button type="button" phx-click="close_modal" class="btn btn-md btn-circle btn-ghost">
            ✕
          </button>
        </div>

        <div class="p-4 bg-base-200 text-base-content/70 shrink-0 text-sm">
          <p :if={@parent_trait.survey_question}>
            {Phoenix.HTML.raw(@parent_trait.survey_question.text)}
          </p>
        </div>

        <.form
          for={@form}
          phx-change="validate_trait_group"
          phx-submit="save_trait_group"
          class="flex flex-col flex-1 min-h-0"
        >
          <div class="flex-1 overflow-y-auto p-4 space-y-4">
            <div>
              <.input field={@form[:title]} type="text" label="Trait Group Name" required />
            </div>

            <div>
              <.input field={@form[:description]} type="textarea" label="Description (optional)" />
            </div>

            <%= if @parent_trait.input_type == "single_select_zip" do %>
              <div class="divider">Select Zip Codes</div>

              <div id="zip-selector" phx-hook="ZipSelector" class="flex gap-4 w-full">
                <div class="flex-1 min-w-0">
                  <% available_count =
                    Enum.count(@zip_search_results, fn zip ->
                      not Enum.any?(@selected_zips, &(&1.id == zip.id))
                    end) %>
                  <label class="label">
                    <span class="label-text font-semibold">
                      Available Zip Codes ({available_count})
                    </span>
                  </label>

                  <div class="mb-2 flex gap-2">
                    <label class="input input-bordered input-sm flex items-center gap-2 flex-1">
                      <.icon name="hero-magnifying-glass" class="w-4 h-4 opacity-70" />
                      <input
                        type="text"
                        phx-debounce="300"
                        name="search"
                        value={@zip_search_term}
                        placeholder="Search (2+ chars)..."
                        class="grow font-mono"
                        autocomplete="off"
                      />
                    </label>
                    <select
                      name="limit"
                      phx-change="change_zip_limit"
                      class="select select-bordered select-sm w-28"
                    >
                      <option value="1000" selected={@zip_search_limit == 1000}>1,000</option>
                      <option value="5000" selected={@zip_search_limit == 5000}>5,000</option>
                      <option value="10000" selected={@zip_search_limit == 10000}>10,000</option>
                      <option value="all" selected={@zip_search_limit == :all}>All</option>
                    </select>
                  </div>

                  <select
                    id="available-zips"
                    multiple
                    size="15"
                    class="select select-bordered w-full h-80 text-sm font-mono [&::-webkit-scrollbar-button]:[display:none]"
                  >
                    <%= for zip <- @zip_search_results do %>
                      <% is_selected = Enum.any?(@selected_zips, &(&1.id == zip.id)) %>
                      <option
                        value={zip.id}
                        disabled={is_selected}
                        class={is_selected && "!text-base-content/40"}
                      >
                        {zip.zip_code} - {zip.location}
                      </option>
                    <% end %>
                  </select>

                  <p class="text-xs text-base-content/60 mt-2">
                    Hold Cmd/Ctrl or Shift to select multiple
                  </p>
                </div>

                <div class="flex flex-col items-center justify-center gap-2">
                  <button
                    type="button"
                    data-action="add-all"
                    class="btn btn-sm btn-primary"
                    title="Add all visible"
                  >
                    >>
                  </button>
                  <button
                    type="button"
                    data-action="add-selected"
                    class="btn btn-sm btn-primary"
                    title="Add selected"
                  >
                    >
                  </button>
                  <button
                    type="button"
                    data-action="remove-selected"
                    class="btn btn-sm btn-secondary"
                    title="Remove selected"
                  >
                    &lt;
                  </button>
                  <button
                    type="button"
                    data-action="clear-all"
                    class="btn btn-sm btn-secondary"
                    title="Clear all"
                  >
                    &lt;&lt;
                  </button>
                </div>

                <div class="flex-1 min-w-0">
                  <label class="label">
                    <span class="label-text font-semibold">
                      Selected Zip Codes ({length(@selected_zips)})
                    </span>
                  </label>

                  <select
                    id="selected-zips"
                    multiple
                    size="15"
                    class="select select-bordered w-full h-80 text-sm mt-7 font-mono [&::-webkit-scrollbar-button]:[display:none]"
                  >
                    <%= for zip <- @selected_zips do %>
                      <option value={zip.id}>
                        {zip.zip_code} - {zip.location}
                      </option>
                    <% end %>
                  </select>

                  <p class="text-xs text-base-content/60 mt-2">
                    Hold Cmd/Ctrl or Shift to select multiple
                  </p>
                </div>
              </div>
            <% else %>
              <div class="divider">Select Traits</div>

              <div :if={@parent_trait.child_traits} class="py-0">
                <label
                  :for={child_trait <- Enum.sort_by(@parent_trait.child_traits, & &1.display_order)}
                  class="flex items-center gap-3 [&:not(:last-child)]:border-b border-dashed border-base-content/10 py-4 px-2 hover:bg-base-200 cursor-pointer"
                >
                  <input
                    type="checkbox"
                    name="trait_ids[]"
                    value={child_trait.id}
                    id={"trait-#{child_trait.id}"}
                    class="checkbox w-7 h-7"
                  />
                  <div class="text-lg text-base-content">
                    {if child_trait.survey_answer &&
                          child_trait.survey_answer.text not in [nil, ""],
                        do: child_trait.survey_answer.text,
                        else: child_trait.trait_name}
                  </div>
                </label>
              </div>
            <% end %>
          </div>

          <div class="p-4 flex flex-row align-end gap-2 justify-end bg-base-200 border-t border-base-300 shrink-0">
            <button type="button" phx-click="close_modal" class="btn btn-lg btn-ghost">
              Cancel
            </button>
            <button
              type="submit"
              class="btn btn-lg btn-primary"
              disabled={@parent_trait.input_type == "single_select_zip" && @selected_zips == []}
            >
              Create Trait Group
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end
end
