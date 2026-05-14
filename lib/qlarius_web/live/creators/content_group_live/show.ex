defmodule QlariusWeb.Creators.ContentGroupLive.Show do
  use QlariusWeb, :live_view

  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}
  alias Qlarius.Tiqit.Arcade.Creators
  alias Qlarius.Tiqit.Arcade.Arcade
  alias Qlarius.Tiqit.Arcade.ContentGroup
  alias QlariusWeb.Creators.ContentGroupHTML
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

  def handle_event("delete_tiqit_class", %{"id" => id}, socket) do
    {:ok, _} = Creators.delete_tiqit_class(id)

    content_group = Creators.get_content_group!(socket.assigns.content_group.id)

    {:noreply,
     socket
     |> assign(:content_group, content_group)
     |> put_flash(:info, "Tiqit class deleted successfully")}
  end

  def handle_event("move_piece", %{"id" => id, "direction" => dir}, socket)
      when dir in ["up", "down"] do
    case Integer.parse(to_string(id)) do
      {piece_id, _} ->
        group = socket.assigns.content_group
        ordered = ContentGroup.ordered_content_pieces(group.content_pieces)
        idx = Enum.find_index(ordered, &(&1.id == piece_id))
        len = length(ordered)

        new_ordered =
          case {dir, idx} do
            {"up", i} when is_integer(i) and i > 0 -> swap_at(ordered, i, i - 1)
            {"down", i} when is_integer(i) and i < len - 1 -> swap_at(ordered, i, i + 1)
            _ -> ordered
          end

        if new_ordered == ordered do
          {:noreply, socket}
        else
          case Creators.restripe_content_pieces(group, new_ordered) do
            {:ok, g} -> {:noreply, assign(socket, :content_group, g)}
            {:error, _} -> {:noreply, put_flash(socket, :error, "Could not update order.")}
          end
        end

      :error ->
        {:noreply, socket}
    end
  end

  def handle_event("move_piece", _params, socket), do: {:noreply, socket}

  def handle_event("apply_piece_order_preset", params, socket) do
    preset = Map.get(params, "preset", "")

    if preset == "" or preset not in ContentGroup.piece_order_presets() do
      {:noreply, socket}
    else
      group = socket.assigns.content_group
      active = ContentGroup.active_content_pieces(group.content_pieces)
      sorted = ContentGroup.sort_pieces_by_preset(active, preset)

      case Creators.restripe_content_pieces(group, sorted) do
        {:ok, g} ->
          {:noreply,
           socket
           |> assign(:content_group, g)
           |> put_flash(
             :info,
             "Display order updated for all #{socket.assigns.catalog.piece_type}s."
           )}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not update order.")}
      end
    end
  end

  defp content_group_image_url(group) do
    ImageHelpers.group_image_url(group)
  end

  defp content_group_iframe_url(group) do
    base_url = QlariusWeb.Endpoint.url()
    "#{base_url}/widgets/arqade/group/#{group.id}"
  end

  defp swap_at(list, i, j) do
    a = Enum.at(list, i)
    b = Enum.at(list, j)
    list |> List.replace_at(i, b) |> List.replace_at(j, a)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <Layouts.admin {assigns}>
        <div class="flex h-screen">
          <AdminSidebar.sidebar current_user={@current_scope.user} />

          <div class="flex min-w-0 grow flex-col">
            <AdminTopbar.topbar current_user={@current_scope.user} />

            <div class="overflow-auto">
              <div class="p-6">
                <div class="space-y-6">
                  <!-- Breadcrumbs -->
                  <.breadcrumbs
                    crumbs={[
                      {@creator.name, ~p"/creators/#{@creator.id}"},
                      {"#{String.capitalize(to_string(@catalog.type))}: #{@catalog.name}",
                       ~p"/creators/catalogs/#{@catalog.id}"}
                    ]}
                    current={"#{String.capitalize(to_string(@catalog.group_type))}: #{@content_group.title}"}
                  />
                  
    <!-- Header Section -->
                  <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
                    <div>
                      <h1 class="text-2xl font-bold text-base-content">{@content_group.title}</h1>
                      <p class="text-base-content/60 mt-1">
                        {@catalog.group_type |> to_string() |> String.capitalize()} • {@creator.name}
                      </p>
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
                          {ContentGroupHTML.group_card_description_p_tag(
                            @content_group.description || ""
                          )}
                        </div>
                        
    <!-- Embed Link -->
                        <%= if ContentGroup.has_active_content_pieces?(@content_group.content_pieces) do %>
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
                          <TiqitClassHTML.tiqit_classes_table
                            record={@content_group}
                            on_delete="delete_tiqit_class"
                          />
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
                            <button
                              phx-click="add_default_tiqit_classes"
                              class="btn btn-primary btn-sm"
                            >
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
                      <div class="flex flex-wrap gap-2 justify-end">
                        <button
                          :if={ContentGroup.has_active_content_pieces?(@content_group.content_pieces)}
                          type="button"
                          phx-click={show_modal("piece-order-modal")}
                          class="btn btn-outline btn-secondary"
                        >
                          <.icon name="hero-arrows-up-down" class="w-4 h-4 mr-2" /> Display order
                        </button>
                        <.link
                          navigate={
                            ~p"/creators/content_groups/#{@content_group.id}/content_pieces/new"
                          }
                          class="btn btn-primary"
                        >
                          <.icon name="hero-plus" class="w-4 h-4 mr-2" />
                          New {@content_group.catalog.piece_type |> to_string() |> String.capitalize()}
                        </.link>

                        <.link
                          navigate={~p"/creators/content_groups/#{@content_group.id}/youtube_import"}
                          class="btn btn-outline btn-primary"
                        >
                          <.icon name="hero-play-circle" class="w-4 h-4 mr-2" /> Import from YouTube
                        </.link>
                      </div>
                    </div>

                    <%= if ContentGroup.has_active_content_pieces?(@content_group.content_pieces) do %>
                      <div class="space-y-3">
                        <%= for piece <- ContentGroup.ordered_content_pieces(@content_group.content_pieces) do %>
                          <div class="card bg-base-100 shadow-lg hover:shadow-xl transition-shadow">
                            <div class="card-body p-4">
                              <div class="flex gap-4">
                                <%= if @content_group.show_piece_thumbnails do %>
                                  <div class="flex-shrink-0 w-24 self-start">
                                    <img
                                      src={ImageHelpers.content_image_url(piece, @content_group)}
                                      alt={piece.title}
                                      class="w-full h-auto object-cover rounded-lg"
                                    />
                                  </div>
                                <% end %>

                                <div class="flex-1 min-w-0">
                                  <div class="flex items-start justify-between gap-4">
                                    <div class="flex-1 min-w-0 space-y-1">
                                      <h3 class="text-lg font-semibold text-base-content">
                                        {piece.title}
                                      </h3>

                                      <div class="flex flex-wrap items-center gap-x-3 gap-y-0.5 text-xs text-base-content/50">
                                        <span class="flex items-center gap-1">
                                          <.icon name="hero-calendar" class="w-3 h-3" />
                                          {Calendar.strftime(piece.inserted_at, "%b %d, %Y")}
                                        </span>
                                        <span class="flex items-center gap-1">
                                          <.icon name="hero-clock" class="w-3 h-3" />
                                          {format_duration(piece.length)}
                                        </span>
                                        <span class="flex items-center gap-1">
                                          <.icon name="hero-tag" class="w-3 h-3" />
                                          {length(piece.tiqit_classes)} classes
                                        </span>
                                      </div>

                                      <%= if @content_group.show_piece_descriptions && piece.description do %>
                                        <div class="description-container" id={"desc-#{piece.id}"}>
                                          {ContentGroupHTML.piece_description_p_tag(piece.description)}
                                          <button
                                            type="button"
                                            onclick={"toggleDescription(document.getElementById('desc-#{piece.id}'))"}
                                            class="expand-btn mt-1 cursor-pointer text-xs font-medium text-primary hover:text-primary-focus"
                                          >
                                            Expand
                                          </button>
                                        </div>
                                      <% end %>
                                    </div>

                                    <div class="flex gap-2 flex-shrink-0">
                                      <.link
                                        navigate={~p"/creators/content_pieces/#{piece.id}"}
                                        class="btn btn-ghost btn-sm"
                                      >
                                        <.icon name="hero-eye" class="w-4 h-4" />
                                      </.link>
                                      <.link
                                        navigate={~p"/creators/content_pieces/#{piece.id}/edit"}
                                        class="btn btn-ghost btn-sm"
                                      >
                                        <.icon name="hero-pencil" class="w-4 h-4" />
                                      </.link>
                                    </div>
                                  </div>
                                </div>
                              </div>
                            </div>
                          </div>
                        <% end %>
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
                            <h3 class="text-lg font-bold text-base-content mb-2">
                              No Content Pieces Yet
                            </h3>
                            <p class="text-base-content/60 mb-6">
                              Start building your content collection by adding your first {@catalog.piece_type}.
                            </p>
                            <div class="flex flex-col sm:flex-row gap-3 justify-center">
                              <.link
                                navigate={
                                  ~p"/creators/content_groups/#{@content_group.id}/content_pieces/new"
                                }
                                class="btn btn-primary btn-lg"
                              >
                                <.icon name="hero-plus" class="w-5 h-5 mr-2" />
                                Add First Content Piece
                              </.link>

                              <.link
                                navigate={
                                  ~p"/creators/content_groups/#{@content_group.id}/youtube_import"
                                }
                                class="btn btn-outline btn-primary btn-lg"
                              >
                                <.icon name="hero-play-circle" class="w-5 h-5 mr-2" />
                                Import from YouTube
                              </.link>
                            </div>
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

      <.modal id="piece-order-modal" on_cancel={hide_modal("piece-order-modal")}>
        <div class="p-6 space-y-4 max-h-[min(32rem,85vh)] overflow-y-auto">
          <h2 id="piece-order-modal-title" class="text-lg font-semibold text-base-content pr-10">
            {String.capitalize(to_string(@catalog.piece_type))} display order
          </h2>
          <p id="piece-order-modal-description" class="text-sm text-base-content/70">
            Use the arrows to move one row at a time, or pick a sort to rewrite order for every {to_string(
              @catalog.piece_type
            )} in this group.
          </p>

          <form phx-change="apply_piece_order_preset" class="form-control max-w-md">
            <label class="label py-0">
              <span class="label-text font-medium">Reorder all by</span>
            </label>
            <select name="preset" class="select select-bordered select-sm w-full">
              <option value="">Choose…</option>
              <option value="desc">Newest first (by date added)</option>
              <option value="asc">Oldest first (by date added)</option>
              <option value="title_asc">Title A–Z</option>
              <option value="title_desc">Title Z–A</option>
            </select>
          </form>

          <ul class="divide-y divide-base-300 border border-base-300 rounded-lg">
            <%= for {piece, idx} <- Enum.with_index(ContentGroup.ordered_content_pieces(@content_group.content_pieces)) do %>
              <% last? =
                idx ==
                  length(ContentGroup.active_content_pieces(@content_group.content_pieces)) - 1 %>
              <li class="flex items-center gap-2 px-3 py-2 bg-base-100">
                <span class="flex-1 min-w-0 text-sm font-medium truncate" title={piece.title}>
                  {piece.title}
                </span>
                <div class="flex flex-col gap-0.5 flex-shrink-0">
                  <button
                    type="button"
                    phx-click="move_piece"
                    phx-value-id={piece.id}
                    phx-value-direction="up"
                    disabled={idx == 0}
                    class="btn btn-ghost btn-xs px-1 min-h-0 h-7 disabled:opacity-30"
                    aria-label="Move up"
                  >
                    <.icon name="hero-chevron-up" class="w-4 h-4" />
                  </button>
                  <button
                    type="button"
                    phx-click="move_piece"
                    phx-value-id={piece.id}
                    phx-value-direction="down"
                    disabled={last?}
                    class="btn btn-ghost btn-xs px-1 min-h-0 h-7 disabled:opacity-30"
                    aria-label="Move down"
                  >
                    <.icon name="hero-chevron-down" class="w-4 h-4" />
                  </button>
                </div>
              </li>
            <% end %>
          </ul>
        </div>
      </.modal>

      <script type="text/javascript">
        function copyCode(element) {
          navigator.clipboard.writeText(element.querySelector('code').textContent);
          const notification = element.querySelector('.copy-notification');
          notification.classList.remove('hidden');
          setTimeout(() => notification.classList.add('hidden'), 2000);
        }

        window.toggleDescription = function(container) {
          const text = container.querySelector('.description-text');
          const btn = container.querySelector('.expand-btn');
          
          if (text.classList.contains('line-clamp-3')) {
            text.classList.remove('line-clamp-3');
            btn.textContent = 'Collapse';
          } else {
            text.classList.add('line-clamp-3');
            btn.textContent = 'Expand';
          }
        };
      </script>
    </div>
    """
  end
end
