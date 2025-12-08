defmodule QlariusWeb.CreatorDashboard.Show do
  use QlariusWeb, :live_view

  alias Qlarius.Creators
  alias Qlarius.Qlink
  alias QlariusWeb.Uploaders.CreatorImage
  alias QlariusWeb.LiveView.ImageUpload
  alias QlariusWeb.Helpers.ImageHelpers

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    creator = Creators.get_creator!(id)

    {:ok,
     socket
     |> assign(:creator, creator)
     |> assign(:page_title, creator.name)
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
      <div class="container mx-auto px-4 py-8">
        <div class="mb-6">
          <.link navigate={~p"/creators"} class="btn btn-ghost btn-sm">
            ← Back to Creators
          </.link>
        </div>

        <%= if @show_edit_form do %>
          <div class="card bg-base-100 shadow-lg max-w-2xl mb-8">
            <div class="card-body">
              <h2 class="text-2xl font-bold mb-4">Edit Creator</h2>

              <.form
                for={@form}
                id="creator-edit-form"
                phx-change="validate"
                phx-submit="save"
                multipart
                autocomplete="off"
                class="space-y-6"
              >
                <div class="space-y-4">
                  <.input
                    field={@form[:name]}
                    type="text"
                    label="Creator Name"
                    class="input input-bordered w-full"
                    placeholder="Enter creator name"
                    autocomplete="off"
                    required
                  />

                  <.input
                    field={@form[:bio]}
                    type="textarea"
                    label="Bio"
                    class="textarea textarea-bordered w-full"
                    placeholder="Enter creator bio"
                    autocomplete="off"
                  />
                </div>

                <.image_upload_field
                  upload={@uploads.image}
                  label="Creator Image"
                  current_image={@creator.image}
                  current_image_url={CreatorImage.url({@creator.image, @creator}, :original)}
                  on_delete="delete_image"
                />

                <div class="flex flex-col sm:flex-row gap-3 pt-4 border-t border-base-300">
                  <.button class="btn btn-primary btn-wide sm:btn-auto">
                    <.icon name="hero-check" class="w-4 h-4 mr-2" /> Save Creator
                  </.button>

                  <button type="button" phx-click="cancel_edit" class="btn btn-ghost">
                    <.icon name="hero-arrow-left" class="w-4 h-4 mr-2" /> Cancel
                  </button>
                </div>
              </.form>
            </div>
          </div>
        <% else %>
          <div class="card bg-base-100 shadow-xl mb-8">
            <div class="card-body">
              <div class="flex items-center gap-6">
                <%= if @creator.image do %>
                  <img
                    src={CreatorImage.url({@creator.image, @creator}, :original)}
                    alt={@creator.name}
                    class="rounded-full w-24 h-24 object-cover"
                  />
                <% else %>
                  <div class="avatar placeholder">
                    <div class="bg-neutral text-neutral-content rounded-full w-24">
                      <span class="text-3xl">{String.first(@creator.name)}</span>
                    </div>
                  </div>
                <% end %>

                <div class="flex-1">
                  <h1 class="text-3xl font-bold">{@creator.name}</h1>
                  <%= if @creator.bio do %>
                    <p class="text-base-content/70 mt-2">{@creator.bio}</p>
                  <% end %>
                </div>

                <div class="card-actions gap-2">
                  <.link patch={~p"/creators/#{@creator.id}/edit"} class="btn btn-primary">
                    Edit Profile
                  </.link>
                  <button
                    phx-click="delete_creator"
                    data-confirm="Are you sure you want to delete this creator? This action cannot be undone."
                    class="btn btn-error"
                  >
                    <.icon name="hero-trash" class="w-4 h-4 mr-2" /> Delete
                  </button>
                </div>
              </div>
            </div>
          </div>
        <% end %>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
          <!-- Qlink Pages Section -->
          <div>
            <div class="flex justify-between items-center mb-4">
              <h2 class="text-2xl font-bold">Qlink Pages</h2>
              <.link
                navigate={~p"/creators/#{@creator.id}/qlink_pages/new"}
                class="btn btn-primary btn-sm"
              >
                New Page
              </.link>
            </div>

            <%= if @creator.qlink_pages == [] do %>
              <div class="card bg-base-200 shadow">
                <div class="card-body">
                  <p class="text-center">No Qlink pages yet.</p>
                  <div class="card-actions justify-center">
                    <.link
                      navigate={~p"/creators/#{@creator.id}/qlink_pages/new"}
                      class="btn btn-sm btn-primary"
                    >
                      Create First Page
                    </.link>
                  </div>
                </div>
              </div>
            <% else %>
              <div class="space-y-4">
                <%= for page <- @creator.qlink_pages do %>
                  <div class="card bg-base-100 shadow">
                    <div class="card-body">
                      <div class="flex items-center gap-4">
                        <div class="flex-shrink-0">
                          <%= if Qlink.get_display_image(page) != "/images/default_avatar.png" do %>
                            <img
                              src={Qlink.get_display_image(page)}
                              alt={page.title}
                              class="w-16 h-16 object-cover rounded-full"
                            />
                          <% else %>
                            <div class="avatar placeholder">
                              <div class="bg-neutral text-neutral-content rounded-full w-16 h-16">
                                <span class="text-xl">{String.first(page.title)}</span>
                              </div>
                            </div>
                          <% end %>
                        </div>
                        <div class="flex-1">
                          <h3 class="card-title">{page.title}</h3>
                          <p class="text-sm text-base-content/70">@{page.alias}</p>

                          <div class="stats stats-horizontal shadow-sm mt-2">
                            <div class="stat py-2 px-4">
                              <div class="stat-title text-xs">Views</div>
                              <div class="stat-value text-lg">{page.view_count}</div>
                            </div>
                            <div class="stat py-2 px-4">
                              <div class="stat-title text-xs">Clicks</div>
                              <div class="stat-value text-lg">{page.total_clicks}</div>
                            </div>
                          </div>
                        </div>
                        <div class="card-actions">
                          <.link
                            navigate={~p"/@#{page.alias}"}
                            class="btn btn-ghost btn-sm"
                            target="_blank"
                          >
                            View
                          </.link>
                          <.link
                            navigate={~p"/creators/qlink_pages/#{page.id}/edit"}
                            class="btn btn-ghost btn-sm"
                          >
                            Edit
                          </.link>
                          <button
                            phx-click="delete_qlink_page"
                            phx-value-id={page.id}
                            data-confirm="Are you sure?"
                            class="btn btn-ghost btn-sm text-error"
                          >
                            Delete
                          </button>
                        </div>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>

          <!-- Tiqit Catalogs Section -->
          <div>
            <div class="flex justify-between items-center mb-4">
              <h2 class="text-2xl font-bold">Tiqit Catalogs</h2>
              <.link
                navigate={~p"/creators/catalogs/#{@creator.id}/content_groups/new"}
                class="btn btn-primary btn-sm"
              >
                New Catalog
              </.link>
            </div>

            <%= if @creator.catalogs == [] do %>
              <div class="card bg-base-200 shadow">
                <div class="card-body">
                  <p class="text-center">No catalogs yet</p>
                  <div class="card-actions justify-center">
                    <.link
                      navigate={~p"/creators/#{@creator.id}/catalogs/new"}
                      class="btn btn-sm btn-primary"
                    >
                      Create First Catalog
                    </.link>
                  </div>
                </div>
              </div>
            <% else %>
              <div class="space-y-4">
                <%= for catalog <- @creator.catalogs do %>
                  <div class="card bg-base-100 shadow">
                    <div class="card-body">
                      <div class="flex items-center gap-4">
                        <div class="flex-shrink-0">
                          <%= if ImageHelpers.catalog_image_url(catalog) != ImageHelpers.placeholder_image_url() do %>
                            <img
                              src={ImageHelpers.catalog_image_url(catalog)}
                              alt={catalog.name}
                              class="w-16 h-16 object-cover rounded-lg"
                            />
                          <% else %>
                            <div class="avatar placeholder">
                              <div class="bg-neutral text-neutral-content rounded-lg w-16 h-16">
                                <span class="text-xl">{String.first(catalog.name)}</span>
                              </div>
                            </div>
                          <% end %>
                        </div>
                        <div class="flex-1">
                          <h3 class="card-title">{catalog.name}</h3>
                          <p class="text-sm text-base-content/70">{catalog.type |> to_string() |> String.capitalize()}</p>
                        </div>
                        <div class="card-actions">
                          <.link
                            navigate={~p"/creators/catalogs/#{catalog.id}"}
                            class="btn btn-ghost btn-sm"
                          >
                            Manage
                          </.link>
                        </div>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end
end
