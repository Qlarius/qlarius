defmodule QlariusWeb.CreatorDashboard.Show do
  use QlariusWeb, :live_view

  import QlariusWeb.Components.MarketerUI

  alias Qlarius.Creators
  alias Qlarius.Tiqit.ContentAudiences
  alias QlariusWeb.AudienceCard
  alias Qlarius.Qlink
  alias QlariusWeb.Uploaders.CreatorImage
  alias QlariusWeb.LiveView.ImageUpload
  alias QlariusWeb.Helpers.ImageHelpers
  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    creator = Creators.get_creator!(id)

    {:ok,
     socket
     |> assign(:creator, creator)
     |> assign(:page_title, creator.name)
     |> assign(:audience, ContentAudiences.effective_audience(creator))
     |> assign(:show_edit_form, false)
     |> assign(:form, nil)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :show, _params) do
    socket
    |> assign(:show_edit_form, false)
    |> assign(:form, nil)
  end

  defp apply_action(socket, :edit, _params) do
    changeset = Creators.change_creator(socket.assigns.creator)

    socket
    |> assign(:show_edit_form, true)
    |> assign(:form, to_form(changeset))
    |> ImageUpload.setup_upload(:image, auto_upload: true)
  end

  defp apply_action(socket, _action, _params), do: socket

  @impl true
  def handle_event("validate", %{"creator" => creator_params}, socket) do
    form =
      socket.assigns.creator
      |> Creators.change_creator(creator_params)
      |> to_form(action: :validate)

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("save", %{"creator" => creator_params}, socket) do
    creator_params_with_image =
      ImageUpload.consume_and_add_to_params(
        socket,
        :image,
        socket.assigns.creator,
        CreatorImage,
        creator_params
      )

    case Creators.update_creator(socket.assigns.creator, creator_params_with_image) do
      {:ok, creator} ->
        {:noreply,
         socket
         |> assign(:creator, creator)
         |> assign(:show_edit_form, false)
         |> assign(:form, nil)
         |> put_flash(:info, "Creator updated successfully")
         |> push_patch(to: ~p"/creators/#{creator.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
    end
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_edit_form, false)
     |> assign(:form, nil)
     |> push_patch(to: ~p"/creators/#{socket.assigns.creator.id}")}
  end

  def handle_event("delete_creator", _params, socket) do
    {:ok, _} = Creators.delete_creator(socket.assigns.creator)

    {:noreply,
     socket
     |> put_flash(:info, "Creator deleted successfully")
     |> push_navigate(to: ~p"/creators")}
  end

  def handle_event("delete_image", _params, socket) do
    case Creators.delete_creator_image(socket.assigns.creator) do
      {:ok, creator} ->
        {:noreply,
         socket
         |> assign(:creator, creator)
         |> put_flash(:info, "Image deleted successfully")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete image")}
    end
  end

  def handle_event("delete_qlink_page", %{"id" => id}, socket) do
    page = Qlink.get_page!(id)
    {:ok, _} = Qlink.delete_page(page)

    creator = Creators.get_creator!(socket.assigns.creator.id)

    {:noreply,
     socket
     |> assign(:creator, creator)
     |> put_flash(:info, "Qlink page deleted successfully")}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :image, ref)}
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
            <.page class="max-w-5xl">
              <%= if @show_edit_form do %>
                <.page_header
                  title="Edit creator"
                  subtitle={@creator.name}
                  back_to={~p"/creators/#{@creator.id}"}
                  back_label={@creator.name}
                />

                <.form
                  for={@form}
                  id="creator-edit-form"
                  phx-change="validate"
                  phx-submit="save"
                  multipart
                  autocomplete="off"
                  class="mb-8 max-w-3xl"
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
                      current_image={@creator.image}
                      current_image_url={CreatorImage.url({@creator.image, @creator}, :original)}
                      on_delete="delete_image"
                    />
                    <:footer>
                      <button type="button" phx-click="cancel_edit" class="btn btn-ghost">
                        Cancel
                      </button>
                      <.button variant="primary" phx-disable-with="Saving...">Save creator</.button>
                    </:footer>
                  </.panel>
                </.form>
              <% else %>
                <.page_header
                  title={@creator.name}
                  subtitle={"Creator ##{@creator.id}"}
                  back_to={~p"/creators"}
                  back_label="Creators"
                >
                  <:actions>
                    <.link
                      navigate={~p"/creators/#{@creator.id}/audiences"}
                      class="btn btn-sm btn-ghost"
                    >
                      Audiences
                    </.link>
                    <.link
                      navigate={~p"/creators/#{@creator.id}/trait-groups"}
                      class="btn btn-sm btn-ghost"
                    >
                      Trait groups
                    </.link>
                    <.link
                      navigate={~p"/creators/#{@creator.id}/insights"}
                      class="btn btn-sm btn-ghost"
                    >
                      Insights
                    </.link>
                    <.link
                      patch={~p"/creators/#{@creator.id}/edit"}
                      class="btn btn-sm btn-ghost"
                    >
                      <.icon name="hero-pencil-square" class="size-4" /> Edit profile
                    </.link>
                    <button
                      type="button"
                      phx-click="delete_creator"
                      data-confirm="Are you sure you want to delete this creator? This action cannot be undone."
                      class="btn btn-sm btn-ghost text-error"
                    >
                      <.icon name="hero-trash" class="size-4" /> Delete
                    </button>
                  </:actions>
                </.page_header>

                <.panel id="creator-profile" class="mb-8">
                  <div class="flex flex-wrap items-start gap-6">
                    <%= if @creator.image do %>
                      <img
                        src={CreatorImage.url({@creator.image, @creator}, :original)}
                        alt={@creator.name}
                        class="size-20 shrink-0 rounded-full object-cover"
                      />
                    <% else %>
                      <.initial_tile name={@creator.name} class="size-20 rounded-full text-2xl" />
                    <% end %>
                    <div class="min-w-0 flex-1 space-y-4">
                      <p
                        :if={@creator.bio not in [nil, ""]}
                        class="whitespace-pre-line text-sm text-base-content/70 [overflow-wrap:anywhere]"
                      >
                        {@creator.bio}
                      </p>
                      <p :if={@creator.bio in [nil, ""]} class="text-sm text-base-content/50">
                        No bio yet.
                      </p>
                      <div class="grid max-w-md grid-cols-2 gap-3">
                        <.stat_tile label="Qlink pages" icon="hero-link">
                          {length(@creator.qlink_pages)}
                        </.stat_tile>
                        <.stat_tile label="Catalogs" icon="hero-rectangle-stack">
                          {length(@creator.catalogs)}
                        </.stat_tile>
                      </div>
                    </div>
                  </div>
                </.panel>
              <% end %>

              <AudienceCard.card
                creator={@creator}
                content={@creator}
                effective={@audience}
                level={:creator}
                class="mb-8"
              />

              <div class="grid items-start gap-8 lg:grid-cols-2">
                <.panel
                  id="creator-qlink-pages"
                  flush
                  title="Qlink pages"
                  description="Link-in-bio pages for this creator."
                >
                  <:actions>
                    <.link
                      navigate={~p"/creators/#{@creator.id}/qlink_pages/new"}
                      class="btn btn-primary btn-sm"
                    >
                      <.icon name="hero-plus" class="size-4" /> New page
                    </.link>
                  </:actions>

                  <.empty_state
                    :if={@creator.qlink_pages == []}
                    icon="hero-link"
                    title="No Qlink pages yet"
                  >
                    Create a page to share this creator's links.
                    <:action>
                      <.link
                        navigate={~p"/creators/#{@creator.id}/qlink_pages/new"}
                        class="btn btn-sm btn-primary"
                      >
                        Create first page
                      </.link>
                    </:action>
                  </.empty_state>

                  <ul :if={@creator.qlink_pages != []} class="divide-y divide-base-300">
                    <li
                      :for={page <- @creator.qlink_pages}
                      id={"qlink-page-#{page.id}"}
                      class="flex items-center gap-4 px-6 py-4 transition-colors hover:bg-base-200/40"
                    >
                      <%= if Qlink.get_display_image(page) != "/images/default_avatar.png" do %>
                        <img
                          src={Qlink.get_display_image(page)}
                          alt={page.title}
                          class="size-12 shrink-0 rounded-full object-cover"
                        />
                      <% else %>
                        <.initial_tile name={page.title} class="size-12 rounded-full" />
                      <% end %>
                      <div class="min-w-0 flex-1">
                        <div class="flex flex-wrap items-center gap-2">
                          <.link
                            navigate={~p"/creators/qlink_pages/#{page.id}/edit"}
                            class="truncate font-semibold hover:underline"
                          >
                            {page.title}
                          </.link>
                          <.status_badge tone={if page.is_published, do: "success", else: "neutral"}>
                            {if page.is_published, do: "Published", else: "Draft"}
                          </.status_badge>
                        </div>
                        <p class="truncate text-xs text-base-content/50">
                          @{page.alias} · {page.view_count} views · {page.total_clicks} clicks
                        </p>
                      </div>
                      <div class="flex shrink-0 items-center gap-1">
                        <a
                          href={Qlarius.Qlink.Urls.interact_url(page.alias)}
                          target="_blank"
                          rel="noopener noreferrer"
                          class="btn btn-ghost btn-sm btn-square"
                          title={if page.is_published, do: "View", else: "Preview"}
                          aria-label={if page.is_published, do: "View", else: "Preview"}
                        >
                          <.icon name="hero-eye" class="size-4" />
                        </a>
                        <.icon_button
                          icon="hero-pencil-square"
                          label="Edit"
                          navigate={~p"/creators/qlink_pages/#{page.id}/edit"}
                        />
                        <.icon_button
                          icon="hero-trash"
                          label="Delete"
                          tone="error"
                          phx-click="delete_qlink_page"
                          phx-value-id={page.id}
                          data-confirm="Are you sure?"
                        />
                      </div>
                    </li>
                  </ul>
                </.panel>

                <.panel
                  id="creator-catalogs"
                  flush
                  title="Tiqit catalogs"
                  description="Content catalogs sold through Tiqit."
                >
                  <:actions>
                    <.link
                      :if={@current_scope.true_user.role == "admin" and @creator.catalogs != []}
                      navigate={~p"/creators/#{@creator.id}/rss_import"}
                      class="btn btn-ghost btn-sm"
                    >
                      <.icon name="hero-rss" class="size-4" /> Import from RSS
                    </.link>
                    <.link
                      navigate={~p"/creators/#{@creator.id}/catalogs/new"}
                      class="btn btn-primary btn-sm"
                    >
                      <.icon name="hero-plus" class="size-4" /> New catalog
                    </.link>
                  </:actions>

                  <.empty_state
                    :if={@creator.catalogs == []}
                    icon="hero-rectangle-stack"
                    title="No catalogs yet"
                  >
                    Create a catalog to start publishing content.
                    <:action>
                      <.link
                        navigate={~p"/creators/#{@creator.id}/catalogs/new"}
                        class="btn btn-sm btn-primary"
                      >
                        Create first catalog
                      </.link>
                    </:action>
                  </.empty_state>

                  <ul :if={@creator.catalogs != []} class="divide-y divide-base-300">
                    <li
                      :for={catalog <- @creator.catalogs}
                      id={"catalog-#{catalog.id}"}
                      class="flex items-center gap-4 px-6 py-4 transition-colors hover:bg-base-200/40"
                    >
                      <%= if ImageHelpers.catalog_image_url(catalog) != ImageHelpers.placeholder_image_url() do %>
                        <img
                          src={ImageHelpers.catalog_image_url(catalog)}
                          alt={catalog.name}
                          class="size-12 shrink-0 rounded-lg object-cover"
                        />
                      <% else %>
                        <.initial_tile name={catalog.name} class="size-12 rounded-lg" />
                      <% end %>
                      <div class="min-w-0 flex-1">
                        <.link
                          navigate={~p"/creators/catalogs/#{catalog.id}"}
                          class="block truncate font-semibold hover:underline"
                        >
                          {catalog.name}
                        </.link>
                        <p class="text-xs text-base-content/50">
                          {catalog.type |> to_string() |> String.capitalize()}
                        </p>
                      </div>
                      <.link navigate={~p"/creators/catalogs/#{catalog.id}"} class="btn btn-sm">
                        Manage
                      </.link>
                    </li>
                  </ul>
                </.panel>
              </div>
            </.page>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  attr :name, :string, default: nil
  attr :class, :any, default: nil

  defp initial_tile(assigns) do
    ~H"""
    <span class={[
      "flex shrink-0 items-center justify-center bg-base-200 font-semibold text-base-content/70",
      @class
    ]}>
      {String.first(@name || "?")}
    </span>
    """
  end
end
