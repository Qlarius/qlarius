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
  alias Qlarius.Tiqit.ContentAudiences
  alias Qlarius.Tiqit.ContentEngagement
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

  import QlariusWeb.WhyYouPanel, only: [content_details_overlay: 1]

  on_mount {QlariusWeb.DetectMobile, :detect_mobile}

  def mount(_params, session, socket) do
    scope = socket.assigns[:current_scope]

    socket =
      socket
      |> init_pwa_assigns(session)
      |> assign(
        base_path: "",
        current_path: Paths.discover(""),
        title: "Arqade",
        display_mode: "tile",
        show_discovery_view_menu: false,
        show_why_you?: false,
        why_you: nil,
        content_details: nil,
        right_sidebar_panel: nil,
        right_sidebar_title: "Transaction Details"
      )
      |> assign_async(:feed, fn ->
        {:ok, %{feed: Arcade.list_discovery_feed(scope)}}
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
    {:noreply,
     assign(socket, :show_discovery_view_menu, !socket.assigns.show_discovery_view_menu)}
  end

  def handle_event("hide_discovery_view_menu", _params, socket) do
    {:noreply, assign(socket, :show_discovery_view_menu, false)}
  end

  def handle_event("discovery_click", params, socket) do
    _ = ContentEngagement.record_discovery_click(socket.assigns.current_scope, click_attrs(params))
    {:noreply, socket}
  rescue
    _ -> {:noreply, socket}
  end

  def handle_event("open_why_you", %{"kind" => kind, "id" => id}, socket) do
    card =
      socket.assigns.feed
      |> feed_cards()
      |> find_card(kind, id)

    {:noreply,
     assign(socket,
       show_why_you?: socket.assigns.base_path != "",
       why_you: why_you_for_card(card),
       content_details: content_details_for_card(card),
       right_sidebar_panel: :content,
       right_sidebar_title: "Content Details"
     )}
  end

  def handle_event("close_why_you", _params, socket) do
    {:noreply,
     assign(socket,
       show_why_you?: false,
       why_you: nil,
       content_details: nil,
       right_sidebar_panel: nil,
       right_sidebar_title: "Transaction Details"
     )}
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
      <.content_details_overlay
        :if={@base_path != ""}
        show={@show_why_you?}
        why_you={@why_you}
        content={@content_details}
      />

      <.arqade_page_wrap base_path={@base_path} wrap_mobile={@base_path == ""} {assigns}>
        <div class={[
          "flex flex-col gap-6 pb-2",
          @base_path == "/tiqit" && "overflow-y-auto flex-1 min-h-0 px-4 py-4"
        ]}>

          <.async_result :let={feed} assign={@feed}>
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

            <%= if feed.picked == [] and feed.more == [] do %>
              <div class="text-center text-base-content/50 py-12">
                No content available yet. Check back soon.
              </div>
            <% else %>
              <section :if={feed.picked != []} class="flex flex-col gap-3">
                <h2 class="text-lg font-semibold">Picked for you</h2>
                <div class={discovery_grid_class(@display_mode)}>
                  <.discovery_item_card
                    :for={card <- feed.picked}
                    elevated={@base_path == ""}
                    display_mode={@display_mode}
                    navigate={card_navigate(@base_path, card)}
                    image_src={card_image(card)}
                    image_alt={card_title(card)}
                    title={card_title(card)}
                    subtitle={card_subtitle(card)}
                    detail={card_detail(card)}
                    price_info={card_price(card)}
                    piece_type={card_piece_type(card)}
                    click_rest={card_click_rest(card, :picked_for_you)}
                    why_you_kind={to_string(card.kind)}
                    why_you_id={to_string(card.item.id)}
                    why_you_label={ContentAudiences.why_you_label(card.resolve)}
                    why_you_sidebar?={@base_path == ""}
                  />
                </div>
              </section>

              <section :if={feed.more != []} class="flex flex-col gap-3">
                <h2 :if={feed.picked != []} class="text-lg font-semibold">More from creators</h2>
                <div class={discovery_grid_class(@display_mode)}>
                  <.discovery_item_card
                    :for={card <- feed.more}
                    elevated={@base_path == ""}
                    display_mode={@display_mode}
                    navigate={card_navigate(@base_path, card)}
                    image_src={card_image(card)}
                    image_alt={card_title(card)}
                    title={card_title(card)}
                    subtitle={card_subtitle(card)}
                    detail={card_detail(card)}
                    price_info={card_price(card)}
                    piece_type={card_piece_type(card)}
                    click_rest={card_click_rest(card, :more_from_creators)}
                  />
                </div>
              </section>
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

  defp card_click_rest(card, surface) do
    %{
      "phx-click" => "discovery_click",
      "phx-value-surface" => to_string(surface),
      "phx-value-kind" => to_string(card.kind),
      "phx-value-id" => to_string(card.item.id),
      "phx-value-band-id" => optional_id(card.resolve, :band_id),
      "phx-value-target-id" => optional_id(card.resolve, :target_id)
    }
  end

  defp optional_id(%{boost_match: match}, key) when is_map(match) do
    case Map.get(match, key) do
      id when is_integer(id) -> to_string(id)
      _ -> ""
    end
  end

  defp optional_id(_, _), do: ""

  defp click_attrs(%{"kind" => kind, "id" => id} = params) do
    surface = String.to_existing_atom(params["surface"] || "direct")
    band_id = parse_optional_int(params["band-id"])
    target_id = parse_optional_int(params["target-id"])

    loaded = load_click_content(kind, id)

    Map.merge(loaded, %{
      surface: surface,
      target_band_id: band_id,
      target_id: target_id,
      boost_level: kind
    })
  end

  defp click_attrs(_), do: %{surface: :direct}

  defp load_click_content("piece", id) do
    piece =
      Arcade.get_content_piece!(id)
      |> Qlarius.Repo.preload(content_group: [catalog: :creator])

    %{
      piece: piece,
      group: piece.content_group,
      catalog: piece.content_group && piece.content_group.catalog,
      creator: piece.content_group && piece.content_group.catalog && piece.content_group.catalog.creator
    }
  end

  defp load_click_content("group", id) do
    group =
      Arcade.get_content_group!(id)
      |> Qlarius.Repo.preload(catalog: :creator)

    %{
      piece: nil,
      group: group,
      catalog: group.catalog,
      creator: group.catalog && group.catalog.creator
    }
  end

  defp load_click_content(_, _), do: %{}

  defp parse_optional_int(nil), do: nil
  defp parse_optional_int(""), do: nil

  defp parse_optional_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp card_navigate(base_path, %{kind: :group, item: group}),
    do: Paths.group(base_path, group.id)

  defp card_navigate(base_path, %{kind: :piece, item: piece}),
    do: Paths.piece(base_path, piece.id)

  defp card_image(%{kind: :group, item: group}), do: group_image_url(group)

  defp card_image(%{kind: :piece, item: piece}),
    do: content_image_url(piece, piece.content_group)

  defp card_title(%{kind: :group, item: group}), do: group.title
  defp card_title(%{kind: :piece, item: piece}), do: piece.title

  defp card_subtitle(%{kind: :group, item: group}), do: group.catalog.creator.name

  defp card_subtitle(%{kind: :piece, item: piece}),
    do: piece.content_group.title

  defp card_detail(%{kind: :group, item: group}), do: group_card_detail(group)

  defp card_detail(%{kind: :piece, item: piece}),
    do: piece.content_group.catalog.creator.name

  defp feed_cards(%Phoenix.LiveView.AsyncResult{ok?: true, result: %{feed: feed}}) do
    (feed.picked || []) ++ (feed.more || [])
  end

  defp feed_cards(%Phoenix.LiveView.AsyncResult{ok?: true, result: feed})
       when is_map(feed) do
    (Map.get(feed, :picked) || []) ++ (Map.get(feed, :more) || [])
  end

  defp feed_cards(_), do: []

  defp find_card(cards, kind, id) do
    id = String.to_integer(id)
    kind = String.to_existing_atom(kind)
    Enum.find(cards, &(&1.kind == kind and &1.item.id == id))
  end

  defp why_you_for_card(nil), do: nil

  defp why_you_for_card(%{item: item, resolve: resolve}) do
    ContentAudiences.why_you_from_resolve(resolve, ContentAudiences.ancestry_for(item))
  end

  defp content_details_for_card(nil), do: nil

  defp content_details_for_card(card) do
    %{
      title: card_title(card),
      subtitle: card_subtitle(card),
      image_src: card_image(card),
      detail: card_detail(card),
      price_info: card_price(card)
    }
  end

  defp card_price(%{kind: :group, item: group}), do: group_price_info(group)
  defp card_price(%{kind: :piece, item: piece}), do: piece_price_info(piece)

  defp card_piece_type(%{kind: :group, item: group}), do: to_string(group.catalog.piece_type)

  defp card_piece_type(%{kind: :piece, item: piece}),
    do: to_string(piece.content_group.catalog.piece_type)

  defp group_card_detail(group) do
    catalog = group.catalog
    count = length(ContentGroup.active_content_pieces(group.content_pieces))

    "#{count} #{Catalog.type_label(catalog.piece_type, count, capitalize: false)}"
  end

  defp piece_price_info(piece) do
    classes = Enum.filter(piece.tiqit_classes || [], & &1.active)

    case classes do
      [] ->
        nil

      list ->
        prices = Enum.map(list, & &1.price)
        paid = Enum.reject(prices, &Decimal.eq?(&1, 0))
        %{min_price: if(paid != [], do: "$#{Enum.min(paid)}"), free_count: 0}
    end
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
