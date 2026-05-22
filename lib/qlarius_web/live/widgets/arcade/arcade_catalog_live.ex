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
  alias Qlarius.Tiqit.Arcade.ContentGroup
  alias QlariusWeb.Layouts

  import QlariusWeb.Helpers.ImageHelpers
  import QlariusWeb.PWAHelpers
  import QlariusWeb.Widgets.Arcade.Components,
    only: [arqade_breadcrumbs: 1, discovery_item_card: 1, discovery_grid_class: 0]

  on_mount {QlariusWeb.DetectMobile, :detect_mobile}

  def mount(%{"catalog_id" => catalog_id}, session, socket) do
    catalog = Creators.get_catalog!(catalog_id)

    groups =
      catalog.content_groups
      |> Enum.filter(fn g -> ContentGroup.has_active_content_pieces?(g.content_pieces) end)
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
        <.arqade_breadcrumbs
          base_path={@base_path}
          crumbs={[{@catalog.name, "#{@base_path}/arqade/catalog/#{@catalog.id}"}]}
        />
        <div class="px-4 py-4 space-y-6">
          <div class="flex items-center gap-4">
            <img
              :if={@catalog.image}
              src={catalog_image_url(@catalog)}
              alt={@catalog.name}
              class="aspect-square w-16 shrink-0 rounded-lg object-cover border border-base-300"
            />
            <div class="min-w-0">
              <h1 class="text-lg font-bold tracking-tight text-base-content/50">{@catalog.name}</h1>
              <p class="text-sm text-base-content/50">
                {length(@groups)} {if length(@groups) == 1,
                  do: @catalog.group_type,
                  else: pluralize(@catalog.group_type)}
              </p>
            </div>
          </div>

          <%= if @groups == [] do %>
            <div class="text-center text-base-content/50 py-8">
              No content available in this catalog.
            </div>
          <% else %>
            <div class={discovery_grid_class()}>
              <.discovery_item_card
                :for={group <- @groups}
                navigate={"#{@base_path}/arqade/group/#{group.id}"}
                image_src={group_image_url(group)}
                image_alt={group.title}
                title={group.title}
                detail={group_card_detail(group, @catalog)}
                price_info={group_price_info(group)}
                piece_type={to_string(@catalog.piece_type)}
              />
            </div>
          <% end %>
        </div>
      </Layouts.maybe_mobile>
    </div>
    """
  end

  defp group_card_detail(group, catalog) do
    count = length(ContentGroup.active_content_pieces(group.content_pieces))
    label = catalog.piece_type |> to_string()

    "#{count} #{if count == 1, do: label, else: pluralize_piece_type(label)}"
  end

  defp pluralize_piece_type("series"), do: "series"
  defp pluralize_piece_type("class"), do: "classes"
  defp pluralize_piece_type(label), do: label <> "s"

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

  defp pluralize(word) do
    word = to_string(word)
    if word == "series", do: "series", else: word <> "s"
  end
end
