defmodule QlariusWeb.Widgets.Arcade.ArqadeDiscoveryLive do
  @moduledoc """
  Discovery feed for browsable content — the "front door" to Arqade.

  Presents a mixed feed of discoverable catalogs and content groups that
  have active (purchasable) tiqit classes. This is the first "dumb" version;
  future iterations will personalise results using tag-based matching.

  Serves two contexts via @base_path (same pattern as other arqade LiveViews):
  - Main app: /arqade → @base_path = ""
  - Widget:   /widgets/arqade → @base_path = "/widgets"
  """
  use QlariusWeb, :live_view

  alias Qlarius.Tiqit.Arcade.Arcade
  alias Qlarius.Tiqit.Arcade.ContentGroup
  alias QlariusWeb.Layouts

  import QlariusWeb.Helpers.ImageHelpers
  import QlariusWeb.PWAHelpers

  on_mount {QlariusWeb.DetectMobile, :detect_mobile}

  def mount(_params, session, socket) do
    catalogs = Arcade.list_discoverable_catalogs()
    groups = Arcade.list_discoverable_groups()

    socket =
      socket
      |> init_pwa_assigns(session)
      |> assign(
        catalogs: catalogs,
        groups: groups,
        base_path: "",
        current_path: "/arqade",
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
    <div id="discovery-pwa-detect" phx-hook="PWADetect">
      <Layouts.maybe_mobile wrap={@base_path == ""} {assigns}>
        <div class="px-4 py-4 space-y-6">
          <div>
            <h1 class="text-xl font-bold">Discover</h1>
            <p class="text-sm text-base-content/50">Browse content from creators</p>
          </div>

          <%= if @catalogs == [] && @groups == [] do %>
            <div class="text-center text-base-content/50 py-12">
              No content available yet. Check back soon.
            </div>
          <% else %>
            <%!-- Catalog cards — larger, more prominent --%>
            <div :if={@catalogs != []} class="space-y-3">
              <h2 class="text-sm font-semibold text-base-content/40 uppercase tracking-wider">
                Catalogs
              </h2>
              <div class="grid grid-cols-1 gap-3">
                <.link
                  :for={catalog <- @catalogs}
                  navigate={"#{@base_path}/arqade/catalog/#{catalog.id}"}
                  class="bg-base-200 rounded-xl overflow-hidden border border-base-300 hover:border-widget-400 transition-all cursor-pointer block"
                >
                  <div class="flex gap-4 p-4">
                    <img
                      src={catalog_image_url(catalog)}
                      alt={catalog.name}
                      class="w-20 h-20 rounded-lg object-cover border border-base-300/50 flex-shrink-0"
                    />
                    <div class="flex-1 min-w-0">
                      <div class="font-semibold text-base-content">{catalog.name}</div>
                      <div class="text-sm text-base-content/60">{catalog.creator.name}</div>
                      <div class="text-xs text-base-content/40 mt-1">
                        {catalog_summary(catalog)}
                      </div>
                      <% price_info = catalog_price_info(catalog) %>
                      <div :if={price_info} class="text-xs font-medium mt-1">
                        <span :if={price_info.min_price} class="text-widget-700">
                          from {price_info.min_price}
                        </span>
                        <span
                          :if={price_info.min_price && price_info.free_count > 0}
                          class="text-base-content/50"
                        >
                          ·
                        </span>
                        <span :if={price_info.free_count > 0} class="text-base-content/50">
                          Includes {price_info.free_count} FREE {pluralize(
                            to_string(catalog.piece_type),
                            price_info.free_count
                          )}
                        </span>
                      </div>
                    </div>
                  </div>
                </.link>
              </div>
            </div>

            <%!-- Group cards — smaller, secondary prominence --%>
            <div :if={@groups != []} class="space-y-3">
              <h2 class="text-sm font-semibold text-base-content/40 uppercase tracking-wider">
                Featured
              </h2>
              <div class="grid grid-cols-1 gap-3">
                <.link
                  :for={group <- @groups}
                  navigate={"#{@base_path}/arqade/group/#{group.id}"}
                  class="bg-base-200 rounded-lg overflow-hidden border border-base-300 hover:border-widget-400 transition-all cursor-pointer block"
                >
                  <div class="flex gap-3 p-3">
                    <img
                      src={group_image_url(group)}
                      alt={group.title}
                      class="w-14 h-14 rounded-lg object-cover border border-base-300/50 flex-shrink-0"
                    />
                    <div class="flex-1 min-w-0">
                      <div class="font-medium text-sm text-base-content">{group.title}</div>
                      <div class="text-xs text-base-content/50">
                        {group.catalog.creator.name} › {group.catalog.name}
                      </div>
                      <div class="text-xs text-base-content/40 mt-0.5">
                        {group_summary(group)}
                      </div>
                    </div>
                  </div>
                </.link>
              </div>
            </div>
          <% end %>
        </div>
      </Layouts.maybe_mobile>
    </div>
    """
  end

  defp catalog_summary(catalog) do
    groups =
      Enum.filter(catalog.content_groups, fn g ->
        ContentGroup.has_active_content_pieces?(g.content_pieces)
      end)

    group_count = length(groups)

    piece_count =
      groups
      |> Enum.map(fn g -> length(ContentGroup.active_content_pieces(g.content_pieces)) end)
      |> Enum.sum()

    group_label = catalog.group_type |> to_string()
    piece_label = catalog.piece_type |> to_string()

    "#{piece_count} #{pluralize(piece_label, piece_count)} in #{group_count} #{pluralize(group_label, group_count)}"
  end

  defp group_summary(group) do
    count = length(ContentGroup.active_content_pieces(group.content_pieces))
    label = group.catalog.piece_type |> to_string()
    "#{count} #{pluralize(label, count)}"
  end

  defp catalog_price_info(catalog) do
    all_tiqit_classes =
      Enum.concat([
        Enum.filter(catalog.tiqit_classes, & &1.active),
        catalog.content_groups
        |> Enum.flat_map(&ContentGroup.active_content_pieces(&1.content_pieces))
        |> Enum.flat_map(& &1.tiqit_classes)
        |> Enum.filter(& &1.active)
      ])

    case all_tiqit_classes do
      [] ->
        nil

      classes ->
        prices = Enum.map(classes, & &1.price)
        paid = Enum.reject(prices, &Decimal.eq?(&1, 0))
        free_pieces = count_free_pieces(catalog)

        min_price =
          case paid do
            [] -> nil
            p -> "$#{Enum.min(p)}"
          end

        %{min_price: min_price, free_count: free_pieces}
    end
  end

  defp count_free_pieces(catalog) do
    catalog.content_groups
    |> Enum.flat_map(&ContentGroup.active_content_pieces(&1.content_pieces))
    |> Enum.count(fn piece ->
      piece.tiqit_classes
      |> Enum.filter(& &1.active)
      |> Enum.any?(&Decimal.eq?(&1.price, 0))
    end)
  end

  defp pluralize(word, 1), do: word
  defp pluralize("series", _), do: "series"
  defp pluralize("class", _), do: "classes"
  defp pluralize(word, _), do: word <> "s"
end
