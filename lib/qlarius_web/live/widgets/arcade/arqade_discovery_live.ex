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

  import QlariusWeb.Widgets.Arcade.Components,
    only: [
      discovery_item_card: 1,
      discovery_grid_class: 1,
      discovery_view_toolbar: 1
    ]

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
        title: "Arqade",
        display_mode: "tile",
        show_discovery_view_menu: false
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

  def handle_event("set_discovery_display_mode", %{"mode" => mode}, socket)
      when mode in ~w(tile list) do
    {:noreply,
     socket
     |> assign(:display_mode, mode)
     |> assign(:show_discovery_view_menu, false)}
  end

  def handle_event("toggle_discovery_view_menu", _params, socket) do
    {:noreply, assign(socket, :show_discovery_view_menu, !socket.assigns.show_discovery_view_menu)}
  end

  def handle_event("hide_discovery_view_menu", _params, socket) do
    {:noreply, assign(socket, :show_discovery_view_menu, false)}
  end

  def render(assigns) do
    ~H"""
    <div id="discovery-pwa-detect" phx-hook="PWADetect">
      <Layouts.maybe_mobile wrap={@base_path == ""} {assigns}>
        <div class="space-y-6 pb-2">
          <div>
            <h1 class="text-xl font-bold">Discover</h1>
            <p class="text-sm text-base-content/50">Browse content from creators</p>
          </div>

          <%= if @catalogs == [] && @groups == [] do %>
            <div class="text-center text-base-content/50 py-12">
              No content available yet. Check back soon.
            </div>
          <% else %>
            <div :if={@catalogs != []} class="space-y-3">
              <h2 class="text-base sm:text-lg font-bold tracking-tight text-base-content/50">Catalogs</h2>
              <div class={discovery_grid_class(@display_mode)}>
                <.discovery_item_card
                  :for={catalog <- @catalogs}
                  display_mode={@display_mode}
                  navigate={"#{@base_path}/arqade/catalog/#{catalog.id}"}
                  image_src={catalog_image_url(catalog)}
                  image_alt={catalog.name}
                  title={catalog.name}
                  subtitle={catalog.creator.name}
                  detail={catalog_summary(catalog)}
                  price_info={catalog_price_info(catalog)}
                  piece_type={to_string(catalog.piece_type)}
                />
              </div>
            </div>

            <div :if={@groups != []} class="space-y-3">
              <h2 class="text-base sm:text-lg font-bold tracking-tight text-base-content/50">Featured</h2>
              <div class={discovery_grid_class(@display_mode)}>
                <.discovery_item_card
                  :for={group <- @groups}
                  display_mode={@display_mode}
                  navigate={"#{@base_path}/arqade/group/#{group.id}"}
                  image_src={group_image_url(group)}
                  image_alt={group.title}
                  title={group.title}
                  subtitle={"#{group.catalog.creator.name} › #{group.catalog.name}"}
                  detail={group_summary(group)}
                />
              </div>
            </div>
          <% end %>
        </div>

        <.discovery_view_toolbar
          :if={@base_path == ""}
          display_mode={@display_mode}
          show_view_menu={@show_discovery_view_menu}
        />
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
