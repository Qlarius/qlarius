defmodule QlariusWeb.CreatorDashboard.Index do
  use QlariusWeb, :live_view

  import QlariusWeb.Components.MarketerUI

  alias Qlarius.Creators
  alias Qlarius.Creators.Creator
  alias QlariusWeb.Uploaders.CreatorImage
  alias QlariusWeb.LiveView.ImageUpload
  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}

  @impl true
  def mount(_params, _session, socket) do
    creators = Creators.list_creators()

    {:ok,
     socket
     |> assign(:creators, creators)
     |> assign(:page_title, "My Creators")
     |> assign(:show_form, false)
     |> assign(:form, nil)
     |> assign(:editing_creator, nil)
     |> assign(:view, :grid)
     |> assign(:search, "")
     |> assign(:sort, :az)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "My Creators")
    |> assign(:show_form, false)
    |> assign(:form, nil)
    |> assign(:editing_creator, nil)
  end

  defp apply_action(socket, :new, _params) do
    changeset = Creators.change_creator(%Creator{})

    socket
    |> assign(:page_title, "New Creator")
    |> assign(:show_form, true)
    |> assign(:form, to_form(changeset))
    |> assign(:editing_creator, nil)
    |> ImageUpload.setup_upload(:image, auto_upload: true)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    creator = Creators.get_creator!(id)
    changeset = Creators.change_creator(creator)

    socket
    |> assign(:page_title, "Edit Creator")
    |> assign(:show_form, true)
    |> assign(:form, to_form(changeset))
    |> assign(:editing_creator, creator)
    |> ImageUpload.setup_upload(:image, auto_upload: true)
  end

  @impl true
  def handle_event("validate", %{"creator" => creator_params}, socket) do
    creator = socket.assigns.editing_creator || %Creator{}

    form =
      creator
      |> Creators.change_creator(creator_params)
      |> to_form(action: :validate)

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"creator" => creator_params}, socket) do
    save_creator(socket, socket.assigns.live_action, creator_params)
  end

  def handle_event("cancel", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_form, false)
     |> assign(:form, nil)
     |> assign(:editing_creator, nil)
     |> push_patch(to: ~p"/creators")}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    creator = Creators.get_creator!(id)
    {:ok, _} = Creators.delete_creator(creator)

    creators = Creators.list_creators()

    {:noreply,
     socket
     |> assign(:creators, creators)
     |> put_flash(:info, "Creator deleted successfully")}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :image, ref)}
  end

  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, assign(socket, :search, q)}
  end

  def handle_event("sort", %{"sort" => sort}, socket) do
    {:noreply, assign(socket, :sort, parse_sort(sort))}
  end

  def handle_event("set_view", %{"view" => view}, socket) do
    {:noreply, assign(socket, :view, parse_view(view))}
  end

  defp save_creator(socket, :new, creator_params) do
    case Creators.create_creator(creator_params) do
      {:ok, creator} ->
        creator_params_with_image =
          ImageUpload.consume_and_add_to_params(
            socket,
            :image,
            creator,
            CreatorImage,
            %{}
          )

        _creator =
          if Map.has_key?(creator_params_with_image, "image") do
            {:ok, updated} =
              Creators.update_creator(creator, creator_params_with_image)

            updated
          else
            creator
          end

        creators = Creators.list_creators()

        {:noreply,
         socket
         |> assign(:creators, creators)
         |> assign(:show_form, false)
         |> assign(:form, nil)
         |> assign(:editing_creator, nil)
         |> put_flash(:info, "Creator created successfully")
         |> push_patch(to: ~p"/creators")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
    end
  end

  defp save_creator(socket, :edit, creator_params) do
    creator_params_with_image =
      ImageUpload.consume_and_add_to_params(
        socket,
        :image,
        socket.assigns.editing_creator,
        CreatorImage,
        creator_params
      )

    case Creators.update_creator(socket.assigns.editing_creator, creator_params_with_image) do
      {:ok, _creator} ->
        creators = Creators.list_creators()

        {:noreply,
         socket
         |> assign(:creators, creators)
         |> assign(:show_form, false)
         |> assign(:form, nil)
         |> assign(:editing_creator, nil)
         |> put_flash(:info, "Creator updated successfully")
         |> push_patch(to: ~p"/creators")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin {assigns}>
      <div class="flex h-screen">
        <AdminSidebar.sidebar current_user={@current_scope.user} />
        <div class="flex min-w-0 grow flex-col">
          <AdminTopbar.topbar current_user={@current_scope.user} />
          <div class="overflow-auto">
            <%= if @show_form do %>
              <.page class="max-w-3xl">
                <.page_header
                  title={if @editing_creator, do: "Edit creator", else: "New creator"}
                  subtitle={
                    if @editing_creator,
                      do: @editing_creator.name,
                      else: "Create a new creator profile."
                  }
                  back_to={~p"/creators"}
                  back_label="Creators"
                />
                <.creator_form
                  form={@form}
                  uploads={@uploads}
                  editing_creator={@editing_creator}
                />
              </.page>
            <% else %>
              <.index_view creators={@creators} search={@search} sort={@sort} view={@view} />
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  attr :creators, :list, required: true
  attr :search, :string, required: true
  attr :sort, :atom, required: true
  attr :view, :atom, required: true

  defp index_view(assigns) do
    assigns =
      assign(assigns, :filtered, visible_creators(assigns.creators, assigns.search, assigns.sort))

    ~H"""
    <.page>
      <.page_header
        title="My creators"
        count={length(@creators)}
        subtitle="Creator profiles with their Qlink pages and content catalogs."
      >
        <:actions>
          <.link patch={~p"/creators/new"} class="btn btn-primary btn-sm">
            <.icon name="hero-plus" class="size-4" /> New creator
          </.link>
        </:actions>
      </.page_header>

      <%= if @creators == [] do %>
        <.panel>
          <.empty_state icon="hero-user-group" title="No creators yet">
            Create your first creator profile to get started.
            <:action>
              <.link patch={~p"/creators/new"} class="btn btn-primary btn-sm">
                <.icon name="hero-plus" class="size-4" /> New creator
              </.link>
            </:action>
          </.empty_state>
        </.panel>
      <% else %>
        <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
          <form phx-change="search" phx-submit="search" class="w-full sm:max-w-sm">
            <label class="input w-full">
              <.icon name="hero-magnifying-glass" class="size-4 text-base-content/50" />
              <input
                type="search"
                name="q"
                value={@search}
                placeholder="Search creators"
                phx-debounce="200"
                autocomplete="off"
                class="grow"
              />
            </label>
          </form>
          <div class="flex items-center gap-2">
            <div class="join">
              <button
                type="button"
                phx-click="sort"
                phx-value-sort="az"
                class={["join-item btn btn-sm", @sort == :az && "btn-active"]}
              >
                A-Z
              </button>
              <button
                type="button"
                phx-click="sort"
                phx-value-sort="za"
                class={["join-item btn btn-sm", @sort == :za && "btn-active"]}
              >
                Z-A
              </button>
            </div>
            <div class="join">
              <button
                type="button"
                phx-click="set_view"
                phx-value-view="grid"
                class={["join-item btn btn-sm btn-square", @view == :grid && "btn-active"]}
                title="Grid"
                aria-label="Grid view"
              >
                <.icon name="hero-squares-2x2" class="size-4" />
              </button>
              <button
                type="button"
                phx-click="set_view"
                phx-value-view="list"
                class={["join-item btn btn-sm btn-square", @view == :list && "btn-active"]}
                title="List"
                aria-label="List view"
              >
                <.icon name="hero-bars-3" class="size-4" />
              </button>
            </div>
          </div>
        </div>

        <%= cond do %>
          <% @filtered == [] -> %>
            <.panel>
              <.empty_state icon="hero-magnifying-glass" title={"No creators match \"#{@search}\""}>
                <:action>
                  <button
                    type="button"
                    phx-click="search"
                    phx-value-q=""
                    class="btn btn-sm btn-ghost"
                  >
                    Clear search
                  </button>
                </:action>
              </.empty_state>
            </.panel>
          <% @view == :list -> %>
            <.panel flush>
              <.data_table id="creators-table" rows={@filtered} row_id={&"creator-#{&1.id}"}>
                <:col :let={creator} label="Creator">
                  <div class="flex items-center gap-3">
                    <.creator_avatar creator={creator} size_class="size-9 text-sm" />
                    <div class="min-w-0">
                      <.link
                        navigate={~p"/creators/#{creator.id}"}
                        class="font-semibold hover:underline"
                      >
                        {creator.name}
                      </.link>
                      <p class="line-clamp-1 text-xs text-base-content/50">
                        #{creator.id}{creator.bio not in [nil, ""] && " · #{creator.bio}"}
                      </p>
                    </div>
                  </div>
                </:col>
                <:col :let={creator} label="Qlink pages" class="text-right">
                  {length(creator.qlink_pages)}
                </:col>
                <:col :let={creator} label="Catalogs" class="text-right">
                  {length(creator.catalogs)}
                </:col>
                <:action :let={creator}>
                  <.link navigate={~p"/creators/#{creator.id}"} class="btn btn-sm">Manage</.link>
                </:action>
                <:action :let={creator}>
                  <.delete_creator_button creator={creator} />
                </:action>
              </.data_table>
            </.panel>
          <% true -> %>
            <div class="grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3">
              <.panel
                :for={creator <- @filtered}
                id={"creator-card-#{creator.id}"}
                class="flex flex-col [&>div]:grow"
              >
                <div class="flex items-center gap-4">
                  <.creator_avatar creator={creator} size_class="size-14 text-xl" />
                  <div class="min-w-0">
                    <.link
                      navigate={~p"/creators/#{creator.id}"}
                      class="block truncate font-semibold hover:underline"
                    >
                      {creator.name}
                    </.link>
                    <p class="text-xs text-base-content/50">#{creator.id}</p>
                  </div>
                </div>
                <p
                  :if={creator.bio not in [nil, ""]}
                  class="line-clamp-4 w-full whitespace-pre-line text-sm text-base-content/60 [overflow-wrap:anywhere]"
                >
                  {creator.bio}
                </p>
                <div class="grid grid-cols-2 gap-3">
                  <.stat_tile label="Qlink pages" icon="hero-link">
                    {length(creator.qlink_pages)}
                  </.stat_tile>
                  <.stat_tile label="Catalogs" icon="hero-rectangle-stack">
                    {length(creator.catalogs)}
                  </.stat_tile>
                </div>
                <:footer>
                  <.delete_creator_button creator={creator} />
                  <.link navigate={~p"/creators/#{creator.id}"} class="btn btn-sm">Manage</.link>
                </:footer>
              </.panel>
            </div>
        <% end %>
      <% end %>
    </.page>
    """
  end

  attr :form, :any, required: true
  attr :uploads, :map, required: true
  attr :editing_creator, :any, default: nil

  defp creator_form(assigns) do
    ~H"""
    <.form
      for={@form}
      id="creator-form"
      phx-change="validate"
      phx-submit="save"
      multipart
      autocomplete="off"
    >
      <.panel>
        <.input
          field={@form[:name]}
          type="text"
          label="Creator name"
          placeholder="Enter creator name"
          autocomplete="off"
          required
        />
        <.input
          field={@form[:bio]}
          type="textarea"
          label="Bio"
          placeholder="Enter creator bio"
          autocomplete="off"
        />
        <.image_upload_field
          upload={@uploads.image}
          label="Creator image"
          current_image={if @editing_creator, do: @editing_creator.image}
          current_image_url={
            if @editing_creator && @editing_creator.image,
              do: CreatorImage.url({@editing_creator.image, @editing_creator}, :original)
          }
        />
        <:footer>
          <button type="button" phx-click="cancel" class="btn btn-ghost">Cancel</button>
          <.button variant="primary" phx-disable-with="Saving...">Save creator</.button>
        </:footer>
      </.panel>
    </.form>
    """
  end

  attr :creator, :map, required: true

  defp delete_creator_button(assigns) do
    ~H"""
    <.icon_button
      icon="hero-trash"
      label="Delete"
      tone="error"
      phx-click="delete"
      phx-value-id={@creator.id}
      data-confirm={"Delete #{@creator.name}? This cannot be undone."}
    />
    """
  end

  @doc false
  def visible_creators(creators, search, sort) when is_list(creators) do
    creators
    |> filter_by_name(search)
    |> sort_by_name(sort)
  end

  defp filter_by_name(creators, search) do
    case String.trim(search || "") do
      "" ->
        creators

      query ->
        q = String.downcase(query)

        Enum.filter(creators, fn creator ->
          String.contains?(String.downcase(creator.name || ""), q)
        end)
    end
  end

  defp sort_by_name(creators, :za) do
    Enum.sort_by(creators, &String.downcase(&1.name || ""), :desc)
  end

  defp sort_by_name(creators, _) do
    Enum.sort_by(creators, &String.downcase(&1.name || ""), :asc)
  end

  defp parse_sort("za"), do: :za
  defp parse_sort(_), do: :az

  defp parse_view("list"), do: :list
  defp parse_view(_), do: :grid

  attr :creator, :map, required: true
  attr :size_class, :string, default: "size-14 text-xl"

  defp creator_avatar(assigns) do
    ~H"""
    <%= if @creator.image do %>
      <img
        src={CreatorImage.url({@creator.image, @creator}, :original)}
        alt={@creator.name}
        class={["shrink-0 rounded-full object-cover", @size_class]}
      />
    <% else %>
      <span class={[
        "flex shrink-0 items-center justify-center rounded-full bg-base-200 font-semibold text-base-content/70",
        @size_class
      ]}>
        {String.first(@creator.name || "?")}
      </span>
    <% end %>
    """
  end
end
