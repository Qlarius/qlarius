defmodule QlariusWeb.CreatorDashboard.Index do
  use QlariusWeb, :live_view

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
            <div class="container mx-auto px-4 py-8">
              <div class="flex justify-between items-center mb-8">
                <h1 class="text-3xl font-bold">My Creators</h1>
                <%= if not @show_form do %>
                  <.link patch={~p"/creators/new"} class="btn btn-primary">
                    <.icon name="hero-plus" class="w-4 h-4 mr-2" /> New Creator
                  </.link>
                <% end %>
              </div>

              <%= if @show_form do %>
                <div class="card bg-base-100 shadow-lg max-w-2xl mb-8">
                  <div class="card-body">
                    <div class="flex items-center justify-between mb-4">
                      <h2 class="text-2xl font-bold">
                        {if @editing_creator, do: "Edit Creator", else: "New Creator"}
                      </h2>
                      <button phx-click="cancel" class="btn btn-ghost btn-sm">
                        <.icon name="hero-x-mark" class="w-4 h-4" />
                      </button>
                    </div>

                    <.form
                      for={@form}
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
                        current_image={if @editing_creator, do: @editing_creator.image}
                        current_image_url={
                          if @editing_creator && @editing_creator.image,
                            do:
                              CreatorImage.url({@editing_creator.image, @editing_creator}, :original)
                        }
                      />

                      <div class="flex flex-col sm:flex-row gap-3 pt-4 border-t border-base-300">
                        <.button class="btn btn-primary btn-wide sm:btn-auto">
                          <.icon name="hero-check" class="w-4 h-4 mr-2" /> Save Creator
                        </.button>

                        <button type="button" phx-click="cancel" class="btn btn-ghost">
                          <.icon name="hero-arrow-left" class="w-4 h-4 mr-2" /> Cancel
                        </button>
                      </div>
                    </.form>
                  </div>
                </div>
              <% end %>

              <%= if @creators == [] && not @show_form do %>
                <div class="card bg-base-200 shadow-xl">
                  <div class="card-body items-center text-center">
                    <h2 class="card-title">No creators yet</h2>
                    <p>Create your first creator profile to get started.</p>
                    <.link patch={~p"/creators/new"} class="btn btn-primary mt-4">
                      <.icon name="hero-plus" class="w-4 h-4 mr-2" /> Create First Creator
                    </.link>
                  </div>
                </div>
              <% else %>
                <%= if @creators != [] do %>
                  <div class="flex items-center gap-2 mb-6 min-w-0">
                    <form phx-change="search" class="relative min-w-0 flex-1">
                      <.icon
                        name="hero-magnifying-glass"
                        class="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-base-content/40 pointer-events-none"
                      />
                      <input
                        type="text"
                        name="q"
                        value={@search}
                        placeholder="Search by name…"
                        class="input input-bordered input-sm w-full pl-9"
                        phx-debounce="200"
                      />
                    </form>
                    <div class="join shrink-0">
                      <button
                        type="button"
                        phx-click="sort"
                        phx-value-sort="az"
                        class={"join-item btn btn-sm #{if @sort == :az, do: "btn-active"}"}
                      >
                        A–Z
                      </button>
                      <button
                        type="button"
                        phx-click="sort"
                        phx-value-sort="za"
                        class={"join-item btn btn-sm #{if @sort == :za, do: "btn-active"}"}
                      >
                        Z–A
                      </button>
                    </div>
                    <div class="join shrink-0">
                      <button
                        type="button"
                        phx-click="set_view"
                        phx-value-view="grid"
                        class={"join-item btn btn-sm #{if @view == :grid, do: "btn-active"}"}
                        title="Grid"
                      >
                        <.icon name="hero-squares-2x2" class="w-4 h-4" />
                      </button>
                      <button
                        type="button"
                        phx-click="set_view"
                        phx-value-view="list"
                        class={"join-item btn btn-sm #{if @view == :list, do: "btn-active"}"}
                        title="List"
                      >
                        <.icon name="hero-bars-3" class="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                <% end %>

                <% filtered = visible_creators(@creators, @search, @sort) %>

                <%= if filtered == [] do %>
                  <div class="card bg-base-200">
                    <div class="card-body items-center text-center py-10">
                      <p class="text-base-content/70">
                        No creators match "{@search}".
                      </p>
                    </div>
                  </div>
                <% else %>
                  <%= if @view == :list do %>
                    <div class="overflow-x-auto border border-base-300 rounded-lg bg-base-100">
                      <table class="table">
                        <thead>
                          <tr>
                            <th class="w-14"></th>
                            <th>Name</th>
                            <th class="text-right">Qlink Pages</th>
                            <th class="text-right">Catalogs</th>
                            <th class="w-40"></th>
                          </tr>
                        </thead>
                        <tbody>
                          <%= for creator <- filtered do %>
                            <tr class="hover">
                              <td>
                                <.creator_avatar creator={creator} size_class="w-10 h-10 text-sm" />
                              </td>
                              <td class="min-w-0">
                                <div class="font-medium">{creator.name}</div>
                                <%= if creator.bio do %>
                                  <div class="text-sm text-base-content/60 line-clamp-1">
                                    {creator.bio}
                                  </div>
                                <% end %>
                              </td>
                              <td class="text-right">{length(creator.qlink_pages)}</td>
                              <td class="text-right">{length(creator.catalogs)}</td>
                              <td>
                                <div class="flex justify-end gap-2">
                                  <.link
                                    navigate={~p"/creators/#{creator.id}"}
                                    class="btn btn-primary btn-sm"
                                  >
                                    Manage
                                  </.link>
                                  <button
                                    phx-click="delete"
                                    phx-value-id={creator.id}
                                    data-confirm="Are you sure you want to delete this creator?"
                                    class="btn btn-error btn-sm"
                                  >
                                    <.icon name="hero-trash" class="w-4 h-4" />
                                  </button>
                                </div>
                              </td>
                            </tr>
                          <% end %>
                        </tbody>
                      </table>
                    </div>
                  <% else %>
                    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                      <%= for creator <- filtered do %>
                        <div class="card bg-base-100 shadow-xl">
                          <figure class="px-10 pt-10">
                            <.creator_avatar creator={creator} size_class="w-24 h-24 text-3xl" />
                          </figure>

                          <div class="card-body items-center text-center">
                            <h2 class="card-title">{creator.name}</h2>

                            <%= if creator.bio do %>
                              <p class="text-sm line-clamp-5 whitespace-pre-line [overflow-wrap:anywhere] w-full text-base-content/70">
                                {creator.bio}
                              </p>
                            <% end %>

                            <div class="stats stats-horizontal shadow mt-4">
                              <div class="stat place-items-center">
                                <div class="stat-title">Qlink Pages</div>
                                <div class="stat-value text-sm">{length(creator.qlink_pages)}</div>
                              </div>
                              <div class="stat place-items-center">
                                <div class="stat-title">Catalogs</div>
                                <div class="stat-value text-sm">{length(creator.catalogs)}</div>
                              </div>
                            </div>

                            <div class="card-actions justify-end w-full mt-4 gap-2">
                              <.link
                                navigate={~p"/creators/#{creator.id}"}
                                class="btn btn-primary btn-sm"
                              >
                                Manage
                              </.link>
                              <button
                                phx-click="delete"
                                phx-value-id={creator.id}
                                data-confirm="Are you sure you want to delete this creator?"
                                class="btn btn-error btn-sm"
                              >
                                <.icon name="hero-trash" class="w-4 h-4" />
                              </button>
                            </div>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                <% end %>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </Layouts.admin>
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
  attr :size_class, :string, default: "w-24 h-24 text-3xl"

  defp creator_avatar(assigns) do
    ~H"""
    <%= if @creator.image do %>
      <img
        src={CreatorImage.url({@creator.image, @creator}, :original)}
        alt={@creator.name}
        class={"rounded-full object-cover #{@size_class}"}
      />
    <% else %>
      <div class="avatar placeholder">
        <div class={"bg-neutral text-neutral-content rounded-full #{@size_class}"}>
          <span>{String.first(@creator.name || "?")}</span>
        </div>
      </div>
    <% end %>
    """
  end
end
