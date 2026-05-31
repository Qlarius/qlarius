defmodule QlariusWeb.Widgets.Arcade.ArqadeCreatorLive do
  @moduledoc """
  Creator-scoped discovery — catalogs and featured groups for one creator.

  Mounted at `/arqade/creator/:creator_id` (mobile) and
  `/tiqit/arqade/creator/:creator_id` (Tiqit public host).
  """
  use QlariusWeb, :live_view

  alias Qlarius.Creators
  alias Qlarius.Tiqit.Arcade.Arcade
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
      discovery_grid_class: 1,
      discovery_view_toolbar: 1
    ]

  on_mount {QlariusWeb.DetectMobile, :detect_mobile}

  def mount(%{"creator_id" => creator_id}, session, socket) do
    creator = Creators.get_creator!(creator_id)
    catalogs = Arcade.list_discoverable_catalogs_by_creator(creator.id)
    groups = Arcade.list_discoverable_groups_by_creator(creator.id)

    return_to = Paths.creator("", creator.id)
    current_path = return_to

    socket =
      socket
      |> init_pwa_assigns(session)
      |> assign(
        creator: creator,
        catalogs: catalogs,
        groups: groups,
        base_path: "",
        current_path: current_path,
        title: "Arqade",
        display_mode: "tile",
        show_discovery_view_menu: false
      )
      |> maybe_init_tiqit_host(return_to)

    {:ok, socket}
  end

  def handle_params(_params, uri, socket) do
    base_path = Paths.resolve_base_path(uri, socket.assigns[:base_path])
    return_to = Paths.creator(base_path, socket.assigns.creator.id)

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
    <div id="creator-pwa-detect" phx-hook="PWADetect">
      <.arqade_page_wrap base_path={@base_path} wrap_mobile={@base_path == ""} {assigns}>
        <div class={[
          "flex flex-col gap-6 pb-2 overflow-y-auto flex-1 min-h-0 px-4 py-4",
          @base_path == "/tiqit" && "px-4 py-4"
        ]}>
          <div class="flex items-center gap-4">
            <img
              :if={@creator.image}
              src={creator_image_url(@creator)}
              alt={@creator.name}
              class="aspect-square w-16 shrink-0 rounded-lg object-cover border border-base-300"
            />
            <div class="min-w-0 flex-1">
              <.arqade_breadcrumbs
                base_path={@base_path}
                title={@creator.name}
                title_class="text-2xl font-bold text-base-content truncate min-w-0"
                crumbs={[]}
                current={@creator.name}
              />
              <p :if={String.trim(@creator.bio || "") != ""} class="text-sm text-base-content/60 mt-2 line-clamp-5">
                {String.trim(@creator.bio)}
              </p>
            </div>
          </div>

          <%= if @catalogs == [] && @groups == [] do %>
            <div class="text-center text-base-content/50 py-12">
              No content available from this creator yet.
            </div>
          <% else %>
            <div :if={@catalogs != []} class="flex flex-col gap-3">
              <h2 class="text-lg font-bold tracking-tight text-base-content/50">Catalogs</h2>
              <div class={discovery_grid_class(@display_mode)}>
                <.discovery_item_card
                  :for={catalog <- @catalogs}
                  elevated={@base_path == ""}
                  display_mode={@display_mode}
                  navigate={Paths.catalog(@base_path, catalog.id)}
                  image_src={catalog_image_url(catalog)}
                  image_alt={catalog.name}
                  title={catalog.name}
                  subtitle={@creator.name}
                  detail={catalog_summary(catalog)}
                  price_info={catalog_price_info(catalog)}
                  piece_type={to_string(catalog.piece_type)}
                />
              </div>
            </div>

            <div :if={@groups != []} class="flex flex-col gap-3">
              <h2 class="text-lg font-bold tracking-tight text-base-content/50">Featured</h2>
              <div class={discovery_grid_class(@display_mode)}>
                <.discovery_item_card
                  :for={group <- @groups}
                  elevated={@base_path == ""}
                  display_mode={@display_mode}
                  navigate={Paths.group(@base_path, group.id)}
                  image_src={group_image_url(group)}
                  image_alt={group.title}
                  title={group.title}
                  subtitle={"#{@creator.name} › #{group.catalog.name}"}
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
      </.arqade_page_wrap>
    </div>
    """
  end

  defp maybe_init_tiqit_host(socket, return_to) do
    if socket.assigns[:base_path] == "/tiqit" do
      Host.init_creator_scope(socket, socket.assigns.creator, return_to)
    else
      socket
    end
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
