defmodule QlariusWeb.Creators.AudiencesLive do
  use QlariusWeb, :live_view

  import QlariusWeb.Components.MarketerUI

  alias Qlarius.Accounts.Marketers
  alias Qlarius.Creators
  alias Qlarius.Repo
  alias Qlarius.Sponster.Campaigns.{Target, Targets}
  alias Qlarius.Tiqit.Arcade.{Catalog, ContentGroup, ContentPiece}
  alias Qlarius.Tiqit.{ContentAudiences, CreatorAudienceStarters}
  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar, Targeting}
  alias QlariusWeb.Live.{TargetEditorComponent, TraitGroupEditorComponent}

  defp target_editor_id, do: "target-editor"

  @impl true
  def mount(%{"creator_id" => creator_id}, _session, socket) do
    creator = Creators.accessible_creator!(socket.assigns.current_scope, creator_id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Qlarius.PubSub, "targets")
    end

    {:ok,
     socket
     |> assign(:creator, creator)
     |> assign(:page_title, "Audiences")
     |> assign(:target, nil)
     |> assign(:marketers, Marketers.list_user_marketers(socket.assigns.current_scope.user.id))
     |> assign_starter_defaults()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      socket
      |> assign(:attach, attach_from_params(params))
      |> apply_action(socket.assigns.live_action, params)

    {:noreply, socket}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Audiences")
    |> assign(:target, nil)
    |> assign(:audiences, ContentAudiences.list_audiences(socket.assigns.creator.id))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    target = ContentAudiences.get_audience!(socket.assigns.creator.id, String.to_integer(id))
    same_target? = socket.assigns[:target] && socket.assigns.target.id == target.id

    socket
    |> assign(:page_title, "Edit Audience: #{target.title}")
    |> assign_edit_data(target)
    |> then(fn socket ->
      if same_target? do
        socket
      else
        empty? = audience_empty?(socket.assigns.bands)

        socket
        |> assign_starter_defaults()
        |> assign(:starter_open, empty?)
      end
    end)
  end

  defp apply_action(socket, :inspect, %{"id" => id}) do
    target = ContentAudiences.get_audience!(socket.assigns.creator.id, String.to_integer(id))
    bands = Targets.get_bands_for_target(target.id)
    band_population_counts = Targets.get_band_population_counts(target.id)

    socket
    |> assign(:page_title, "Inspect Audience: #{target.title}")
    |> assign(:target, target)
    |> assign(:bands, bands)
    |> assign(:band_population_counts, band_population_counts)
    |> assign(:target_form, to_form(Target.changeset(target, %{})))
    |> assign(:editing_target_info, false)
  end

  defp assign_edit_data(socket, target) do
    socket
    |> assign(:target, target)
    |> assign(:target_form, to_form(Target.changeset(target, %{})))
    |> assign(:editing_target_info, false)
    |> assign_bands(target)
    |> assign(:content_tag_parents, CreatorAudienceStarters.content_parent_traits())
    |> assign(:audience_tag_parents, CreatorAudienceStarters.audience_parent_traits())
  end

  # The starter cards read the bands directly; the band editor component loads
  # its own copy and tells us when they change.
  defp assign_bands(socket, target) do
    bands = Targets.get_bands_for_target(target.id)

    socket
    |> assign(:bands, bands)
    |> assign(:tagged_by_parent, tagged_by_parent(bands))
  end

  defp assign_starter_defaults(socket) do
    socket
    |> assign(:starter_skipped, false)
    |> assign(:starter_open, false)
    |> close_starter_editor()
  end

  defp close_starter_editor(socket) do
    socket
    |> assign(:editor_parent_trait_id, nil)
    |> assign(:editor_preselected_ids, [])
    |> assign(:editor_title, nil)
    |> assign(:editor_heading, nil)
  end

  @impl true
  def handle_event("new", _params, socket) do
    {:ok, target} =
      ContentAudiences.create_audience(socket.assigns.current_scope, socket.assigns.creator.id, %{
        title: "New audience"
      })

    {:noreply,
     push_navigate(socket, to: edit_path(socket.assigns.creator, target, socket.assigns.attach))}
  end

  def handle_event("toggle_edit_target_info", _params, socket) do
    {:noreply, assign(socket, :editing_target_info, !socket.assigns.editing_target_info)}
  end

  def handle_event("update_target", %{"target" => target_params}, socket) do
    case Targets.update_target(socket.assigns.target, target_params) do
      {:ok, target} ->
        {:noreply,
         socket
         |> put_flash(:info, "Audience updated")
         |> assign(:target, target)
         |> assign(:editing_target_info, false)
         |> assign(:page_title, "Edit Audience: #{target.title}")}

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
    ContentAudiences.trigger_population(socket.assigns.target)

    {:noreply,
     socket
     |> put_flash(:info, "Refreshing reach for “#{socket.assigns.target.title}”...")
     |> assign(:refreshing, true)}
  end

  def handle_event("depopulate_target", _params, socket) do
    case Targets.depopulate_target(socket.assigns.target.id) do
      {:ok, _target} ->
        {:noreply,
         socket
         |> put_flash(:info, "Audience depopulated")
         |> push_navigate(
           to: edit_path(socket.assigns.creator, socket.assigns.target, socket.assigns.attach)
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to depopulate audience")}
    end
  end

  def handle_event("attach", %{"mode" => mode}, socket) do
    mode = String.to_existing_atom(mode)
    content = load_attach_content!(socket.assigns.attach)

    case ContentAudiences.set_attachment(
           socket.assigns.current_scope,
           socket.assigns.target,
           content,
           mode
         ) do
      {:ok, _} ->
        label = if mode == :gate, do: "restriction", else: "relevance"

        {:noreply,
         socket
         |> put_flash(:info, "“#{socket.assigns.target.title}” attached as #{label}")
         |> push_navigate(to: attach_return_path(socket.assigns.attach))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not attach: #{inspect(reason)}")}
    end
  end

  def handle_event("refine", _params, socket) do
    {:ok, copy} =
      ContentAudiences.copy_within_org(socket.assigns.current_scope, socket.assigns.target)

    {:noreply,
     socket
     |> put_flash(:info, "Copied for refinement")
     |> push_navigate(to: edit_path(socket.assigns.creator, copy, socket.assigns.attach))}
  end

  def handle_event("promote", %{"marketer_id" => marketer_id}, socket) do
    marketer_id = String.to_integer(marketer_id)

    case Targets.clone_across_orgs(
           socket.assigns.current_scope,
           socket.assigns.target,
           {:marketer, marketer_id},
           populate: true
         ) do
      {:ok, clone} ->
        {:noreply,
         socket
         |> put_flash(:info, "Cloned into marketer org as “#{clone.title}”")
         |> push_navigate(to: ~p"/marketer/targets/#{clone.id}/edit")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not promote: #{inspect(reason)}")}
    end
  end

  def handle_event("skip_tagging", _params, socket) do
    {:noreply,
     socket
     |> assign(:starter_skipped, true)
     |> assign(:starter_open, false)
     |> close_starter_editor()}
  end

  def handle_event("show_starter", _params, socket) do
    {:noreply, assign(socket, :starter_open, true)}
  end

  def handle_event("tag_parent", %{"id" => id}, socket) do
    parent_id = String.to_integer(id)

    existing =
      socket.assigns.bands
      |> Enum.flat_map(& &1.trait_groups)
      |> Enum.find(&(&1.parent_trait_id == parent_id))

    parent_name =
      Enum.find_value(
        socket.assigns.content_tag_parents ++ socket.assigns.audience_tag_parents,
        fn parent -> parent.id == parent_id && parent.trait_name end
      )

    {:noreply,
     socket
     |> assign(:editor_parent_trait_id, parent_id)
     |> assign(
       :editor_preselected_ids,
       if(existing, do: Enum.map(existing.traits, & &1.id), else: [])
     )
     |> assign(:editor_title, (existing && existing.title) || parent_name)
     |> assign(:editor_heading, parent_name && "Tag: #{parent_name}")}
  end

  @impl true
  def handle_info({TraitGroupEditorComponent, :saved, _group}, socket) do
    send_update(TargetEditorComponent, id: target_editor_id(), reload: true)

    {:noreply,
     socket
     |> put_flash(:info, "Tag saved")
     |> assign(:starter_open, false)
     |> close_starter_editor()
     |> assign_bands(socket.assigns.target)}
  end

  def handle_info({TraitGroupEditorComponent, :closed}, socket) do
    {:noreply, close_starter_editor(socket)}
  end

  def handle_info({TraitGroupEditorComponent, :failed, _message}, socket) do
    {:noreply,
     socket
     |> put_flash(:error, "That tag is not available")
     |> close_starter_editor()}
  end

  def handle_info({TargetEditorComponent, {:flash, kind, message}}, socket) do
    {:noreply, put_flash(socket, kind, message)}
  end

  def handle_info({TargetEditorComponent, :changed}, socket) do
    {:noreply, assign_bands(socket, socket.assigns.target)}
  end

  def handle_info({TargetEditorComponent, :populating}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Populating audience “#{socket.assigns.target.title}”...")
     |> push_navigate(
       to: inspect_path(socket.assigns.creator, socket.assigns.target, socket.assigns.attach)
     )}
  end

  def handle_info({TargetEditorComponent, :done}, socket) do
    {:noreply,
     push_navigate(socket, to: index_path(socket.assigns.creator, socket.assigns.attach))}
  end

  def handle_info(msg, socket) do
    case msg do
      {:target_populated, target_id, _timestamp} ->
        cond do
          socket.assigns.live_action == :index ->
            {:noreply,
             assign(
               socket,
               :audiences,
               ContentAudiences.list_audiences(socket.assigns.creator.id)
             )}

          socket.assigns.live_action == :inspect && socket.assigns.target &&
              socket.assigns.target.id == target_id ->
            target = ContentAudiences.get_audience!(socket.assigns.creator.id, target_id)
            bands = Targets.get_bands_for_target(target.id)

            {:noreply,
             socket
             |> put_flash(:info, "Reach refreshed for “#{target.title}”")
             |> assign(:target, target)
             |> assign(:bands, bands)
             |> assign(:band_population_counts, Targets.get_band_population_counts(target.id))}

          socket.assigns.live_action == :edit && socket.assigns.target &&
              socket.assigns.target.id == target_id ->
            send_update(TargetEditorComponent, id: target_editor_id(), reload: true)

            {:noreply,
             socket
             |> put_flash(:info, "Audience population complete")
             |> reload_edit_data()}

          true ->
            {:noreply, socket}
        end

      _ ->
        {:noreply, socket}
    end
  end

  defp starter_saver(scope, target) do
    fn attrs ->
      ContentAudiences.create_starter_group(
        scope,
        target,
        attrs.parent_trait_id,
        attrs.trait_ids,
        title: attrs.title
      )
    end
  end

  defp reload_edit_data(socket) do
    target = ContentAudiences.get_audience!(socket.assigns.creator.id, socket.assigns.target.id)
    assign_edit_data(socket, target)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin {assigns}>
      <div class="flex h-screen">
        <AdminSidebar.sidebar current_user={@current_scope.user} current_path={@current_path} />
        <div class="flex min-w-0 grow flex-col">
          <AdminTopbar.topbar current_user={@current_scope.user} />
          <div class="overflow-auto flex-1">
            <%= case @live_action do %>
              <% :index -> %>
                <.index_view
                  creator={@creator}
                  audiences={@audiences}
                  attach={@attach}
                />
              <% :edit -> %>
                <.edit_view
                  creator={@creator}
                  target={@target}
                  bands={@bands}
                  target_form={@target_form}
                  editing_target_info={@editing_target_info}
                  attach={@attach}
                  marketers={@marketers}
                  starter_skipped={@starter_skipped}
                  starter_open={@starter_open}
                  content_tag_parents={@content_tag_parents}
                  audience_tag_parents={@audience_tag_parents}
                  tagged_by_parent={@tagged_by_parent}
                  editor_parent_trait_id={@editor_parent_trait_id}
                  editor_preselected_ids={@editor_preselected_ids}
                  editor_title={@editor_title}
                  editor_heading={@editor_heading}
                  on_save={starter_saver(@current_scope, @target)}
                />
              <% :inspect -> %>
                <.inspect_view
                  creator={@creator}
                  target={@target}
                  bands={@bands}
                  band_population_counts={@band_population_counts}
                  target_form={@target_form}
                  editing_target_info={@editing_target_info}
                  attach={@attach}
                />
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  attr :creator, :map, required: true
  attr :audiences, :list, required: true
  attr :attach, :any, required: true

  defp index_view(assigns) do
    ~H"""
    <.page>
      <.page_header
        title="Audiences"
        count={length(@audiences)}
        subtitle="Boost or restrict who sees this creator’s content."
        back_to={~p"/creators/#{@creator.id}"}
        back_label={@creator.name}
      >
        <:actions>
          <.link navigate={~p"/creators/#{@creator.id}/trait-groups"} class="btn btn-sm btn-ghost">
            Trait groups
          </.link>
          <.link navigate={~p"/creators/#{@creator.id}/insights"} class="btn btn-sm btn-ghost">
            Insights
          </.link>
          <button type="button" class="btn btn-sm btn-primary" phx-click="new">
            <.icon name="hero-plus" class="size-4" /> New audience
          </button>
        </:actions>
      </.page_header>

      <div
        :if={@attach}
        class="mb-4 flex items-center gap-3 rounded-xl border border-base-300 bg-base-200/40 px-4 py-3 text-sm text-base-content/70"
      >
        <.icon name="hero-information-circle" class="size-5 shrink-0 text-base-content/50" />
        <span>Pick an audience to attach, or create a new one.</span>
      </div>

      <.panel flush>
        <.empty_state :if={@audiences == []} icon="hero-user-group" title="No audiences yet">
          Create one to boost or restrict who sees this creator’s content.
        </.empty_state>

        <.data_table
          :if={@audiences != []}
          id="audiences"
          rows={@audiences}
          row_id={&"audience-#{&1.id}"}
        >
          <:col :let={aud} label="Audience">
            <div class="flex flex-wrap items-center gap-2">
              <.link
                navigate={edit_path(@creator, aud, @attach)}
                class="font-semibold hover:underline"
              >
                {aud.title}
              </.link>
              <.audience_status_badge audience={aud} />
            </div>
            <p :if={aud.description} class="mt-0.5 truncate text-sm text-base-content/60">
              {aud.description}
            </p>
          </:col>
          <:col :let={aud} label="Reach" class="text-right">{ContentAudiences.reach(aud)}</:col>
          <:col :let={aud} label="Uses" class="text-right">{length(aud.used_on)}</:col>
          <:action :let={aud}>
            <.link
              :if={aud.population_status == "populated"}
              navigate={inspect_path(@creator, aud, @attach)}
              class="btn btn-sm btn-ghost"
            >
              <.icon name="hero-chart-bar" class="size-4" /> Inspect
            </.link>
            <.link navigate={edit_path(@creator, aud, @attach)} class="btn btn-sm btn-ghost">
              <.icon name="hero-wrench-screwdriver" class="size-4" /> Build
            </.link>
          </:action>
        </.data_table>
      </.panel>
    </.page>
    """
  end

  attr :audience, :map, required: true

  defp audience_status_badge(assigns) do
    ~H"""
    <%= case @audience.population_status do %>
      <% "populated" -> %>
        <.status_badge tone="success">Populated</.status_badge>
      <% "populating" -> %>
        <.status_badge tone="info">Populating</.status_badge>
      <% _ -> %>
        <.status_badge>Draft</.status_badge>
    <% end %>
    """
  end

  attr :creator, :map, required: true
  attr :target, :map, required: true
  attr :target_form, :any, required: true
  attr :editing_target_info, :boolean, required: true
  attr :attach, :any, required: true
  slot :actions

  defp audience_header(assigns) do
    ~H"""
    <.page_header
      title={@target.title}
      subtitle={!@editing_target_info && @target.description}
      back_to={index_path(@creator, @attach)}
      back_label="Audiences"
    >
      <:badges>
        <.audience_status_badge audience={@target} />
      </:badges>
      <:actions>
        <button
          :if={!@editing_target_info}
          type="button"
          phx-click="toggle_edit_target_info"
          class="btn btn-sm btn-ghost"
          title="Edit audience name and description"
        >
          <.icon name="hero-pencil-square" class="size-4" /> Edit details
        </button>
        {render_slot(@actions)}
      </:actions>
    </.page_header>

    <.form :if={@editing_target_info} for={@target_form} phx-submit="update_target" class="mb-8">
      <.panel title="Details">
        <div class="grid gap-x-4 md:grid-cols-2">
          <.input field={@target_form[:title]} type="text" label="Audience name" />
          <.input field={@target_form[:description]} type="text" label="Description" />
        </div>
        <:footer>
          <button type="button" phx-click="cancel_edit_target_info" class="btn btn-sm btn-ghost">
            Cancel
          </button>
          <button type="submit" class="btn btn-sm btn-primary">Save</button>
        </:footer>
      </.panel>
    </.form>
    """
  end

  attr :creator, :map, required: true
  attr :target, :map, required: true
  attr :bands, :list, required: true
  attr :target_form, :any, required: true
  attr :editing_target_info, :boolean, required: true
  attr :attach, :any, required: true
  attr :marketers, :list, required: true
  attr :starter_skipped, :boolean, required: true
  attr :starter_open, :boolean, required: true
  attr :content_tag_parents, :list, required: true
  attr :audience_tag_parents, :list, required: true
  attr :tagged_by_parent, :map, required: true
  attr :editor_parent_trait_id, :any, required: true
  attr :editor_preselected_ids, :list, required: true
  attr :editor_title, :any, required: true
  attr :editor_heading, :any, required: true
  attr :on_save, :any, required: true

  defp edit_view(assigns) do
    empty? = audience_empty?(assigns.bands)
    starter_configured? = assigns.content_tag_parents != [] or assigns.audience_tag_parents != []

    show_starter? =
      starter_configured? and not assigns.starter_skipped and (empty? or assigns.starter_open)

    show_collapsed? =
      starter_configured? and not assigns.starter_skipped and not empty? and
        not assigns.starter_open

    content_tagged? =
      Enum.any?(assigns.content_tag_parents, &Map.has_key?(assigns.tagged_by_parent, &1.id))

    show_audience_tags? =
      assigns.audience_tag_parents != [] and
        (content_tagged? or assigns.content_tag_parents == [])

    assigns =
      assigns
      |> assign(:show_starter?, show_starter?)
      |> assign(:show_collapsed?, show_collapsed?)
      |> assign(:show_audience_tags?, show_audience_tags?)

    ~H"""
    <.page>
      <.live_component
        module={TraitGroupEditorComponent}
        id="trait-group-editor"
        owner={{:creator, @creator.id}}
        parent_trait_id={@editor_parent_trait_id}
        preselected_ids={@editor_preselected_ids}
        title={@editor_title}
        heading={@editor_heading}
        submit_label="Save tags"
        on_save={@on_save}
      />

      <.audience_header
        creator={@creator}
        target={@target}
        target_form={@target_form}
        editing_target_info={@editing_target_info}
        attach={@attach}
      >
        <:actions>
          <button type="button" class="btn btn-sm btn-ghost" phx-click="refine">
            <.icon name="hero-document-duplicate" class="size-4" /> Copy to refine
          </button>
          <.link navigate={~p"/creators/#{@creator.id}/trait-groups"} class="btn btn-sm btn-ghost">
            Trait groups
          </.link>
        </:actions>
      </.audience_header>

      <p class="mb-6 flex items-center gap-2 text-sm text-base-content/60">
        <.icon name="hero-exclamation-triangle" class="size-4 shrink-0 text-warning" />
        Editing this audience changes every place it is attached.
      </p>

      <.attach_buttons attach={@attach} />

      <.panel
        :if={@show_starter?}
        title="Tag your content"
        description="Tap a row and pick tags. These become the first groups on this audience."
        class="mb-8"
      >
        <:actions>
          <button type="button" class="btn btn-sm btn-ghost" phx-click="skip_tagging">
            Skip tagging
          </button>
        </:actions>
        <div class="space-y-6">
          <Targeting.tag_starter_cards
            :if={@content_tag_parents != []}
            title="What is this?"
            parents={@content_tag_parents}
            tagged_by_parent={@tagged_by_parent}
          />

          <Targeting.tag_starter_cards
            :if={@show_audience_tags?}
            title="Who is it for? (optional)"
            parents={@audience_tag_parents}
            tagged_by_parent={@tagged_by_parent}
          />
        </div>
      </.panel>

      <div :if={@show_collapsed?} class="mb-6">
        <button type="button" class="btn btn-sm btn-ghost" phx-click="show_starter">
          <.icon name="hero-plus" class="size-4" /> Add another tag
        </button>
      </div>

      <.live_component
        module={TargetEditorComponent}
        id={target_editor_id()}
        target={@target}
        owner={{:creator, @creator.id}}
        copy={Targeting.copy(:audience)}
      />

      <.panel
        :if={@marketers != []}
        title="Promote with an ad"
        description="Clone this audience into one of your marketer accounts as a target."
        class="mt-8"
      >
        <form phx-submit="promote" class="flex flex-wrap items-end gap-2">
          <label class="min-w-0 grow">
            <span class="mb-1 block text-xs text-base-content/50">Marketer</span>
            <select name="marketer_id" class="select select-sm w-full">
              <option :for={m <- @marketers} value={m.id}>{m.business_name}</option>
            </select>
          </label>
          <button type="submit" class="btn btn-sm">Clone to marketer</button>
        </form>
      </.panel>
    </.page>
    """
  end

  attr :creator, :map, required: true
  attr :target, :map, required: true
  attr :bands, :list, required: true
  attr :band_population_counts, :map, required: true
  attr :target_form, :any, required: true
  attr :editing_target_info, :boolean, required: true
  attr :attach, :any, required: true

  defp inspect_view(assigns) do
    ~H"""
    <.page class="max-w-5xl">
      <.audience_header
        creator={@creator}
        target={@target}
        target_form={@target_form}
        editing_target_info={@editing_target_info}
        attach={@attach}
      >
        <:actions>
          <.link navigate={edit_path(@creator, @target, @attach)} class="btn btn-sm btn-ghost">
            <.icon name="hero-wrench-screwdriver" class="size-4" /> Edit audience
          </.link>
        </:actions>
      </.audience_header>

      <.attach_buttons attach={@attach} />

      <Targeting.population_inspect
        copy={Targeting.copy(:audience)}
        bands={@bands}
        band_population_counts={@band_population_counts}
        show_frozen_note?={false}
      />
    </.page>
    """
  end

  attr :attach, :any, required: true

  defp attach_buttons(assigns) do
    ~H"""
    <div
      :if={@attach}
      class="mb-8 flex flex-wrap items-center justify-between gap-3 rounded-xl border border-base-300 bg-base-200/40 px-4 py-3"
    >
      <p class="text-sm text-base-content/70">Attach this audience to the content you came from.</p>
      <div class="flex flex-wrap gap-2">
        <button type="button" class="btn btn-sm btn-ghost" phx-click="attach" phx-value-mode="gate">
          Attach as restriction
        </button>
        <button
          type="button"
          class="btn btn-sm btn-primary"
          phx-click="attach"
          phx-value-mode="boost"
        >
          Attach as relevance
        </button>
      </div>
    </div>
    """
  end

  defp audience_empty?(bands) do
    bands == [] or Enum.all?(bands, fn band -> band.trait_groups == [] end)
  end

  # Keyed on each trait's own parent so a multi-topic group shows under every
  # topic it covers. Anti-Trait Groups are left out: the starter cards describe
  # who the audience welcomes.
  defp tagged_by_parent(bands) do
    for band <- bands,
        tg <- band.trait_groups,
        tg.role != "anti",
        trait <- tg.traits || [],
        trait.parent_trait_id,
        reduce: %{} do
      acc ->
        Map.update(acc, trait.parent_trait_id, [trait.trait_name], &(&1 ++ [trait.trait_name]))
    end
  end

  defp attach_from_params(%{"attach" => level, "attach_id" => id}) do
    %{level: String.to_existing_atom(level), id: String.to_integer(id)}
  end

  defp attach_from_params(_), do: nil

  defp edit_path(creator, target, nil),
    do: ~p"/creators/#{creator.id}/audiences/#{target.id}/edit"

  defp edit_path(creator, target, %{level: level, id: id}),
    do: ~p"/creators/#{creator.id}/audiences/#{target.id}/edit?attach=#{level}&attach_id=#{id}"

  defp inspect_path(creator, target, nil),
    do: ~p"/creators/#{creator.id}/audiences/#{target.id}/inspect"

  defp inspect_path(creator, target, %{level: level, id: id}),
    do: ~p"/creators/#{creator.id}/audiences/#{target.id}/inspect?attach=#{level}&attach_id=#{id}"

  defp index_path(creator, nil), do: ~p"/creators/#{creator.id}/audiences"

  defp index_path(creator, %{level: level, id: id}),
    do: ~p"/creators/#{creator.id}/audiences?attach=#{level}&attach_id=#{id}"

  defp attach_return_path(%{level: :creator, id: id}), do: ~p"/creators/#{id}"
  defp attach_return_path(%{level: :catalog, id: id}), do: ~p"/creators/catalogs/#{id}"
  defp attach_return_path(%{level: :group, id: id}), do: ~p"/creators/content_groups/#{id}"
  defp attach_return_path(%{level: :piece, id: id}), do: ~p"/creators/content_pieces/#{id}"

  defp load_attach_content!(%{level: :creator, id: id}), do: Creators.get_creator!(id)
  defp load_attach_content!(%{level: :catalog, id: id}), do: Repo.get!(Catalog, id)
  defp load_attach_content!(%{level: :group, id: id}), do: Repo.get!(ContentGroup, id)
  defp load_attach_content!(%{level: :piece, id: id}), do: Repo.get!(ContentPiece, id)
end
