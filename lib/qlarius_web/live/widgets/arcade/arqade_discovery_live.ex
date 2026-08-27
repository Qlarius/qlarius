defmodule QlariusWeb.Widgets.Arcade.ArqadeDiscoveryLive do
  @moduledoc """
  Discovery feed for browsable content — the "front door" to Arqade.

  Groups load via `assign_async` so the first paint can show a skeleton
  instead of blocking on the discoverable-group query.

  Serves three contexts via @base_path (same pattern as other arqade LiveViews):
    - Main app: /arqade → @base_path = ""
    - Widget:   /widgets/arqade → @base_path = "/widgets"
    - Tiqit:    /tiqit/arqade → @base_path = "/tiqit"
  """
  use QlariusWeb, :live_view

  alias Qlarius.Tiqit.Arcade.Arcade
  alias Qlarius.Tiqit.Arcade.Catalog
  alias Qlarius.Tiqit.Arcade.ContentGroup
  alias QlariusWeb.TiqitArqade.Host
  alias QlariusWeb.Widgets.Arcade.Paths

  import QlariusWeb.Helpers.ImageHelpers
  import QlariusWeb.PWAHelpers

  import QlariusWeb.Widgets.Arcade.Components,
    only: [
      arqade_page_wrap: 1,
      discovery_item_card: 1,
      discovery_grid_class: 1,
      discovery_section_skeleton: 1,
      discovery_view_toolbar: 1
    ]

  on_mount {QlariusWeb.DetectMobile, :detect_mobile}

  def mount(_params, session, socket) do
    socket =
      socket
      |> init_pwa_assigns(session)
      |> assign(
        base_path: "",
        current_path: Paths.discover(""),
        title: "Arqade",
        display_mode: "tile",
        show_discovery_view_menu: false
      )
      |> assign_async(:groups, fn ->
        {:ok, %{groups: Arcade.list_discoverable_groups()}}
      end)
      |> maybe_init_tiqit_host()

    {:ok, socket}
  end

  def handle_params(_params, uri, socket) do
    base_path = Paths.resolve_base_path(uri, socket.assigns[:base_path])

    socket =
      socket
      |> assign(:base_path, base_path)
      |> assign(:current_path, Paths.discover(base_path))
      |> maybe_init_tiqit_host()

    {:noreply, socket}
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

  def handle_event("open_auth_sheet", params, socket) do
    if Host.tiqit_host?(socket) do
      case Host.handle_event("open_auth_sheet", params, socket) do
        {:handled, socket} -> {:noreply, socket}
        :unhandled -> {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event(event, params, socket) do
    if Host.tiqit_host?(socket) do
      case Host.handle_event(event, params, socket) do
        {:handled, socket} -> {:noreply, socket}
        :unhandled -> {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info(msg, socket) do
    if Host.tiqit_host?(socket) do
      case Host.handle_info(msg, socket) do
        {:handled, socket} -> {:noreply, socket}
        :unhandled -> {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div id="discovery-pwa-detect" phx-hook="PWADetect">
      <.arqade_page_wrap base_path={@base_path} wrap_mobile={@base_path == ""} {assigns}>
        <div class={[
          "flex flex-col gap-6 pb-2",
          @base_path == "/tiqit" && "overflow-y-auto flex-1 min-h-0 px-4 py-4"
        ]}>
          <p class="mobile-page-intro">Browse content from creators</p>

          <.async_result :let={groups} assign={@groups}>
            <:loading>
              <.discovery_section_skeleton
                display_mode={@display_mode}
                elevated={@base_path == ""}
              />
            </:loading>
            <:failed>
              <div class="text-center text-base-content/50 py-12">
                Couldn't load content. Try refreshing.
              </div>
            </:failed>

            <%= if groups == [] do %>
              <div class="text-center text-base-content/50 py-12">
                No content available yet. Check back soon.
              </div>
            <% else %>
              <div class={discovery_grid_class(@display_mode)}>
                <.discovery_item_card
                  :for={group <- groups}
                  elevated={@base_path == ""}
                  display_mode={@display_mode}
                  navigate={Paths.group(@base_path, group.id)}
                  image_src={group_image_url(group)}
                  image_alt={group.title}
                  title={group.title}
                  subtitle={group.catalog.creator.name}
                  detail={group_card_detail(group)}
                  price_info={group_price_info(group)}
                  piece_type={to_string(group.catalog.piece_type)}
                />
              </div>
            <% end %>
          </.async_result>
        </div>

        <.discovery_view_toolbar
          :if={@base_path == ""}
          display_mode={@display_mode}
          show_view_menu={@show_discovery_view_menu}
        />
      </.arqade_page_wrap>
    </div>
    """
  end

  defp maybe_init_tiqit_host(socket) do
    if socket.assigns[:base_path] == "/tiqit" do
      Host.init_browse_scope(socket, Paths.discover("/tiqit"))
    else
      socket
    end
  end

  defp group_card_detail(group) do
    catalog = group.catalog
    count = length(ContentGroup.active_content_pieces(group.content_pieces))

    "#{count} #{Catalog.type_label(catalog.piece_type, count, capitalize: false)}"
  end

  defp group_price_info(group) do
    active_pieces = ContentGroup.active_content_pieces(group.content_pieces)

    all_tiqit_classes =
      Enum.concat(
        Enum.filter(group.tiqit_classes, & &1.active),
        active_pieces
        |> Enum.flat_map(& &1.tiqit_classes)
        |> Enum.filter(& &1.active)
      )

    case all_tiqit_classes do
      [] ->
        nil

      classes ->
        prices = Enum.map(classes, & &1.price)
        paid = Enum.reject(prices, &Decimal.eq?(&1, 0))

        free_count =
          Enum.count(active_pieces, fn piece ->
            piece.tiqit_classes
            |> Enum.filter(& &1.active)
            |> Enum.any?(&Decimal.eq?(&1.price, 0))
          end)

        min_price = if paid != [], do: "$#{Enum.min(paid)}"

        %{min_price: min_price, free_count: free_count}
    end
  end
end
