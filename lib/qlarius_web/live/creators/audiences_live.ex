defmodule QlariusWeb.Creators.AudiencesLive do
  use QlariusWeb, :live_view

  alias Qlarius.Accounts.Marketers
  alias Qlarius.Creators
  alias Qlarius.Repo
  alias Qlarius.Sponster.Campaigns.{Target, Targets}
  alias Qlarius.Tiqit.Arcade.{Catalog, ContentGroup, ContentPiece}
  alias Qlarius.Tiqit.{ContentAudiences, CreatorAudienceStarters}
  alias Qlarius.YouData.Traits
  alias Qlarius.Sponster.Campaigns.TraitGroup
  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar, Targeting}

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
    bands = Targets.get_bands_for_target(target.id)
    outermost_band = Targets.get_outermost_band(target.id)

    available_trait_groups =
      Targets.get_available_trait_groups_for_target(
        target.id,
        {:creator, socket.assigns.creator.id}
      )

    socket
    |> assign(:target, target)
    |> assign(:bands, bands)
    |> assign(:outermost_band, outermost_band)
    |> assign(:available_trait_groups, available_trait_groups)
    |> assign(:target_form, to_form(Target.changeset(target, %{})))
    |> assign(:editing_target_info, false)
    |> assign(:expanding_target, false)
    |> assign(:tagged_by_parent, tagged_by_parent(bands))
    |> assign(:content_tag_parents, CreatorAudienceStarters.content_parent_traits())
    |> assign(:audience_tag_parents, CreatorAudienceStarters.audience_parent_traits())
  end

  defp assign_starter_defaults(socket) do
    socket
    |> assign(:starter_skipped, false)
    |> assign(:starter_open, false)
    |> assign(:show_modal, false)
    |> assign(:selected_parent_trait, nil)
    |> assign(:trait_group_form, nil)
    |> assign(:selected_ids, [])
    |> assign(:zip_search_term, "")
    |> assign(:selected_zips, [])
    |> assign(:zip_search_results, [])
    |> assign(:zip_search_limit, 1000)
    |> assign(:modal_heading, nil)
    |> assign(:modal_submit_label, "Save tags")
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
           |> reload_edit_data()}

        {:error, :trait_group_already_in_target} ->
          {:noreply, put_flash(socket, :error, "Trait group already in audience")}

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
     |> reload_edit_data()}
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
         |> reload_edit_data()}

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
         |> reload_edit_data()}

      {:error, :cannot_delete_bullseye} ->
        {:noreply, put_flash(socket, :error, "Cannot delete bullseye")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "No bands to delete")}
    end
  end

  def handle_event("populate_target", _params, socket) do
    ContentAudiences.trigger_population(socket.assigns.target)

    {:noreply,
     socket
     |> put_flash(:info, "Populating audience “#{socket.assigns.target.title}”...")
     |> push_navigate(to: inspect_path(socket.assigns.creator, socket.assigns.target))}
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

  def handle_event("done", _params, socket) do
    if socket.assigns[:bands] == [] do
      {:noreply,
       put_flash(socket, :error, "Add at least one tag or trait group before finishing")}
    else
      {:noreply, push_navigate(socket, to: ~p"/creators/#{socket.assigns.creator.id}/audiences")}
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
        {:noreply, put_flash(socket, :info, "Audience attached as #{mode}")}

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
     |> assign(:show_modal, false)}
  end

  def handle_event("show_starter", _params, socket) do
    {:noreply, assign(socket, :starter_open, true)}
  end

  def handle_event("tag_parent", %{"id" => id}, socket) do
    parent_id = String.to_integer(id)

    case Traits.get_trait_with_full_survey_data!(parent_id) do
      {:ok, trait} ->
        existing =
          socket.assigns.bands
          |> Enum.flat_map(& &1.trait_groups)
          |> Enum.find(&(&1.parent_trait_id == parent_id))

        selected_ids = if existing, do: Enum.map(existing.traits, & &1.id), else: []

        form =
          %TraitGroup{}
          |> TraitGroup.changeset(%{
            "creator_id" => socket.assigns.creator.id,
            "title" => (existing && existing.title) || trait.trait_name
          })
          |> to_form(as: :trait_group, id: "trait-group-form")

        {:noreply,
         socket
         |> assign(:show_modal, true)
         |> assign(:selected_parent_trait, trait)
         |> assign(:trait_group_form, form)
         |> assign(:selected_ids, selected_ids)
         |> assign(:zip_search_term, "")
         |> assign(:selected_zips, [])
         |> assign(:zip_search_results, [])
         |> assign(:zip_search_limit, 1000)
         |> assign(:modal_heading, "Tag: #{trait.trait_name}")
         |> assign(:modal_submit_label, "Save tags")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "That tag is not available")}
    end
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> assign(:selected_parent_trait, nil)
     |> assign(:trait_group_form, nil)}
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
      if socket.assigns.selected_parent_trait &&
           socket.assigns.selected_parent_trait.input_type == "single_select_zip" &&
           String.length(String.trim(search_term)) >= 2 do
        results =
          Traits.search_zip_codes(socket.assigns.selected_parent_trait.id, search_term, limit)

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
    trait_ids_list =
      trait_ids
      |> List.wrap()
      |> Enum.map(&String.to_integer/1)

    save_starter_group(socket, trait_group_params, trait_ids_list)
  end

  def handle_event("save_trait_group", %{"trait_group" => trait_group_params}, socket) do
    if socket.assigns.selected_parent_trait &&
         socket.assigns.selected_parent_trait.input_type == "single_select_zip" do
      if socket.assigns.selected_zips == [] do
        {:noreply, put_flash(socket, :error, "Please select at least one zip code")}
      else
        trait_ids_list = Enum.map(socket.assigns.selected_zips, & &1.id)
        save_starter_group(socket, trait_group_params, trait_ids_list)
      end
    else
      {:noreply, put_flash(socket, :error, "Please select at least one tag")}
    end
  end

  def handle_event("add_selected_zips", %{"selected_ids" => selected_ids}, socket) do
    selected_ids = if is_list(selected_ids), do: selected_ids, else: [selected_ids]
    new_zip_ids = Enum.map(selected_ids, &String.to_integer/1)

    new_zips =
      Enum.map(new_zip_ids, fn id ->
        trait = Repo.get!(Qlarius.YouData.Traits.Trait, id)
        %{id: trait.id, zip_code: trait.trait_name, location: trait.meta_1}
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
    visible_zips =
      Traits.search_zip_codes(
        socket.assigns.selected_parent_trait.id,
        socket.assigns.zip_search_term,
        Map.get(socket.assigns, :zip_search_limit, 1000)
      )

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

  defp save_starter_group(socket, trait_group_params, trait_ids_list) do
    if trait_ids_list == [] do
      {:noreply, put_flash(socket, :error, "Please select at least one tag")}
    else
      case ContentAudiences.create_starter_group(
             socket.assigns.current_scope,
             socket.assigns.target,
             socket.assigns.selected_parent_trait.id,
             trait_ids_list,
             title: trait_group_params["title"]
           ) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Tag saved")
           |> assign(:show_modal, false)
           |> assign(:starter_open, false)
           |> reload_edit_data()}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Could not save tags: #{inspect(reason)}")}
      end
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

  defp reload_edit_data(socket) do
    target = ContentAudiences.get_audience!(socket.assigns.creator.id, socket.assigns.target.id)
    assign_edit_data(socket, target)
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
                  outermost_band={@outermost_band}
                  available_trait_groups={@available_trait_groups}
                  target_form={@target_form}
                  editing_target_info={@editing_target_info}
                  expanding_target={@expanding_target}
                  attach={@attach}
                  marketers={@marketers}
                  starter_skipped={@starter_skipped}
                  starter_open={@starter_open}
                  content_tag_parents={@content_tag_parents}
                  audience_tag_parents={@audience_tag_parents}
                  tagged_by_parent={@tagged_by_parent}
                  show_modal={@show_modal}
                  selected_parent_trait={@selected_parent_trait}
                  trait_group_form={@trait_group_form}
                  selected_ids={@selected_ids}
                  zip_search_term={@zip_search_term}
                  zip_search_results={@zip_search_results}
                  selected_zips={@selected_zips}
                  zip_search_limit={@zip_search_limit}
                  modal_heading={@modal_heading}
                  modal_submit_label={@modal_submit_label}
                />
              <% :inspect -> %>
                <.inspect_view
                  creator={@creator}
                  target={@target}
                  bands={@bands}
                  band_population_counts={@band_population_counts}
                  target_form={@target_form}
                  editing_target_info={@editing_target_info}
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
    <div class="p-6 space-y-6">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold">Audiences</h1>
          <p class="text-base-content/60">{@creator.name}</p>
        </div>
        <div class="flex gap-2">
          <.link navigate={~p"/creators/#{@creator.id}/trait-groups"} class="btn btn-ghost">
            Trait groups
          </.link>
          <.link navigate={~p"/creators/#{@creator.id}/insights"} class="btn btn-ghost">
            Insights
          </.link>
          <button type="button" class="btn btn-primary" phx-click="new">New audience</button>
        </div>
      </div>

      <div :if={@attach} class="alert alert-info">
        <.icon name="hero-information-circle" class="w-6 h-6" />
        <span>Pick an audience to attach, or create a new one.</span>
      </div>

      <div :if={@audiences == []} class="card bg-base-100 dark:bg-base-200 border border-base-300">
        <div class="card-body text-center py-12">
          <.icon name="hero-user-group" class="w-16 h-16 mx-auto text-base-content/30 mb-4" />
          <p class="text-lg font-medium text-base-content/70">No audiences yet</p>
          <p class="text-sm text-base-content/50 mt-2">
            Create one to boost or restrict who sees this creator’s content.
          </p>
        </div>
      </div>

      <div :if={@audiences != []} class="overflow-x-auto">
        <table class="table table-zebra">
          <thead>
            <tr>
              <th>Audience</th>
              <th class="text-center">Reach</th>
              <th class="text-center">Uses</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr :for={aud <- @audiences}>
              <td class="font-medium">{aud.title}</td>
              <td class="text-center">{ContentAudiences.reach(aud)}</td>
              <td class="text-center">{length(aud.used_on)}</td>
              <td class="text-right">
                <.link
                  navigate={edit_path(@creator, aud, @attach)}
                  class="btn btn-sm btn-primary btn-outline"
                >
                  Build/Edit
                </.link>
                <.link
                  :if={aud.population_status == "populated"}
                  navigate={inspect_path(@creator, aud)}
                  class="btn btn-sm btn-info btn-outline"
                >
                  Inspect
                </.link>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  attr :creator, :map, required: true
  attr :target, :map, required: true
  attr :bands, :list, required: true
  attr :outermost_band, :any, required: true
  attr :available_trait_groups, :list, required: true
  attr :target_form, :any, required: true
  attr :editing_target_info, :boolean, required: true
  attr :expanding_target, :boolean, required: true
  attr :attach, :any, required: true
  attr :marketers, :list, required: true
  attr :starter_skipped, :boolean, required: true
  attr :starter_open, :boolean, required: true
  attr :content_tag_parents, :list, required: true
  attr :audience_tag_parents, :list, required: true
  attr :tagged_by_parent, :map, required: true
  attr :show_modal, :boolean, required: true
  attr :selected_parent_trait, :any, required: true
  attr :trait_group_form, :any, required: true
  attr :selected_ids, :list, required: true
  attr :zip_search_term, :string, required: true
  attr :zip_search_results, :list, required: true
  attr :selected_zips, :list, required: true
  attr :zip_search_limit, :any, required: true
  attr :modal_heading, :any, required: true
  attr :modal_submit_label, :string, required: true

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
    <div class="p-6">
      <Targeting.trait_group_modal
        :if={@show_modal && @selected_parent_trait}
        show_modal={@show_modal}
        parent_trait={@selected_parent_trait}
        form={@trait_group_form}
        zip_search_term={@zip_search_term}
        zip_search_results={@zip_search_results}
        selected_zips={@selected_zips}
        zip_search_limit={@zip_search_limit}
        heading={@modal_heading}
        submit_label={@modal_submit_label}
        selected_ids={@selected_ids}
      />

      <div class="flex items-center justify-between mb-2">
        <div class="flex items-center gap-3">
          <h1 class="text-2xl font-bold">{@target.title}</h1>
          <button
            type="button"
            phx-click="toggle_edit_target_info"
            class="btn btn-ghost btn-sm btn-circle"
            title="Edit audience name and description"
          >
            <.icon name="hero-pencil" class="w-5 h-5" />
          </button>
        </div>
        <div class="flex gap-2">
          <.link navigate={~p"/creators/#{@creator.id}/trait-groups"} class="btn btn-ghost btn-sm">
            Trait groups
          </.link>
          <.link navigate={~p"/creators/#{@creator.id}/audiences"} class="btn btn-ghost btn-sm">
            All audiences
          </.link>
        </div>
      </div>

      <p class="text-sm text-base-content/60 mb-4">{@creator.name}</p>

      <div
        :if={@editing_target_info}
        class="card bg-base-100 dark:bg-base-200 border border-base-300 mb-6"
      >
        <div class="card-body">
          <.form for={@target_form} phx-submit="update_target" class="space-y-4">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div class="form-control">
                <label class="label">
                  <span class="label-text">Audience Name</span>
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
              <button type="button" phx-click="cancel_edit_target_info" class="btn btn-ghost btn-sm">
                Cancel
              </button>
              <button type="submit" class="btn btn-primary btn-sm">Save</button>
            </div>
          </.form>
        </div>
      </div>

      <div :if={@target.description && !@editing_target_info} class="mb-6">
        <p class="text-base-content/70">{@target.description}</p>
      </div>

      <p class="text-sm text-warning mb-4">
        Editing this audience changes every place it is attached.
      </p>

      <div class="flex flex-wrap gap-2 mb-6">
        <button type="button" class="btn btn-sm" phx-click="refine">Copy to refine</button>
      </div>

      <div :if={@attach} class="flex gap-2 mb-6">
        <button
          type="button"
          class="btn btn-sm btn-primary"
          phx-click="attach"
          phx-value-mode="boost"
        >
          Attach as relevance
        </button>
        <button
          type="button"
          class="btn btn-sm btn-outline"
          phx-click="attach"
          phx-value-mode="gate"
        >
          Attach as restriction
        </button>
      </div>

      <form :if={@marketers != []} phx-submit="promote" class="flex gap-2 items-end mb-6">
        <label class="form-control grow">
          <span class="label-text">Promote with an ad</span>
          <select name="marketer_id" class="select select-bordered">
            <option :for={m <- @marketers} value={m.id}>{m.business_name}</option>
          </select>
        </label>
        <button class="btn btn-secondary">Clone to marketer</button>
      </form>

      <div :if={@show_starter?} class="card bg-base-100 dark:bg-base-200 border border-base-300 mb-6">
        <div class="card-body space-y-6">
          <div class="flex items-start justify-between gap-4">
            <div>
              <h2 class="text-xl font-bold">Tag your content</h2>
              <p class="text-sm text-base-content/60 mt-1">
                Tap a row and pick tags. These become the first groups on this audience.
              </p>
            </div>
            <button type="button" class="btn btn-ghost btn-sm" phx-click="skip_tagging">
              Skip tagging
            </button>
          </div>

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
      </div>

      <div :if={@show_collapsed?} class="mb-4">
        <button type="button" class="btn btn-ghost btn-sm" phx-click="show_starter">
          Add another tag
        </button>
      </div>

      <Targeting.band_editor
        copy={Targeting.copy(:audience)}
        bands={@bands}
        outermost_band={@outermost_band}
        available_trait_groups={@available_trait_groups}
        expanding_target={@expanding_target}
      />
    </div>
    """
  end

  attr :creator, :map, required: true
  attr :target, :map, required: true
  attr :bands, :list, required: true
  attr :band_population_counts, :map, required: true
  attr :target_form, :any, required: true
  attr :editing_target_info, :boolean, required: true

  defp inspect_view(assigns) do
    ~H"""
    <div class="p-6">
      <div class="flex items-center justify-between mb-2">
        <div class="flex items-center gap-3">
          <h1 class="text-2xl font-bold">{@target.title}</h1>
          <button
            type="button"
            phx-click="toggle_edit_target_info"
            class="btn btn-ghost btn-sm btn-circle"
            title="Edit audience name and description"
          >
            <.icon name="hero-pencil" class="w-5 h-5" />
          </button>
        </div>
        <.link
          navigate={~p"/creators/#{@creator.id}/audiences/#{@target.id}/edit"}
          class="btn btn-ghost btn-sm"
        >
          Edit audience
        </.link>
      </div>

      <p class="text-sm text-base-content/60 mb-4">{@creator.name}</p>

      <div
        :if={@editing_target_info}
        class="card bg-base-100 dark:bg-base-200 border border-base-300 mb-6"
      >
        <div class="card-body">
          <.form for={@target_form} phx-submit="update_target" class="space-y-4">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div class="form-control">
                <label class="label">
                  <span class="label-text">Audience Name</span>
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
              <button type="button" phx-click="cancel_edit_target_info" class="btn btn-ghost btn-sm">
                Cancel
              </button>
              <button type="submit" class="btn btn-primary btn-sm">Save</button>
            </div>
          </.form>
        </div>
      </div>

      <div :if={@target.description && !@editing_target_info} class="mb-6">
        <p class="text-base-content/70">{@target.description}</p>
      </div>

      <Targeting.population_inspect
        copy={Targeting.copy(:audience)}
        bands={@bands}
        band_population_counts={@band_population_counts}
        show_frozen_note?={false}
      />
    </div>
    """
  end

  defp audience_empty?(bands) do
    bands == [] or Enum.all?(bands, fn band -> band.trait_groups == [] end)
  end

  defp tagged_by_parent(bands) do
    for band <- bands, tg <- band.trait_groups, reduce: %{} do
      acc ->
        names = Enum.map(tg.traits || [], & &1.trait_name)

        if tg.parent_trait_id do
          Map.put(acc, tg.parent_trait_id, names)
        else
          acc
        end
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

  defp inspect_path(creator, target),
    do: ~p"/creators/#{creator.id}/audiences/#{target.id}/inspect"

  defp load_attach_content!(%{level: :creator, id: id}), do: Creators.get_creator!(id)
  defp load_attach_content!(%{level: :catalog, id: id}), do: Repo.get!(Catalog, id)
  defp load_attach_content!(%{level: :group, id: id}), do: Repo.get!(ContentGroup, id)
  defp load_attach_content!(%{level: :piece, id: id}), do: Repo.get!(ContentPiece, id)
end
