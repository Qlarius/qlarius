defmodule QlariusWeb.Live.Marketers.TargetsManagerLive do
  use QlariusWeb, :live_view

  import QlariusWeb.Components.MarketerUI

  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar, Targeting}
  alias Qlarius.Sponster.Campaigns.{Target, Targets}
  alias QlariusWeb.Live.Marketers.CurrentMarketer
  alias QlariusWeb.Live.TargetEditorComponent

  defp target_editor_id, do: "target-editor"

  on_mount {CurrentMarketer, :load_current_marketer}

  @blank_target_params %{"title" => "", "description" => ""}

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
    |> assign(:new_target_form, to_form(@blank_target_params, as: :target))
    |> assign_targets()
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    if socket.assigns.current_marketer do
      target = Targets.get_target_for_marketer!(id, socket.assigns.current_marketer.id)

      socket
      |> assign(:page_title, "Edit Target: #{target.title}")
      |> assign(:target, target)
      |> assign(:target_form, to_form(Target.changeset(target, %{})))
      |> assign(:editing_target_info, false)
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
    socket = assign_new(socket, :show_archived, fn -> false end)

    if marketer = socket.assigns.current_marketer do
      socket
      |> assign(:targets, Targets.list_targets_for_marketer(marketer.id))
      |> assign(:archived_targets, Targets.list_archived_targets_for_marketer(marketer.id))
    else
      socket
      |> assign(:targets, [])
      |> assign(:archived_targets, [])
    end
  end

  defp with_target(socket, id, fun) do
    target = Targets.get_target_for_marketer!(id, socket.assigns.current_marketer.id)
    fun.(target)
  end

  @impl true
  def handle_event("delete_target", %{"id" => id}, socket) do
    with_target(socket, id, fn target ->
      case Targets.delete_target(target) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Deleted \"#{target.title}\"")
           |> assign_targets()}

        {:error, :used_in_campaign} ->
          {:noreply,
           socket
           |> put_flash(:error, "This target has been used in a campaign. Archive it instead.")
           |> assign_targets()}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete target")}
      end
    end)
  end

  def handle_event("archive_target", %{"id" => id}, socket) do
    with_target(socket, id, fn target ->
      case Targets.archive_target(target) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Archived \"#{target.title}\"")
           |> assign_targets()}

        {:error, :in_live_campaign} ->
          {:noreply,
           socket
           |> put_flash(:error, "Deactivate the campaign using this target before archiving it.")
           |> assign_targets()}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to archive target")}
      end
    end)
  end

  def handle_event("unarchive_target", %{"id" => id}, socket) do
    with_target(socket, id, fn target ->
      case Targets.unarchive_target(target) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Restored \"#{target.title}\"")
           |> assign_targets()}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to unarchive target")}
      end
    end)
  end

  def handle_event("toggle_archived", _params, socket) do
    {:noreply, assign(socket, :show_archived, !socket.assigns.show_archived)}
  end

  def handle_event("validate_new_target", %{"target" => params}, socket) do
    {:noreply, assign(socket, :new_target_form, to_form(params, as: :target))}
  end

  def handle_event("create_target", %{"target" => params} = all_params, socket) do
    if !socket.assigns.current_marketer do
      {:noreply, put_flash(socket, :error, "Please select a marketer first")}
    else
      attrs = %{
        title: params["title"],
        description: params["description"],
        marketer_id: socket.assigns.current_marketer.id
      }

      case Targets.create_target(attrs) do
        {:ok, target} ->
          return_to =
            safe_return_to(all_params["return_to"], ~p"/marketer/targets/#{target.id}/edit")

          {:noreply,
           socket
           |> put_flash(:info, "Target created successfully")
           |> push_navigate(to: return_to)}

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

  def handle_event("validate_target", %{"target" => target_params}, socket) do
    changeset =
      socket.assigns.target
      |> Target.changeset(target_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :target_form, to_form(changeset))}
  end

  def handle_event("update_target", %{"target" => target_params} = params, socket) do
    case Targets.update_target(socket.assigns.target, target_params) do
      {:ok, target} ->
        socket =
          socket
          |> put_flash(:info, "Target updated successfully")
          |> assign(:target, target)
          |> assign(:editing_target_info, false)
          |> assign(:target_form, to_form(Target.changeset(target, %{})))

        case params["return_to"] do
          nil ->
            {:noreply, socket}

          return_to ->
            {:noreply,
             push_navigate(socket, to: safe_return_to(return_to, ~p"/marketer/targets"))}
        end

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

  def handle_event("refresh_population", _params, socket) do
    require Logger
    Logger.info("🔄 User clicked Refresh Population for target #{socket.assigns.target.id}")

    Targets.trigger_population(socket.assigns.target)

    {:noreply,
     socket
     |> put_flash(:info, "Refreshing population for \"#{socket.assigns.target.title}\"...")
     |> assign(:refreshing, true)}
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

  @impl true
  def handle_info({TargetEditorComponent, {:flash, kind, message}}, socket) do
    {:noreply, put_flash(socket, kind, message)}
  end

  def handle_info({TargetEditorComponent, :changed}, socket) do
    {:noreply, reload_target_data(socket)}
  end

  def handle_info({TargetEditorComponent, :populating}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Populating target \"#{socket.assigns.target.title}\"...")
     |> push_navigate(to: ~p"/marketer/targets/#{socket.assigns.target.id}/inspect")}
  end

  def handle_info({TargetEditorComponent, :done}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/marketer/targets")}
  end

  def handle_info(msg, socket) do
    case msg do
      {:target_populated, target_id, timestamp} ->
        require Logger
        Logger.info("LiveView received: target_populated for #{target_id} at #{timestamp}")

        cond do
          socket.assigns.live_action == :index ->
            {:noreply, assign_targets(socket)}

          socket.assigns.live_action == :inspect && socket.assigns.target &&
              socket.assigns.target.id == target_id ->
            Logger.info("Updating inspect view with flash message")

            {:noreply,
             socket
             |> put_flash(:info, "Population refreshed for \"#{socket.assigns.target.title}\"")
             |> reload_inspect_data()}

          socket.assigns.live_action == :edit && socket.assigns.target &&
              socket.assigns.target.id == target_id ->
            send_update(TargetEditorComponent, id: target_editor_id(), reload: true)

            {:noreply,
             socket
             |> put_flash(:info, "Target population complete")
             |> reload_target_data()}

          true ->
            {:noreply, socket}
        end

      _ ->
        {:noreply, socket}
    end
  end

  defp reload_target_data(socket) do
    target =
      Targets.get_target_for_marketer!(
        socket.assigns.target.id,
        socket.assigns.current_marketer.id
      )

    assign(socket, :target, target)
  end

  defp reload_inspect_data(socket) do
    require Logger
    Logger.info("🔄 reload_inspect_data called")

    target =
      Targets.get_target_for_marketer!(
        socket.assigns.target.id,
        socket.assigns.current_marketer.id
      )

    bands = Targets.get_bands_for_target(target.id)
    band_population_counts = Targets.get_band_population_counts(target.id)

    Logger.info("🔄 Reloaded counts: #{inspect(band_population_counts)}")

    socket
    |> assign(:target, target)
    |> assign(:bands, bands)
    |> assign(:band_population_counts, band_population_counts)
    |> assign(:refreshing, false)
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
              current_path={~p"/marketer/targets"}
            />

            <%= cond do %>
              <% !@current_marketer -> %>
                <.no_marketer_notice message="Choose a marketer to build and manage their targets." />
              <% @live_action == :index -> %>
                <.index_view
                  targets={@targets}
                  archived_targets={@archived_targets}
                  show_archived={@show_archived}
                  new_target_form={@new_target_form}
                />
              <% @live_action == :edit -> %>
                <.page>
                  <.target_header
                    target={@target}
                    target_form={@target_form}
                    editing_target_info={@editing_target_info}
                  />
                  <.live_component
                    module={TargetEditorComponent}
                    id={target_editor_id()}
                    target={@target}
                    owner={{:marketer, @current_marketer.id}}
                    copy={Targeting.copy(:target)}
                    show_me_file_counts?={true}
                  />
                </.page>
              <% @live_action == :inspect -> %>
                <.page class="max-w-5xl">
                  <.target_header
                    target={@target}
                    target_form={@target_form}
                    editing_target_info={@editing_target_info}
                  />
                  <Targeting.population_inspect
                    copy={Targeting.copy(:target)}
                    bands={@bands}
                    band_population_counts={@band_population_counts}
                  />
                </.page>
            <% end %>

            <.unsaved_changes_dialog />
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  attr :targets, :list, required: true
  attr :archived_targets, :list, required: true
  attr :show_archived, :boolean, required: true
  attr :new_target_form, :any, required: true

  defp index_view(assigns) do
    assigns = assign(assigns, :dirty, assigns.new_target_form.params != @blank_target_params)

    ~H"""
    <.page>
      <.page_header
        title="Targets"
        count={length(@targets)}
        subtitle="Audiences built from your trait groups, from a precise bullseye out to wider rings."
      />

      <div class="grid items-start gap-8 lg:grid-cols-[minmax(0,1fr)_360px]">
        <div class="min-w-0">
          <.panel flush>
            <.empty_state :if={@targets == []} icon="hero-viewfinder-circle" title="No targets yet">
              Name your first target in the form, then add trait groups to its bullseye.
            </.empty_state>

            <.target_list :if={@targets != []} targets={@targets} />
          </.panel>

          <.archived_section
            label="Archived targets"
            count={length(@archived_targets)}
            open={@show_archived}
            toggle="toggle_archived"
          >
            <.panel flush>
              <.target_list targets={@archived_targets} archived />
            </.panel>
          </.archived_section>
        </div>

        <.form
          for={@new_target_form}
          id="new-target-form"
          phx-change="validate_new_target"
          phx-submit="create_target"
          phx-hook="UnsavedChanges"
          data-dirty={to_string(@dirty)}
          data-dialog="unsaved-changes-dialog"
          class="lg:sticky lg:top-22"
        >
          <.panel title="New target" description="Name it now. You add trait groups on the next step.">
            <.input field={@new_target_form[:title]} type="text" label="Name" required />
            <.input
              field={@new_target_form[:description]}
              type="textarea"
              label="Description (optional)"
              rows="3"
            />
            <:footer>
              <.unsaved_note dirty={@dirty} id="unsaved-changes-note" />
              <.button variant="primary" phx-disable-with="Creating...">
                Create target <.icon name="hero-arrow-right" class="size-4" />
              </.button>
            </:footer>
          </.panel>
        </.form>
      </div>
    </.page>
    """
  end

  attr :targets, :list, required: true
  attr :archived, :boolean, default: false

  defp target_list(assigns) do
    ~H"""
    <ul class="divide-y divide-base-300">
      <li
        :for={target <- @targets}
        id={"target-#{target.id}"}
        class={[
          "flex items-center gap-4 px-6 py-4 transition-colors hover:bg-base-200/40",
          @archived && "opacity-70"
        ]}
      >
        <div class="flex size-10 shrink-0 items-center justify-center rounded-full bg-base-200 text-base-content/60">
          <.bullseye_icon />
        </div>

        <div class="min-w-0 flex-1">
          <div class="flex flex-wrap items-center gap-2">
            <.link navigate={target_path(target)} class="truncate font-semibold hover:underline">
              {target.title}
            </.link>
            <.target_status_badges target={target} />
          </div>
          <p :if={target.description} class="mt-0.5 truncate text-sm text-base-content/60">
            {target.description}
          </p>
          <div class="mt-2 flex flex-wrap gap-1.5">
            <.chip :for={tg <- target.bullseye_trait_groups}>
              <Targeting.role_badge group={tg} /> {tg.title}
            </.chip>
            <span :if={target.bullseye_trait_groups == []} class="text-xs text-base-content/50">
              No bullseye yet
            </span>
          </div>
        </div>

        <dl class="grid shrink-0 grid-cols-2 gap-6 text-right max-sm:hidden">
          <div>
            <dt class="text-xs text-base-content/50">Rings</dt>
            <dd class="font-semibold">
              {if target.target_bands == [], do: "-", else: length(target.target_bands)}
            </dd>
          </div>
          <div>
            <dt class="text-xs text-base-content/50">People</dt>
            <dd class="font-semibold">
              {if populated?(target), do: target.total_population, else: "-"}
            </dd>
          </div>
        </dl>

        <div class="flex shrink-0 items-center gap-1">
          <.link navigate={target_path(target)} class="btn btn-sm btn-ghost">
            <%= if populated?(target) do %>
              <.icon name="hero-chart-bar" class="size-4" /> Inspect
            <% else %>
              <.icon name="hero-wrench-screwdriver" class="size-4" /> Build
            <% end %>
          </.link>
          <.target_removal_action target={target} archived={@archived} />
        </div>
      </li>
    </ul>
    """
  end

  attr :target, :any, required: true
  attr :archived, :boolean, required: true

  defp target_removal_action(assigns) do
    ~H"""
    <%= cond do %>
      <% @archived -> %>
        <button
          type="button"
          phx-click="unarchive_target"
          phx-value-id={@target.id}
          class="btn btn-sm btn-ghost"
        >
          <.icon name="hero-arrow-uturn-left" class="size-4" /> Unarchive
        </button>
      <% @target.is_frozen -> %>
        <span
          class="btn btn-sm btn-ghost btn-square btn-disabled"
          title="In a live campaign. Deactivate the campaign to archive this target."
          aria-label="Locked by a live campaign"
        >
          <.icon name="hero-lock-closed" class="size-4" />
        </span>
      <% @target.used_in_campaign -> %>
        <button
          type="button"
          phx-click="archive_target"
          phx-value-id={@target.id}
          class="btn btn-sm btn-ghost btn-square"
          title="Archive. Used in a past campaign, so it is kept for history."
          aria-label={"Archive #{@target.title}"}
        >
          <.icon name="hero-archive-box" class="size-4" />
        </button>
      <% true -> %>
        <button
          type="button"
          phx-click="delete_target"
          phx-value-id={@target.id}
          data-confirm={"Delete \"#{@target.title}\"? Its rings and population are removed. Your trait groups are kept."}
          class="btn btn-sm btn-ghost btn-square text-error"
          title="Delete"
          aria-label={"Delete #{@target.title}"}
        >
          <.icon name="hero-trash" class="size-4" />
        </button>
    <% end %>
    """
  end

  defp target_path(target) do
    if populated?(target),
      do: ~p"/marketer/targets/#{target.id}/inspect",
      else: ~p"/marketer/targets/#{target.id}/edit"
  end

  defp populated?(target), do: target.population_status == "populated"

  attr :target, :any, required: true

  defp target_status_badges(assigns) do
    ~H"""
    <%= case @target.population_status do %>
      <% "populated" -> %>
        <.status_badge tone="success">Populated</.status_badge>
      <% "populating" -> %>
        <.status_badge tone="info">Populating</.status_badge>
      <% _ -> %>
        <.status_badge>Draft</.status_badge>
    <% end %>
    <.status_badge :if={@target.is_frozen} tone="warning">In live campaign</.status_badge>
    """
  end

  attr :target, :any, required: true
  attr :target_form, :any, required: true
  attr :editing_target_info, :boolean, required: true

  defp target_header(assigns) do
    assigns = assign(assigns, :dirty, assigns.target_form.source.changes != %{})

    ~H"""
    <.page_header
      back_to={~p"/marketer/targets"}
      back_label="Targets"
      title={@target.title}
      subtitle={@target.description}
    >
      <:badges>
        <.target_status_badges target={@target} />
      </:badges>
      <:actions :if={!@editing_target_info}>
        <button type="button" phx-click="toggle_edit_target_info" class="btn btn-sm btn-ghost">
          <.icon name="hero-pencil-square" class="size-4" /> Edit details
        </button>
      </:actions>
    </.page_header>

    <.form
      :if={@editing_target_info}
      for={@target_form}
      id="target-info-form"
      phx-change="validate_target"
      phx-submit="update_target"
      phx-hook="UnsavedChanges"
      data-dirty={to_string(@dirty)}
      data-dialog="unsaved-changes-dialog"
      class="mb-8"
    >
      <.panel title="Details">
        <div class="grid gap-x-4 md:grid-cols-2">
          <.input field={@target_form[:title]} type="text" label="Name" required />
          <.input field={@target_form[:description]} type="text" label="Description" />
        </div>
        <:footer>
          <.unsaved_note dirty={@dirty} id="unsaved-changes-note" />
          <button type="button" phx-click="cancel_edit_target_info" class="btn btn-ghost">
            Cancel
          </button>
          <.button variant="primary" phx-disable-with="Saving...">Save details</.button>
        </:footer>
      </.panel>
    </.form>
    """
  end
end
