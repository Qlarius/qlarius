defmodule QlariusWeb.Widgets.Arcade.ArcadeCatalogLive do
  @moduledoc """
  Displays a catalog's content groups, allowing navigation into each group.

  This LiveView serves three contexts via @base_path:
  - Embedded widgets: `/widgets/arqade/catalog/:catalog_id` → `"/widgets"`
  - Main app: `/arqade/catalog/:catalog_id` → `""`
  - Tiqit public: `/tiqit/arqade/catalog/:catalog_id` → `"/tiqit"`
  """
  use QlariusWeb, :live_view

  alias Qlarius.Tiqit.Arcade.Creators
  alias Qlarius.Tiqit.Arcade.Catalog
  alias Qlarius.Tiqit.Arcade.ContentGroup
  alias QlariusWeb.TiqitArqade.Host
  alias QlariusWeb.Widgets.Arcade.Paths

  import QlariusWeb.Helpers.ImageHelpers
  import QlariusWeb.PWAHelpers

  import QlariusWeb.Widgets.Arcade.Components,
    only: [
      arqade_breadcrumbs: 1,
      arqade_page_wrap: 1,
      discovery_item_card: 1,
      discovery_grid_class: 0
    ]

  on_mount {QlariusWeb.DetectMobile, :detect_mobile}

  def mount(%{"catalog_id" => catalog_id}, session, socket) do
    catalog = Creators.get_catalog!(catalog_id)

    groups =
      catalog.content_groups
      |> Enum.filter(fn g -> ContentGroup.has_active_content_pieces?(g.content_pieces) end)
      |> Enum.sort_by(& &1.inserted_at, :desc)
      |> Enum.map(fn g -> %{g | catalog: catalog} end)

    return_to = Paths.catalog("", catalog_id)

    socket =
      socket
      |> init_pwa_assigns(session)
      |> assign(
        catalog: catalog,
        groups: groups,
        base_path: "",
        current_path: return_to,
        title: "Arqade"
      )
      |> maybe_init_tiqit_host(return_to)

    {:ok, socket}
  end

  def handle_params(_params, uri, socket) do
    base_path = Paths.resolve_base_path(uri, socket.assigns[:base_path])
    return_to = Paths.catalog(base_path, socket.assigns.catalog.id)

    socket =
      socket
      |> assign(:base_path, base_path)
      |> assign(:current_path, return_to)
      |> maybe_init_tiqit_host(return_to)

    {:noreply, socket}
  end

  def handle_event("pwa_detected", params, socket) do
    handle_pwa_detection(socket, params)
  end

  def handle_event("referral_code_from_storage", _params, socket) do
    {:noreply, socket}
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
    <div id="catalog-pwa-detect" phx-hook="PWADetect">
      <.arqade_page_wrap base_path={@base_path} wrap_mobile={@base_path == ""} {assigns}>
        <div class={[
          "space-y-6",
          @base_path != "" && "px-4 py-4 overflow-y-auto flex-1 min-h-0"
        ]}>
          <div class="flex items-center gap-4">
            <img
              :if={@catalog.image}
              src={catalog_image_url(@catalog)}
              alt={@catalog.name}
              class="aspect-square w-16 shrink-0 rounded-lg object-cover border border-base-300"
            />
            <div class="min-w-0 flex-1">
              <%= if @base_path == "/widgets" do %>
                <h1 class="text-lg font-bold tracking-tight text-base-content/50 truncate">
                  {@catalog.name}
                </h1>
              <% else %>
                <.arqade_breadcrumbs
                  base_path={@base_path}
                  title={@catalog.name}
                  title_class="text-2xl font-bold text-base-content truncate min-w-0"
                  crumbs={[
                    {@catalog.creator.name, Paths.creator(@base_path, @catalog.creator_id)}
                  ]}
                  current={@catalog.name}
                />
              <% end %>
              <p class="text-sm text-base-content/50 mt-1">
                {length(@groups)} {Catalog.type_label(@catalog.group_type, length(@groups), capitalize: false)}
              </p>
            </div>
          </div>

          <%= if @groups == [] do %>
            <div class="text-center text-base-content/50 py-8">
              No content available in this catalog.
            </div>
          <% else %>
            <div class="flex flex-col gap-3">
              <h2 class="text-lg font-bold tracking-tight text-base-content/50">
                {Catalog.type_label(@catalog.group_type, length(@groups))}
              </h2>
              <div class={discovery_grid_class()}>
                <.discovery_item_card
                  :for={group <- @groups}
                  elevated={@base_path == ""}
                  navigate={Paths.group(@base_path, group.id)}
                  image_src={group_image_url(group)}
                  image_alt={group.title}
                  title={group.title}
                  detail={group_card_detail(group, @catalog)}
                  price_info={group_price_info(group)}
                  piece_type={to_string(@catalog.piece_type)}
                />
              </div>
            </div>
          <% end %>
        </div>
      </.arqade_page_wrap>
    </div>
    """
  end

  defp maybe_init_tiqit_host(socket, return_to) do
    if socket.assigns[:base_path] == "/tiqit" do
      Host.init_creator_scope(socket, socket.assigns.catalog.creator, return_to)
    else
      socket
    end
  end

  defp group_card_detail(group, catalog) do
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
