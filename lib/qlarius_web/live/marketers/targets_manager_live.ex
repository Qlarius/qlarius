defmodule QlariusWeb.Live.Marketers.TargetsManagerLive do
  use QlariusWeb, :live_view

  alias Qlarius.Sponster.Campaigns.{Target, TargetBand, Targets}
  alias QlariusWeb.Live.Marketers.CurrentMarketer

  on_mount {CurrentMarketer, :load_current_marketer}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Qlarius.PubSub, "targets")
    end

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Targets")
    |> assign(:target, nil)
    |> assign(:new_target_form, to_form(%{"title" => "", "description" => ""}))
    |> assign_targets()
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    if socket.assigns.current_marketer do
      target = Targets.get_target_for_marketer!(id, socket.assigns.current_marketer.id)
      bands = Targets.get_bands_for_target(target.id)
      outermost_band = Targets.get_outermost_band(target.id)

      available_trait_groups =
        Targets.get_available_trait_groups_for_target(
          target.id,
          socket.assigns.current_marketer.id
        )

      socket
      |> assign(:page_title, "Edit Target: #{target.title}")
      |> assign(:target, target)
      |> assign(:bands, bands)
      |> assign(:outermost_band, outermost_band)
      |> assign(:available_trait_groups, available_trait_groups)
      |> assign(:target_form, to_form(Target.changeset(target, %{})))
      |> assign(:editing_target_info, false)
      |> assign(:expanding_target, false)
      |> assign(:band_population_counts, %{})
    else
      socket
      |> put_flash(:error, "Please select a marketer first")
      |> push_navigate(to: ~p"/marketer/targets")
    end
  end

  defp apply_action(socket, :inspect, %{"id" => id}) do
    if socket.assigns.current_marketer do
      target = Targets.get_target_for_marketer!(id, socket.assigns.current_marketer.id)
      bands = Targets.get_bands_for_target(target.id)
      band_population_counts = Targets.get_band_population_counts(target.id)

      socket
      |> assign(:page_title, "Inspect Target: #{target.title}")
      |> assign(:target, target)
      |> assign(:bands, bands)
      |> assign(:band_population_counts, band_population_counts)
      |> assign(:target_form, to_form(Target.changeset(target, %{})))
      |> assign(:editing_target_info, false)
    else
      socket
      |> put_flash(:error, "Please select a marketer first")
      |> push_navigate(to: ~p"/marketer/targets")
    end
  end

  defp assign_targets(socket) do
    if socket.assigns.current_marketer do
      targets = Targets.list_targets_for_marketer(socket.assigns.current_marketer.id)
      assign(socket, :targets, targets)
    else
      assign(socket, :targets, [])
    end
  end

  @impl true
  def handle_event("create_target", %{"title" => title, "description" => description}, socket) do
    if !socket.assigns.current_marketer do
      {:noreply, put_flash(socket, :error, "Please select a marketer first")}
    else
      attrs = %{
        title: title,
        description: description,
        marketer_id: socket.assigns.current_marketer.id
      }

      case Targets.create_target(attrs) do
        {:ok, target} ->
          {:noreply,
           socket
           |> put_flash(:info, "Target created successfully")
           |> push_navigate(to: ~p"/marketer/targets/#{target.id}/edit")}

        {:error, %Ecto.Changeset{errors: errors}} ->
          error_message =
            errors
            |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end)
            |> Enum.join(", ")

          {:noreply, put_flash(socket, :error, error_message)}
      end
    end
  end

  def handle_event("toggle_edit_target_info", _params, socket) do
    {:noreply, assign(socket, :editing_target_info, !socket.assigns.editing_target_info)}
  end

  def handle_event("update_target", %{"target" => target_params}, socket) do
    case Targets.update_target(socket.assigns.target, target_params) do
      {:ok, target} ->
        {:noreply,
         socket
         |> put_flash(:info, "Target updated successfully")
         |> assign(:target, target)
         |> assign(:editing_target_info, false)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :target_form, to_form(changeset))}
    end
  end

  def handle_event("cancel_edit_target_info", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_target_info, false)
     |> assign(:target_form, to_form(Target.changeset(socket.assigns.target, %{})))}
  end

  def handle_event("create_bullseye", _params, socket) do
    if !Targets.get_bullseye_for_target(socket.assigns.target.id) do
      case Targets.create_bullseye_band(socket.assigns.target.id) do
        {:ok, _band} ->
          {:noreply,
           socket
           |> put_flash(:info, "Bullseye created")
           |> reload_target_data()}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to create bullseye")}
      end
    else
      {:noreply, put_flash(socket, :error, "Bullseye already exists")}
    end
  end

  def handle_event("add_trait_group", %{"trait_group_id" => trait_group_id}, socket) do
    bullseye = Targets.get_bullseye_for_target(socket.assigns.target.id)

    bullseye =
      if !bullseye do
        case Targets.create_bullseye_band(socket.assigns.target.id) do
          {:ok, band} -> band
          {:error, _} -> nil
        end
      else
        bullseye
      end

    if !bullseye do
      {:noreply, put_flash(socket, :error, "Failed to create bullseye")}
    else
      case Targets.add_trait_group_to_band(bullseye.id, String.to_integer(trait_group_id)) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Trait group added to bullseye")
           |> reload_target_data()}

        {:error, :trait_group_already_in_target} ->
          {:noreply, put_flash(socket, :error, "Trait group already in target")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to add trait group")}
      end
    end
  end

  def handle_event(
        "remove_trait_group_from_bullseye",
        %{"band_id" => band_id, "trait_group_id" => trait_group_id},
        socket
      ) do
    {:ok, _} =
      Targets.remove_trait_group_from_band(
        String.to_integer(band_id),
        String.to_integer(trait_group_id)
      )

    {:noreply,
     socket
     |> put_flash(:info, "Trait group removed from bullseye")
     |> reload_target_data()}
  end

  def handle_event("start_expanding_target", _params, socket) do
    {:noreply, assign(socket, :expanding_target, true)}
  end

  def handle_event("cancel_expanding_target", _params, socket) do
    {:noreply, assign(socket, :expanding_target, false)}
  end

  def handle_event("create_outer_band", %{"excluded_trait_group_id" => tg_id}, socket) do
    case Targets.create_outer_band(socket.assigns.target.id, String.to_integer(tg_id)) do
      {:ok, _band} ->
        {:noreply,
         socket
         |> put_flash(:info, "Ring created")
         |> assign(:expanding_target, false)
         |> reload_target_data()}

      {:error, :cannot_create_empty_band} ->
        {:noreply, put_flash(socket, :error, "Cannot create empty band")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create ring")}
    end
  end

  def handle_event("delete_outermost_band", _params, socket) do
    case Targets.delete_outermost_band(socket.assigns.target.id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Ring deleted")
         |> reload_target_data()}

      {:error, :cannot_delete_bullseye} ->
        {:noreply, put_flash(socket, :error, "Cannot delete bullseye")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "No bands to delete")}
    end
  end

  def handle_event("populate_target", _params, socket) do
    Targets.trigger_population(socket.assigns.target)

    {:noreply,
     socket
     |> put_flash(:info, "Population started. You will be notified when complete.")
     |> push_navigate(to: ~p"/marketer/targets")}
  end

  def handle_event("refresh_population", _params, socket) do
    Targets.trigger_population(socket.assigns.target)

    {:noreply,
     socket
     |> put_flash(:info, "Population refresh started. You will be notified when complete.")
     |> push_navigate(to: ~p"/marketer/targets")}
  end

  def handle_event("depopulate_target", _params, socket) do
    case Targets.depopulate_target(socket.assigns.target.id) do
      {:ok, _target} ->
        {:noreply,
         socket
         |> put_flash(:info, "Target depopulated successfully")
         |> push_navigate(to: ~p"/marketer/targets/#{socket.assigns.target.id}/edit")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to depopulate target")}
    end
  end

  def handle_event("done", _params, socket) do
    if socket.assigns.bands == [] do
      {:noreply, put_flash(socket, :error, "Create at least a bullseye before finishing")}
    else
      {:noreply, push_navigate(socket, to: ~p"/marketer/targets")}
    end
  end

  @impl true
  def handle_info({:target_populated, target_id}, socket) do
    if socket.assigns.live_action == :index do
      {:noreply, assign_targets(socket)}
    else
      if socket.assigns.target && socket.assigns.target.id == target_id do
        {:noreply,
         socket
         |> put_flash(:info, "Target population complete")
         |> reload_target_data()}
      else
        {:noreply, socket}
      end
    end
  end

  defp reload_target_data(socket) do
    target =
      Targets.get_target_for_marketer!(
        socket.assigns.target.id,
        socket.assigns.current_marketer.id
      )

    bands = Targets.get_bands_for_target(target.id)
    outermost_band = Targets.get_outermost_band(target.id)

    available_trait_groups =
      Targets.get_available_trait_groups_for_target(
        target.id,
        socket.assigns.current_marketer.id
      )

    socket
    |> assign(:target, target)
    |> assign(:bands, bands)
    |> assign(:outermost_band, outermost_band)
    |> assign(:available_trait_groups, available_trait_groups)
    |> assign(:editing_target_info, false)
    |> assign(:expanding_target, false)
  end

  defp excluded_trait_group_id(band, bands) do
    sorted_bands = Enum.sort_by(bands, &length(&1.trait_groups), :desc)
    current_index = Enum.find_index(sorted_bands, &(&1.id == band.id))

    if current_index && current_index < length(sorted_bands) - 1 do
      next_band = Enum.at(sorted_bands, current_index + 1)
      current_tg_ids = Enum.map(band.trait_groups, & &1.id) |> MapSet.new()
      next_tg_ids = Enum.map(next_band.trait_groups, & &1.id) |> MapSet.new()
      excluded_ids = MapSet.difference(current_tg_ids, next_tg_ids) |> MapSet.to_list()

      List.first(excluded_ids)
    else
      nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin {assigns}>
      <.current_marketer_bar
        current_marketer={@current_marketer}
        current_path={~p"/marketer/targets"}
      />

      <%= cond do %>
        <% @live_action == :index -> %>
          <.index_view {assigns} />
        <% @live_action == :edit -> %>
          <.edit_view {assigns} />
        <% @live_action == :inspect -> %>
          <.inspect_view {assigns} />
      <% end %>
    </Layouts.admin>
    """
  end

  attr :current_marketer, :any, required: true
  attr :targets, :list, required: true
  attr :new_target_form, :any, required: true

  defp index_view(assigns) do
    ~H"""
    <div :if={!@current_marketer} class="p-6">
      <div class="alert alert-warning">
        <.icon name="hero-exclamation-circle" class="w-6 h-6" />
        <span>Please select a marketer to manage targets.</span>
      </div>
    </div>

    <div :if={@current_marketer} class="p-6">
      <div class="flex justify-between items-center mb-6">
        <h1 class="text-2xl font-bold">Targets</h1>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div class="lg:col-span-2">
          <div :if={@targets == []} class="card bg-base-100 border border-base-300">
            <div class="card-body text-center py-12">
              <.icon name="hero-document-plus" class="w-16 h-16 mx-auto text-base-content/30 mb-4" />
              <p class="text-lg font-medium text-base-content/70">No targets yet</p>
              <p class="text-sm text-base-content/50 mt-2">
                Create your first target on the right to get started
              </p>
            </div>
          </div>

          <div :if={@targets != []} class="overflow-x-auto">
            <table class="table table-zebra">
              <thead>
                <tr>
                  <th>Target Name</th>
                  <th>Bullseye</th>
                  <th class="text-center">Outer Rings</th>
                  <th class="text-center">Total Population</th>
                  <th class="text-center"></th>
                </tr>
              </thead>
              <tbody>
                <tr :for={target <- @targets}>
                  <td class="font-medium !align-top">{target.title}</td>
                  <td class="!align-top">
                    <%= if target.bullseye_trait_groups == [] do %>
                      <span class="text-base-content/50">-</span>
                    <% else %>
                      <div class="flex flex-wrap gap-1">
                        <span
                          :for={tg <- target.bullseye_trait_groups}
                          class="badge badge-outline badge-xs py-2 border border-base-content/30"
                        >
                          {tg.title}
                        </span>
                      </div>
                    <% end %>
                  </td>
                  <td class="text-center !align-top">
                    <%= if target.bullseye_trait_group_count == 0 do %>
                      <span class="text-base-content/50">-</span>
                    <% else %>
                      {target.outer_band_count}
                    <% end %>
                  </td>
                  <td class="text-center !align-top">
                    <%= if target.is_frozen do %>
                      {target.total_population}
                    <% else %>
                      <span class="text-base-content/50">-</span>
                    <% end %>
                  </td>
                  <td class="!align-top">
                    <%= if target.is_frozen do %>
                      <.link
                        navigate={~p"/marketer/targets/#{target.id}/inspect"}
                        class="btn btn-sm btn-info btn-outline"
                      >
                        Inspect
                      </.link>
                      <button class="btn btn-sm btn-primary btn-outline btn-disabled">
                        Build/Edit
                      </button>
                    <% else %>
                      <.link
                        navigate={~p"/marketer/targets/#{target.id}/edit"}
                        class="btn btn-sm btn-primary btn-outline"
                      >
                        Build/Edit
                      </.link>
                    <% end %>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <div class="lg:col-span-1">
          <div class="card bg-base-100 border border-base-300">
            <div class="card-body">
              <h2 class="card-title mb-4">Create New Target</h2>
              <form phx-submit="create_target" class="space-y-4">
                <div class="form-control w-full">
                  <input
                    type="text"
                    name="title"
                    placeholder="Target name"
                    class="input input-bordered w-full"
                    required
                  />
                </div>

                <div class="form-control w-full">
                  <textarea
                    name="description"
                    placeholder="Description (optional)"
                    class="textarea textarea-bordered w-full"
                    rows="3"
                  />
                </div>

                <button type="submit" class="btn btn-primary w-full">
                  <.icon name="hero-arrow-up" class="w-5 h-5 lg:hidden" />
                  <.icon name="hero-arrow-left" class="w-5 h-5 hidden lg:block" /> Create New Target
                </button>
              </form>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :target, :any, required: true
  attr :bands, :list, required: true
  attr :outermost_band, :any, required: true
  attr :available_trait_groups, :list, required: true
  attr :target_form, :any, required: true
  attr :editing_target_info, :boolean, required: true

  defp edit_view(assigns) do
    ~H"""
    <div class="p-6">
      <div class="flex items-center gap-3 mb-2">
        <h1 class="text-2xl font-bold">{@target.title}</h1>
        <button
          phx-click="toggle_edit_target_info"
          class="btn btn-ghost btn-sm btn-circle"
          title="Edit target name and description"
        >
          <.icon name="hero-pencil" class="w-5 h-5" />
        </button>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div class="lg:col-span-2">
          <div :if={@editing_target_info} class="card bg-base-100 border border-base-300 mb-6">
            <div class="card-body">
              <.form for={@target_form} phx-submit="update_target" class="space-y-4">
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div class="form-control">
                    <label class="label">
                      <span class="label-text">Target Name</span>
                    </label>
                    <.input field={@target_form[:title]} type="text" />
                  </div>

                  <div class="form-control">
                    <label class="label">
                      <span class="label-text">Description</span>
                    </label>
                    <.input field={@target_form[:description]} type="text" />
                  </div>
                </div>

                <div class="flex gap-2 justify-end">
                  <button
                    type="button"
                    phx-click="cancel_edit_target_info"
                    class="btn btn-ghost btn-sm"
                  >
                    Cancel
                  </button>
                  <button type="submit" class="btn btn-primary btn-sm">
                    Save
                  </button>
                </div>
              </.form>
            </div>
          </div>

          <div :if={@target.description && !@editing_target_info} class="mb-6">
            <p class="text-base-content/70">{@target.description}</p>
          </div>

          <%= if @bands == [] do %>
            <div class="alert alert-info mb-6">
              <.icon name="hero-information-circle" class="w-6 h-6" />
              <span>
                Start by creating a bullseye for this target. Select trait groups from the panel on the right.
              </span>
            </div>
          <% end %>

          <div class="mb-6 flex gap-2">
            <button phx-click="done" class="btn btn-primary">
              Done
            </button>
            <%= if @bands != [] do %>
              <button
                phx-click="populate_target"
                class="btn btn-success"
                data-confirm="This will calculate populations for all bands. Continue?"
              >
                Freeze and Populate Target
              </button>
            <% end %>
          </div>

          <div class="overflow-x-auto">
            <table class="table">
              <thead>
                <tr>
                  <th>Target Rings</th>
                  <th>Trait Groups</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={band <- @bands}>
                  <td class={[
                    "font-bold !align-top",
                    TargetBand.is_bullseye?(band) && "text-error"
                  ]}>
                    <div class="flex items-start gap-2">
                      <span>{Targets.band_label(band, @bands)}</span>
                      <%= if @outermost_band && band.id == @outermost_band.id && !TargetBand.is_bullseye?(@outermost_band) do %>
                        <button
                          phx-click="delete_outermost_band"
                          class="btn btn-ghost btn-xs btn-circle"
                          title="Delete this ring"
                        >
                          <.icon name="hero-trash" class="w-4 h-4" />
                        </button>
                      <% end %>
                    </div>
                  </td>
                  <td class="!align-top">
                    <div class="space-y-2">
                      <%= if @expanding_target && @outermost_band && band.id == @outermost_band.id && length(band.trait_groups) > 1 do %>
                        <div class="flex flex-wrap gap-2">
                          <button
                            :for={tg <- band.trait_groups}
                            phx-click="create_outer_band"
                            phx-value-excluded_trait_group_id={tg.id}
                            class={[
                              "badge badge-warning cursor-pointer py-3 px-3",
                              tg.id == excluded_trait_group_id(band, @bands) && "opacity-60"
                            ]}
                            title={"Click to exclude #{tg.title}"}
                          >
                            {tg.title} <.icon name="hero-scissors" class="w-4 h-4" />
                          </button>
                        </div>
                      <% else %>
                        <%= if TargetBand.is_bullseye?(band) && length(@bands) == 1 do %>
                          <div class="flex flex-wrap gap-2">
                            <div
                              :for={tg <- band.trait_groups}
                              class="badge badge-outline py-3 px-3 flex items-center gap-2"
                            >
                              <span>{tg.title}</span>
                              <button
                                phx-click="remove_trait_group_from_bullseye"
                                phx-value-band_id={band.id}
                                phx-value-trait_group_id={tg.id}
                                class="cursor-pointer hover:text-error"
                                title="Remove from bullseye"
                              >
                                <.icon name="hero-x-mark" class="w-4 h-4" />
                              </button>
                            </div>
                          </div>
                        <% else %>
                          <div class="flex flex-wrap gap-2">
                            <span
                              :for={tg <- band.trait_groups}
                              class={[
                                "badge badge-outline py-3",
                                tg.id == excluded_trait_group_id(band, @bands) && "opacity-60"
                              ]}
                            >
                              {tg.title}
                            </span>
                          </div>
                        <% end %>
                      <% end %>
                    </div>
                  </td>
                </tr>
                <tr :if={@expanding_target}>
                  <td class="!align-top font-bold text-error">
                    <div class="flex items-start gap-2">
                      <span>Ring {length(@bands)}</span>
                      <button
                        phx-click="cancel_expanding_target"
                        class="btn btn-ghost btn-xs btn-circle"
                        title="Cancel"
                      >
                        <.icon name="hero-x-mark" class="w-4 h-4" />
                      </button>
                    </div>
                  </td>
                  <td class="italic text-base-content/60 !align-top">
                    Select a trait group from the ring above to exclude for this new ring.
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <%= if @bands != [] && @outermost_band && length(@outermost_band.trait_groups) > 1 && !@expanding_target do %>
            <div class="mt-6 flex gap-2">
              <button phx-click="start_expanding_target" class="btn btn-primary btn-outline">
                <.icon name="hero-plus" class="w-5 h-5" /> Expand Target
              </button>
            </div>
          <% end %>
        </div>

        <div class="lg:col-span-1">
          <div class="card bg-base-100 border border-base-300">
            <div class="card-body">
              <h2 class="text-lg font-bold mb-4">
                Select a Trait Group to add to the Bullseye:
              </h2>

              <%= if length(@bands) > 1 do %>
                <div class="alert alert-info mb-4">
                  <.icon name="hero-lock-closed" class="w-5 h-5" />
                  <div class="text-sm">
                    <p class="font-semibold">Bullseye Locked</p>
                    <p class="text-xs">
                      Delete outer rings first to modify the bullseye.
                    </p>
                  </div>
                </div>

                <%= if @available_trait_groups == [] do %>
                  <p class="text-sm text-base-content/50">
                    No available trait groups. All trait groups have been added to this target.
                  </p>
                <% else %>
                  <div class="space-y-2">
                    <div
                      :for={tg <- @available_trait_groups}
                      class="btn btn-sm btn-block justify-start btn-disabled opacity-60"
                    >
                      {tg.title}
                    </div>
                  </div>
                <% end %>
              <% else %>
                <%= if @available_trait_groups == [] do %>
                  <p class="text-sm text-base-content/50">
                    No available trait groups. All trait groups have been added to this target.
                  </p>
                <% else %>
                  <div class="space-y-2">
                    <button
                      :for={tg <- @available_trait_groups}
                      phx-click="add_trait_group"
                      phx-value-trait_group_id={tg.id}
                      class="btn btn-sm btn-block justify-start"
                    >
                      [+] {tg.title}
                    </button>
                  </div>
                <% end %>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :target, :any, required: true
  attr :bands, :list, required: true
  attr :band_population_counts, :map, required: true
  attr :target_form, :any, required: true
  attr :editing_target_info, :boolean, required: true

  defp inspect_view(assigns) do
    total_population = Map.values(assigns.band_population_counts) |> Enum.sum()
    assigns = assign(assigns, :total_population, total_population)

    ~H"""
    <div class="p-6">
      <div class="flex items-center gap-3 mb-2">
        <h1 class="text-2xl font-bold">{@target.title}</h1>
        <button
          phx-click="toggle_edit_target_info"
          class="btn btn-ghost btn-sm btn-circle"
          title="Edit target name and description"
        >
          <.icon name="hero-pencil" class="w-5 h-5" />
        </button>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-1 gap-6">
        <div>
          <div :if={@editing_target_info} class="card bg-base-100 border border-base-300 mb-6">
            <div class="card-body">
              <.form for={@target_form} phx-submit="update_target" class="space-y-4">
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div class="form-control">
                    <label class="label">
                      <span class="label-text">Target Name</span>
                    </label>
                    <.input field={@target_form[:title]} type="text" />
                  </div>

                  <div class="form-control">
                    <label class="label">
                      <span class="label-text">Description</span>
                    </label>
                    <.input field={@target_form[:description]} type="text" />
                  </div>
                </div>

                <div class="flex gap-2 justify-end">
                  <button
                    type="button"
                    phx-click="cancel_edit_target_info"
                    class="btn btn-ghost btn-sm"
                  >
                    Cancel
                  </button>
                  <button type="submit" class="btn btn-primary btn-sm">
                    Save
                  </button>
                </div>
              </.form>
            </div>
          </div>

          <div :if={@target.description && !@editing_target_info} class="mb-6">
            <p class="text-base-content/70">{@target.description}</p>
          </div>

          <div class="alert alert-info mb-6">
            <.icon name="hero-lock-closed" class="w-5 h-5" />
            <div class="text-sm">
              <p class="font-semibold">This target structure is frozen</p>
              <p class="text-xs">Depopulate this target below to edit its structure.</p>
            </div>
          </div>

          <div class="mb-6 flex gap-2">
            <button phx-click="done" class="btn btn-primary">
              Done
            </button>
            <button
              phx-click="refresh_population"
              class="btn btn-success"
              data-confirm="This will recalculate populations for all rings. Continue?"
            >
              Refresh Population
            </button>
            <button
              phx-click="depopulate_target"
              class="btn btn-error btn-outline"
              data-confirm="This will delete all population data and unfreeze the target. Continue?"
            >
              Depopulate
            </button>
          </div>

          <div class="mb-4 p-4 bg-base-200 rounded-lg">
            <p class="text-sm font-semibold">Total Population: {@total_population}</p>
          </div>

          <div class="overflow-x-auto">
            <table class="table">
              <thead>
                <tr>
                  <th>Target Rings</th>
                  <th>Trait Groups</th>
                  <th class="text-center">MeFiles</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={band <- @bands}>
                  <td class={[
                    "font-bold !align-top",
                    TargetBand.is_bullseye?(band) && "text-error"
                  ]}>
                    <span>{Targets.band_label(band, @bands)}</span>
                  </td>
                  <td class="!align-top">
                    <div class="flex flex-wrap gap-2">
                      <span
                        :for={tg <- band.trait_groups}
                        class={[
                          "badge badge-outline py-3",
                          tg.id == excluded_trait_group_id(band, @bands) && "opacity-60"
                        ]}
                      >
                        {tg.title}
                      </span>
                    </div>
                  </td>
                  <td class="text-center !align-top">
                    <span class="font-semibold">{Map.get(@band_population_counts, band.id, 0)}</span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
