defmodule QlariusWeb.Widgets.Arcade.ArcadeCatalogLive do
  @moduledoc """
  Displays a catalog's content groups, allowing navigation into each group.

  This LiveView serves two contexts via @base_path:
  - Embedded widgets: mounted at /widgets/arqade/catalog/:catalog_id → @base_path = "/widgets"
  - Main app: mounted at /arqade/catalog/:catalog_id → @base_path = ""
  All internal links use @base_path to stay within the correct context.
  """
  use QlariusWeb, :live_view

  alias Qlarius.Tiqit.Arcade.Creators
  alias QlariusWeb.Layouts

  import QlariusWeb.Helpers.ImageHelpers
  import QlariusWeb.PWAHelpers

  on_mount {QlariusWeb.DetectMobile, :detect_mobile}

  def mount(%{"catalog_id" => catalog_id}, session, socket) do
    catalog = Creators.get_catalog!(catalog_id)

    groups =
      catalog.content_groups
      |> Enum.filter(fn g -> Enum.any?(g.content_pieces) end)
      |> Enum.sort_by(& &1.inserted_at, :desc)
      |> Enum.map(fn g -> %{g | catalog: catalog} end)

    socket =
      socket
      |> init_pwa_assigns(session)
      |> assign(
        catalog: catalog,
        groups: groups,
        base_path: "",
        current_path: "/arqade/catalog/#{catalog_id}",
        title: "Arqade"
      )

    {:ok, socket}
  end

  def handle_params(_params, uri, socket) do
    base_path = if String.contains?(uri, "/widgets/"), do: "/widgets", else: ""
    {:noreply, assign(socket, :base_path, base_path)}
  end

  def handle_event("pwa_detected", params, socket) do
    handle_pwa_detection(socket, params)
  end

  def handle_event("referral_code_from_storage", _params, socket) do
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div id="catalog-pwa-detect" phx-hook="PWADetect">
    <Layouts.maybe_mobile wrap={@base_path == ""} {assigns}>
      <div class="mb-6">
        <div class="flex items-center gap-4 mb-6">
          <%= if @catalog.image do %>
            <img
              src={catalog_image_url(@catalog)}
              alt={@catalog.name}
              class="w-16 h-16 rounded-lg object-cover border border-base-300"
            />
          <% end %>
          <div>
            <h1 class="text-2xl font-bold">{@catalog.name}</h1>
            <p class="text-sm text-base-content/60">
              {length(@groups)} {if length(@groups) == 1, do: @catalog.group_type, else: pluralize(@catalog.group_type)}
            </p>
          </div>
        </div>

        <%= if @groups == [] do %>
          <div class="text-center text-base-content/50 py-8">
            No content available in this catalog.
          </div>
        <% else %>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <.link
              :for={group <- @groups}
              navigate={"#{@base_path}/arqade/group/#{group.id}"}
              class="bg-base-200 rounded-lg p-4 border border-base-300 hover:border-primary/50 hover:bg-base-200/80 transition-all cursor-pointer block"
            >
              <div class="flex gap-4 items-start">
                <img
                  src={group_image_url(group)}
                  alt={group.title}
                  class="w-20 h-20 rounded-lg object-cover border border-base-300/50 flex-shrink-0"
                />
                <div class="flex-1 min-w-0">
                  <h3 class="font-semibold text-base-content mb-1">{group.title}</h3>
                  <p class="text-sm text-base-content/60">
                    {length(group.content_pieces)} {if length(group.content_pieces) == 1, do: @catalog.piece_type, else: pluralize(@catalog.piece_type)}
                  </p>
                </div>
              </div>
            </.link>
          </div>
        <% end %>
      </div>
    </Layouts.maybe_mobile>
    </div>
    """
  end

  defp pluralize(word) do
    word = to_string(word)
    if word == "series", do: "series", else: word <> "s"
  end
end
