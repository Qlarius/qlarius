defmodule QlariusWeb.Creators.CatalogLive.Show do
  use QlariusWeb, :live_view

  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}
  alias Qlarius.Tiqit.Arcade.Creators
  alias Qlarius.Tiqit.Arcade.Arcade
  alias QlariusWeb.TiqitClassHTML
  alias QlariusWeb.Helpers.ImageHelpers
  import QlariusWeb.CoreComponents

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    catalog = Creators.get_catalog!(id)
    creator = catalog.creator

    {:ok,
     socket
     |> assign(:catalog, catalog)
     |> assign(:creator, creator)
     |> assign(:page_title, catalog.name)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    catalog = socket.assigns.catalog
    creator = catalog.creator
    {:ok, _catalog} = Creators.delete_catalog(catalog)

    {:noreply,
     socket
     |> put_flash(:info, "Catalog deleted successfully")
     |> push_navigate(to: ~p"/creators/#{creator.id}")}
  end

  def handle_event("add_default_tiqit_classes", _params, socket) do
    Arcade.write_default_catalog_tiqit_classes(socket.assigns.catalog)

    catalog = Creators.get_catalog!(socket.assigns.catalog.id)

    {:noreply,
     socket
     |> assign(:catalog, catalog)
     |> put_flash(:info, "Default Tiqit classes added successfully")}
  end

  def handle_event("delete_tiqit_class", %{"id" => id}, socket) do
    {:ok, _} = Creators.delete_tiqit_class(id)

    catalog = Creators.get_catalog!(socket.assigns.catalog.id)

    {:noreply,
     socket
     |> assign(:catalog, catalog)
     |> put_flash(:info, "Tiqit class deleted successfully")}
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
            <div class="p-6">
              <div class="space-y-6">
                <!-- Breadcrumbs -->
                <.breadcrumbs crumbs={[
                  {@creator.name, ~p"/creators/#{@creator.id}"}
                ]} current={"#{String.capitalize(to_string(@catalog.type))}: #{@catalog.name}"} />

                <!-- Header Section -->
                <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
                  <div>
                    <h1 class="text-2xl font-bold text-base-content">{@catalog.name}</h1>
                    <p class="text-base-content/60 mt-1">
                      {@catalog.type |> to_string() |> String.capitalize()} • {@creator.name}
                    </p>
                  </div>
                  <div class="flex gap-2">
                    <.link
                      navigate={~p"/creators/catalogs/#{@catalog.id}/edit"}
                      class="btn btn-outline"
                    >
                      <.icon name="hero-pencil" class="w-4 h-4 mr-2" /> Edit
                    </.link>
                    <button
                      phx-click="delete"
                      data-confirm="Are you sure you want to delete this catalog?"
                      class="btn btn-outline btn-error"
                    >
                      <.icon name="hero-trash" class="w-4 h-4 mr-2" /> Delete
                    </button>
                  </div>
                </div>

    <!-- Overview Section -->
                <div class="card bg-base-100 shadow-lg">
                  <div class="card-body">
                    <div class="grid grid-cols-1 md:grid-cols-3 gap-6 items-start">
                      <div>
                        <h3 class="text-sm font-medium text-base-content mb-2">Catalog Image</h3>
                        <%= if ImageHelpers.catalog_image_url(@catalog) != ImageHelpers.placeholder_image_url() do %>
                          <img
                            src={ImageHelpers.catalog_image_url(@catalog)}
                            class="w-50 h-50 object-cover rounded border border-base-300"
                            alt={"#{@catalog.name} image"}
                          />
                        <% else %>
                          <div class="w-48 h-32 rounded bg-base-200 flex items-center justify-center text-base-content/40">
                            No image
                          </div>
                        <% end %>
                      </div>

                      <div class="md:col-span-1">
                        <h3 class="text-sm font-medium text-base-content mb-2">Type Hierarchy</h3>
                        <div class="flex flex-col flex-wrap gap-2">
                          <span class="badge badge-primary p-4">
                            <.icon name="hero-rectangle-group" class="w-4 h-4 mr-1" />
                            Catalog: {@catalog.type |> to_string() |> String.capitalize()}
                          </span>
                          <span class="badge badge-secondary p-4">
                            <.icon name="hero-queue-list" class="w-4 h-4 mr-1" />
                            Group: {@catalog.group_type |> to_string() |> String.capitalize()}
                          </span>
                          <span class="badge badge-info p-4">
                            <.icon name="hero-document-text" class="w-4 h-4 mr-1" />
                            Piece: {@catalog.piece_type |> to_string() |> String.capitalize()}
                          </span>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>

    <!-- URL Section -->
                <%= if @catalog.url do %>
                  <div class="card bg-base-100 shadow-lg">
                    <div class="card-body">
                      <div class="flex items-center gap-3">
                        <.icon name="hero-link" class="w-5 h-5 text-base-content/60" />
                        <div class="flex-1">
                          <h3 class="text-sm font-medium text-base-content mb-1">Catalog URL</h3>
                          <.link
                            href={@catalog.url}
                            target="_blank"
                            class="text-primary hover:text-primary-focus break-all"
                          >
                            {@catalog.url}
                          </.link>
                        </div>
                        <div class="flex gap-2">
                          <.link href={@catalog.url} target="_blank" class="btn btn-ghost btn-sm">
                            <.icon name="hero-arrow-top-right-on-square" class="w-4 h-4" />
                          </.link>
                        </div>
                      </div>
                    </div>
                  </div>
                <% end %>

    <!-- Tiqit Classes Section -->
                <div class="space-y-4">
                  <div class="flex items-center justify-between">
                    <h2 class="text-xl font-semibold text-base-content flex items-center">
                      <.icon name="hero-tag" class="w-6 h-6 mr-3 text-primary" /> {@catalog.type
                      |> to_string()
                      |> String.capitalize()}-Level Tiqit Classes
                    </h2>
                  </div>

                  <%= if Enum.any?(@catalog.tiqit_classes) do %>
                    <div class="card bg-base-100 shadow-lg">
                      <div class="card-body p-0">
                        <TiqitClassHTML.tiqit_classes_table record={@catalog} on_delete="delete_tiqit_class" />
                      </div>
                    </div>
                  <% else %>
                    <!-- Empty State for Tiqit Classes -->
                    <div class="hero min-h-32 bg-base-200 rounded-lg">
                      <div class="hero-content text-center">
                        <div class="max-w-md">
                          <div class="avatar placeholder mb-4">
                            <div class="bg-neutral-focus text-neutral-content rounded-full w-12 h-12">
                              <span class="text-lg">🏷️</span>
                            </div>
                          </div>
                          <h3 class="text-lg font-bold text-base-content mb-2">
                            No Tiqit Classes Yet
                          </h3>
                          <p class="text-base-content/60 mb-4">
                            Set up pricing tiers for this catalog.
                          </p>
                          <div class="flex flex-col sm:flex-row gap-3">
                            <button phx-click="add_default_tiqit_classes" class="btn btn-primary">
                              <.icon name="hero-plus" class="w-4 h-4 mr-2" /> Add Tiqit Class Defaults
                            </button>
                            <.link
                              navigate={~p"/creators/catalogs/#{@catalog.id}/edit"}
                              class="btn btn-outline"
                            >
                              <.icon name="hero-pencil" class="w-4 h-4 mr-2" /> Edit Manually
                            </.link>
                          </div>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>

    <!-- Content Groups Section -->
                <div class="space-y-4">
                  <div class="flex items-center justify-between">
                    <h2 class="text-xl font-semibold text-base-content flex items-center">
                      <.icon name="hero-folder" class="w-6 h-6 mr-3 text-secondary" />
                      {@catalog.group_type |> to_string() |> String.capitalize()}
                    </h2>
                    <div class="flex gap-2">
                      <.link
                        navigate={~p"/creators/catalogs/#{@catalog.id}/content_groups/new"}
                        class="btn btn-primary"
                      >
                        <.icon name="hero-plus" class="w-4 h-4 mr-2" />
                        New {@catalog.group_type |> to_string() |> String.capitalize()}
                      </.link>
                    </div>
                  </div>

                  <%= if Enum.any?(@catalog.content_groups) do %>
                    <div class="card bg-base-100 shadow-lg">
                      <div class="card-body p-0">
                        <div class="overflow-x-auto">
                          <table class="table table-zebra w-full">
                            <thead class="bg-base-200">
                              <tr>
                                <th class="font-semibold text-base-content">Name</th>
                                <th class="font-semibold text-base-content">
                                  {@catalog.piece_type |> to_string() |> String.capitalize()} count
                                </th>
                                <th class="font-semibold text-base-content text-right">Actions</th>
                              </tr>
                            </thead>
                            <tbody class="divide-y divide-base-300">
                              <%= for group <- @catalog.content_groups do %>
                                <tr
                                  class="hover:bg-base-200 cursor-pointer transition-colors"
                                  phx-click={JS.navigate(~p"/creators/content_groups/#{group.id}")}
                                >
                                  <td class="font-medium text-base-content">
                                    <div class="flex items-center gap-3">
                                      <div class="w-10 h-10">
                                        <%= if ImageHelpers.group_image_url(group) != ImageHelpers.placeholder_image_url() do %>
                                          <img
                                            src={ImageHelpers.group_image_url(group)}
                                            class="w-10 h-10 object-cover rounded"
                                            alt={"#{group.title} image"}
                                          />
                                        <% else %>
                                          <div class="avatar placeholder">
                                            <div class="bg-neutral-focus text-neutral-content rounded w-10 h-10">
                                              <span class="text-sm">{String.at(group.title, 0)}</span>
                                            </div>
                                          </div>
                                        <% end %>
                                      </div>
                                      <div class="font-medium">{group.title}</div>
                                    </div>
                                  </td>
                                  <td class="text-base-content">
                                    <span class="badge badge-secondary badge-sm p-2">
                                      {length(group.content_pieces)}
                                    </span>
                                  </td>
                                  <td class="text-right">
                                    <div class="flex gap-2 justify-end">
                                      <.link
                                        navigate={~p"/creators/content_groups/#{group.id}/edit"}
                                        class="btn btn-ghost btn-sm"
                                      >
                                        <.icon name="hero-pencil" class="w-4 h-4" />
                                      </.link>
                                      <.link
                                        navigate={~p"/creators/content_groups/#{group.id}"}
                                        class="btn btn-ghost btn-sm"
                                      >
                                        <.icon name="hero-eye" class="w-4 h-4" />
                                      </.link>
                                    </div>
                                  </td>
                                </tr>
                              <% end %>
                            </tbody>
                          </table>
                        </div>
                      </div>
                    </div>
                  <% else %>
                    <!-- Empty State for Content Groups -->
                    <div class="hero min-h-48 bg-base-200 rounded-lg">
                      <div class="hero-content text-center">
                        <div class="max-w-md">
                          <div class="avatar placeholder mb-4">
                            <div class="bg-neutral-focus text-neutral-content rounded-full w-16 h-16">
                              <span class="text-xl">📁</span>
                            </div>
                          </div>
                          <h3 class="text-lg font-bold text-base-content mb-2">
                            No Content Groups Yet
                          </h3>
                          <p class="text-base-content/60 mb-6">
                            Start building your catalog by adding your first {@catalog.group_type}.
                          </p>
                          <.link
                            navigate={~p"/creators/catalogs/#{@catalog.id}/content_groups/new"}
                            class="btn btn-primary btn-lg"
                          >
                            <.icon name="hero-plus" class="w-5 h-5 mr-2" /> Add First Content Group
                          </.link>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end
end
