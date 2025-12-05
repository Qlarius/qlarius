defmodule QlariusWeb.Creators.ContentGroupLive.Show do
  use QlariusWeb, :live_view

  alias Qlarius.Tiqit.Arcade.Creators
  alias Qlarius.Tiqit.Arcade.Arcade
  alias QlariusWeb.Helpers.ImageHelpers
  alias QlariusWeb.TiqitClassHTML
  import QlariusWeb.CoreComponents

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    content_group = Creators.get_content_group!(id)
    catalog = content_group.catalog
    creator = catalog.creator

    {:ok,
     socket
     |> assign(:content_group, content_group)
     |> assign(:catalog, catalog)
     |> assign(:creator, creator)
     |> assign(:page_title, content_group.title)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    content_group = socket.assigns.content_group
    catalog = content_group.catalog

    {:ok, _content_group} = Creators.delete_content_group(content_group)

    {:noreply,
     socket
     |> put_flash(:info, "Content group deleted successfully")
     |> push_navigate(to: ~p"/creators/catalogs/#{catalog.id}")}
  end

  def handle_event("add_default_tiqit_classes", _params, socket) do
    Arcade.write_default_group_tiqit_classes(socket.assigns.content_group)

    content_group = Creators.get_content_group!(socket.assigns.content_group.id)

    {:noreply,
     socket
     |> assign(:content_group, content_group)
     |> put_flash(:info, "Default Tiqit classes added successfully")}
  end

  defp content_group_image_url(group) do
    ImageHelpers.group_image_url(group)
  end

  defp content_group_iframe_url(group) do
    # For LiveView, we need to construct the URL differently
    # Using the current URI from socket
    origin = get_origin()
    scheme = get_scheme()
    "#{scheme}://#{origin}/widgets/arcade/group/#{group.id}"
  end

  defp get_scheme do
    case System.get_env("PHX_HOST") do
      nil -> "http"
      _ -> "https"
    end
  end

  defp get_origin do
    # This is a simplified version - in production you'd want to get this from socket or config
    case System.get_env("PHX_HOST") do
      nil -> "localhost:4000"
      host -> host
    end
  end

  defp content_image_url(piece, group) do
    ImageHelpers.content_image_url(piece, group)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin {assigns}>
      <div class="p-6">
        <div class="space-y-6">
          <!-- Header Section -->
          <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
            <div class="flex items-center gap-4">
              <.link navigate={~p"/creators/#{@creator.id}"} class="btn btn-ghost btn-sm">
                <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to Creator
              </.link>
              <div>
                <h1 class="text-2xl font-bold text-base-content">{@content_group.title}</h1>
                <p class="text-base-content/60 mt-1">
                  {@catalog.group_type |> to_string() |> String.capitalize()} • {@creator.name}
                </p>
              </div>
            </div>
            <div class="flex gap-2">
              <.link
                navigate={~p"/creators/content_groups/#{@content_group.id}/edit"}
                class="btn btn-outline"
              >
                <.icon name="hero-pencil" class="w-4 h-4 mr-2" /> Edit
              </.link>
              <button
                phx-click="delete"
                data-confirm="Are you sure you want to delete this content group?"
                class="btn btn-outline btn-error"
              >
                <.icon name="hero-trash" class="w-4 h-4 mr-2" /> Delete
              </button>
            </div>
          </div>

          <!-- Description and Embed Section -->
          <div class="card bg-base-100 shadow-lg">
            <div class="card-body">
              <img
                src={content_group_image_url(@content_group)}
                alt={@content_group.title}
                class="w-50 h-50 object-cover rounded-lg mb-2"
              />
              <div class="space-y-6">
                <!-- Description -->
                <div>
                  <h3 class="text-lg font-semibold text-base-content mb-3">Description</h3>
                  <div class="prose prose-sm max-w-none">
                    <p class="text-base-content/80 italic">{@content_group.description}</p>
                  </div>
                </div>

                <!-- Embed Link -->
                <%= if Enum.any?(@content_group.content_pieces) do %>
                  <div class="border-t border-base-300 pt-6">
                    <h4 class="text-md font-semibold text-base-content mb-3 flex items-center">
                      <.icon name="hero-code-bracket" class="w-5 h-5 mr-2" /> Embed Code
                    </h4>

                    <div class="flex items-center gap-4">
                      <div class="flex-1">
                        <div
                          class="relative bg-base-200 hover:bg-base-300 rounded-lg p-4 cursor-pointer transition-colors group"
                          onclick="copyCode(this)"
                        >
                          <div class="flex items-center justify-between">
                            <code class="text-sm font-mono text-base-content break-all">
                              {content_group_iframe_url(@content_group)}
                            </code>
                            <div class="flex items-center gap-2 ml-4">
                              <.icon
                                name="hero-document-duplicate"
                                class="w-5 h-5 text-base-content/60 group-hover:text-base-content"
                              />
                            </div>
                          </div>

                          <!-- Copy notification -->
                          <div class="copy-notification hidden absolute -top-2 -right-2 bg-success text-success-content text-xs px-2 py-1 rounded shadow-lg">
                            Copied!
                          </div>
                        </div>
                      </div>

                      <.link
                        navigate={~p"/creators/content_groups/#{@content_group.id}/preview"}
                        class="btn btn-outline btn-sm whitespace-nowrap"
                      >
                        <.icon name="hero-eye" class="w-4 h-4 mr-2" /> Preview
                      </.link>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>

          <!-- Tiqit Classes Section -->
          <div class="space-y-4">
            <div class="flex items-center justify-between">
              <h2 class="text-xl font-semibold text-base-content flex items-center">
                <.icon name="hero-tag" class="w-6 h-6 mr-3 text-primary" /> {@content_group.catalog.group_type
                |> to_string()
                |> String.capitalize()} Tiqit Classes
              </h2>
            </div>

            <%= if Enum.any?(@content_group.tiqit_classes) do %>
              <div class="card bg-base-100 shadow-lg">
                <div class="card-body p-0">
                  <TiqitClassHTML.tiqit_classes_table record={@content_group} />
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
                    <h3 class="text-lg font-bold text-base-content mb-2">No Tiqit Classes Yet</h3>
                    <button phx-click="add_default_tiqit_classes" class="btn btn-primary btn-sm">
                      <.icon name="hero-plus" class="w-4 h-4 mr-2" /> Add Tiqit Class Defaults
                    </button>
                  </div>
                </div>
              </div>
            <% end %>
          </div>

          <!-- Content Pieces Section -->
          <div class="space-y-4">
            <div class="flex items-center justify-between">
              <h2 class="text-xl font-semibold text-base-content flex items-center">
                <.icon name="hero-queue-list" class="w-6 h-6 mr-3 text-secondary" /> {@content_group.catalog.piece_type
                |> to_string()
                |> String.capitalize()}(s)
              </h2>
              <div class="flex gap-2">
                <.link
                  navigate={~p"/creators/content_groups/#{@content_group.id}/content_pieces/new"}
                  class="btn btn-primary"
                >
                  <.icon name="hero-plus" class="w-4 h-4 mr-2" />
                  New {@content_group.catalog.piece_type |> to_string() |> String.capitalize()}
                </.link>
              </div>
            </div>

            <%= if Enum.any?(@content_group.content_pieces) do %>
              <div class="card bg-base-100 shadow-lg">
                <div class="card-body p-0">
                  <div class="overflow-x-auto">
                    <table class="table table-zebra w-full">
                      <thead class="bg-base-200">
                        <tr>
                          <th class="font-semibold text-base-content">Title</th>
                          <th class="font-semibold text-base-content">Added</th>
                          <th class="font-semibold text-base-content">Length</th>
                          <th class="font-semibold text-base-content">Tiqit Classes</th>
                          <th class="font-semibold text-base-content text-right">Actions</th>
                        </tr>
                      </thead>
                      <tbody class="divide-y divide-base-300">
                        <%= for piece <- Enum.sort_by(@content_group.content_pieces, & &1.id) do %>
                          <tr
                            class="hover:bg-base-200 cursor-pointer transition-colors"
                            phx-click={JS.navigate(~p"/creators/content_pieces/#{piece.id}")}
                          >
                            <td class="font-medium text-base-content">
                              <div class="flex items-center gap-3">
                                <%= if @content_group.show_piece_thumbnails do %>
                                  <div class="avatar">
                                    <div class="w-12 h-12 rounded-lg">
                                      <img
                                        src={ImageHelpers.content_image_url(piece, @content_group)}
                                        alt={piece.title}
                                        class="w-full h-full object-cover rounded-lg"
                                      />
                                    </div>
                                  </div>
                                <% else %>
                                  <div class="avatar placeholder">
                                    <div class="bg-neutral-focus text-neutral-content rounded-full w-8 h-8">
                                      <span class="text-xs">{String.at(piece.title, 0)}</span>
                                    </div>
                                  </div>
                                <% end %>
                                <div>
                                  <div class="font-medium">{piece.title}</div>
                                  <div class="text-sm text-base-content/60">{piece.description}</div>
                                </div>
                              </div>
                            </td>
                            <td class="text-base-content">
                              <span class="badge badge-outline badge-xs whitespace-nowrap">
                                {Calendar.strftime(piece.inserted_at, "%b %d, %Y")}
                              </span>
                            </td>
                            <td class="text-base-content">
                              <span class="badge badge-primary badge-xs">
                                {format_duration(piece.length)}
                              </span>
                            </td>
                            <td class="text-base-content">
                              <span class="badge badge-secondary badge-xs">
                                {length(piece.tiqit_classes)}
                              </span>
                            </td>
                            <td class="text-right">
                              <div class="flex gap-2 justify-end">
                                <.link
                                  navigate={~p"/creators/content_pieces/#{piece.id}/edit"}
                                  class="btn btn-ghost btn-sm"
                                >
                                  <.icon name="hero-pencil" class="w-4 h-4" />
                                </.link>
                                <.link
                                  navigate={~p"/creators/content_pieces/#{piece.id}"}
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
              <!-- Empty State for Content Pieces -->
              <div class="hero min-h-48 bg-base-200 rounded-lg">
                <div class="hero-content text-center">
                  <div class="max-w-md">
                    <div class="avatar placeholder mb-4">
                      <div class="bg-neutral-focus text-neutral-content rounded-full w-16 h-16">
                        <span class="text-xl">📄</span>
                      </div>
                    </div>
                    <h3 class="text-lg font-bold text-base-content mb-2">No Content Pieces Yet</h3>
                    <p class="text-base-content/60 mb-6">
                      Start building your content collection by adding your first {@catalog.piece_type}.
                    </p>
                    <.link
                      navigate={~p"/creators/content_groups/#{@content_group.id}/content_pieces/new"}
                      class="btn btn-primary btn-lg"
                    >
                      <.icon name="hero-plus" class="w-5 h-5 mr-2" /> Add First Content Piece
                    </.link>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.admin>

    <script type="text/javascript">
      function copyCode(element) {
        navigator.clipboard.writeText(element.querySelector('code').textContent);
        const notification = element.querySelector('.copy-notification');
        notification.classList.remove('hidden');
        setTimeout(() => notification.classList.add('hidden'), 2000);
      }
    </script>
    """
  end
end
