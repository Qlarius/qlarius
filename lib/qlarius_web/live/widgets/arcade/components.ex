defmodule QlariusWeb.Widgets.Arcade.Components do
  use Phoenix.Component

  alias Qlarius.Tiqit.Arcade.ContentGroup
  alias Qlarius.Tiqit.Arcade.ContentPiece
  alias Qlarius.Tiqit.Arcade.TiqitClass
  alias Qlarius.Wallets
  import QlariusWeb.CoreComponents
  import QlariusWeb.Money
  import QlariusWeb.TiqitClassHTML
  import QlariusWeb.Components.CustomComponentsMobile

  defp pluralize(count, word) do
    word_str = to_string(word)

    if count == 1 do
      word_str
    else
      case word_str do
        "series" -> "series"
        "episode" -> "episodes"
        "piece" -> "pieces"
        w -> w <> "s"
      end
    end
  end

  # `balance` is `nil` for unauthenticated viewers — the grid still
  # renders fully so anon users can browse all Tiqit options; the
  # `select-tiqit-class` LV event is intercepted server-side for
  # unauth and opens the Connect-wallet modal instead.
  attr :balance, :any, required: true
  attr :piece, ContentPiece, required: true
  attr :group, ContentGroup, required: true
  attr :tiqit_up_group_credit, :any, default: nil
  attr :tiqit_up_catalog_credit, :any, default: nil

  def tiqit_class_grid(assigns) do
    piece = assigns.piece
    group = assigns.group
    catalog = group.catalog
    group_credit = assigns.tiqit_up_group_credit || Decimal.new(0)
    catalog_credit = assigns.tiqit_up_catalog_credit || Decimal.new(0)

    durations =
      [piece, group, catalog]
      |> Enum.flat_map(&for tc <- &1.tiqit_classes, do: tc.duration_hours)
      |> Enum.uniq()
      |> Enum.sort()

    show_group? = Enum.any?(group.tiqit_classes)
    show_catalog? = Enum.any?(catalog.tiqit_classes)

    show_discount_notice? =
      (show_group? and Decimal.gt?(group_credit, 0)) or
        (show_catalog? and Decimal.gt?(catalog_credit, 0))

    assigns =
      assign(assigns,
        catalog: catalog,
        group_credit: group_credit,
        catalog_credit: catalog_credit,
        show_discount_notice?: show_discount_notice?,
        durations: durations,
        group: group,
        piece: piece,
        show_group?: show_group?,
        show_catalog?: show_catalog?
      )

    ~H"""
    <div class="flex justify-center">
      <div class="overflow-x-auto w-full max-w-4xl">
        <table class="table table-compact !w-auto inline-table mx-auto table-fixed">
          <colgroup>
            <col class="w-40" />
            <col class="w-40" />
            <col :if={@show_group?} class="w-40" />
            <col :if={@show_catalog?} class="w-40" />
          </colgroup>
          <thead class="bg-base-200">
            <tr>
              <th class="w-40 font-semibold text-base-content text-right py-2 px-3 whitespace-nowrap">
              </th>
              <th class="w-40 font-semibold text-base-content text-center py-2 px-3 leading-none">
                This<br />{@catalog.piece_type |> to_string() |> String.capitalize()}
              </th>
              <th
                :if={@show_group?}
                class="w-40 font-semibold text-base-content text-center py-2 px-3 leading-none"
              >
                Entire {@catalog.group_type |> to_string() |> String.capitalize()}<br />
                <span class="text-base-content/40 text-xs mt-0">
                  ({length(@group.content_pieces)} {pluralize(
                    length(@group.content_pieces),
                    @catalog.piece_type
                  )})
                </span>
              </th>
              <th
                :if={@show_catalog?}
                class="w-40 font-semibold text-base-content text-center py-2 px-3 leading-none"
              >
                Entire {@catalog.type |> to_string() |> String.capitalize()}<br />
                <span class="text-base-content/40 text-xs mt-0">
                  ({length(@catalog.content_groups)} {pluralize(
                    length(@catalog.content_groups),
                    @catalog.group_type
                  )})
                </span>
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-base-300">
            <tr :for={duration <- @durations}>
              <td class="font-bold text-base-content text-right p-3 whitespace-nowrap">
                {format_tiqit_class_duration(duration)}
                <.icon name="hero-arrow-right" class="w-4 h-4 ml-1 text-base-content/60" />
              </td>
              <td class="w-40 text-center py-1 px-3">
                <%= if class = Enum.find(@piece.tiqit_classes, & &1.duration_hours == duration) do %>
                  <div class="flex justify-center">
                    <.tiqit_class_grid_price balance={@balance} tiqit_class={class} />
                  </div>
                <% else %>
                  <span class="text-base-content/40 text-sm">-</span>
                <% end %>
              </td>
              <%= if @show_group? do %>
                <td class="w-40 text-center py-1 px-3">
                  <%= if class = Enum.find(@group.tiqit_classes, & &1.duration_hours == duration) do %>
                    <div class="flex justify-center">
                      <.tiqit_class_grid_price_with_credit
                        balance={@balance}
                        tiqit_class={class}
                        credit={@group_credit}
                      />
                    </div>
                  <% else %>
                    <span class="text-base-content/40 text-sm">-</span>
                  <% end %>
                </td>
              <% end %>
              <%= if @show_catalog? do %>
                <td class="w-40 text-center py-1 px-3">
                  <%= if class = Enum.find(@catalog.tiqit_classes, & &1.duration_hours == duration) do %>
                    <div class="flex justify-center">
                      <.tiqit_class_grid_price_with_credit
                        balance={@balance}
                        tiqit_class={class}
                        credit={@catalog_credit}
                      />
                    </div>
                  <% else %>
                    <span class="text-base-content/40 text-sm">-</span>
                  <% end %>
                </td>
              <% end %>
            </tr>
          </tbody>
        </table>
        <%= if @show_discount_notice? do %>
          <div class="alert bg-widget-100 border-widget-300 py-2 px-4 rounded-lg flex flex-col items-center gap-2 mt-4 justify-center text-center">
            <div class="flex items-center justify-center gap-2 w-full">
              <.icon name="hero-arrow-trending-up" class="w-5 h-5 text-widget-700 shrink-0" />
              <span class="text-sm font-medium text-base-content">
                TiqitUp discounts applied to credit active tiqits
              </span>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  attr :tiqit_class, TiqitClass, required: true
  attr :balance, :any, required: true
  attr :credit, :any, required: true

  def tiqit_class_grid_price_with_credit(assigns) do
    credit = assigns.credit
    original = assigns.tiqit_class.price
    adjusted = Decimal.max(Decimal.new(0), Decimal.sub(original, credit))
    has_credit = Decimal.compare(credit, Decimal.new(0)) == :gt

    assigns =
      assign(assigns,
        adjusted: adjusted,
        has_credit: has_credit,
        is_free: Decimal.compare(adjusted, Decimal.new(0)) != :gt,
        original: original
      )

    ~H"""
    <%= if @is_free and @has_credit do %>
      <div class="flex flex-col items-center gap-0.5">
        <span class="text-xs text-base-content/40 line-through">{format_usd(@original)}</span>
        <button
          phx-click="select-tiqit-class"
          phx-value-tiqit-class-id={@tiqit_class.id}
          class="btn-widget btn-sm rounded-full px-4 cursor-pointer"
        >
          Free!
        </button>
      </div>
    <% else %>
      <%= if @has_credit do %>
        <%= if Decimal.compare(@balance, @adjusted) != :lt do %>
          <div class="flex flex-col items-center gap-0.5">
            <span class="text-xs text-base-content/40 line-through">{format_usd(@original)}</span>
            <button
              phx-click="select-tiqit-class"
              phx-value-tiqit-class-id={@tiqit_class.id}
              class="btn-widget btn-sm rounded-full px-4 cursor-pointer"
            >
              {format_usd(@adjusted)}
            </button>
          </div>
        <% else %>
          <div class="flex flex-col items-center gap-0.5">
            <span class="text-xs text-base-content/40 line-through">{format_usd(@original)}</span>
            <div class="btn-widget btn-sm btn-disabled rounded-full px-4">
              {format_usd(@adjusted)}
            </div>
          </div>
        <% end %>
      <% else %>
        <.tiqit_class_grid_price balance={@balance} tiqit_class={@tiqit_class} />
      <% end %>
    <% end %>
    """
  end

  # Balance is `nil` when the viewer is anonymous (no current scope).
  # In that case we render the grid chips as fully clickable — the
  # LV's `select-tiqit-class` handler intercepts unauth clicks and
  # opens the Connect-wallet modal instead of the purchase flow.
  attr :tiqit_class, TiqitClass, required: true
  attr :balance, :any, required: true

  def tiqit_class_grid_price(assigns) do
    ~H"""
    <%= if is_nil(@balance) or Decimal.compare(@balance, @tiqit_class.price) != :lt do %>
      <button
        phx-click="select-tiqit-class"
        phx-value-tiqit-class-id={@tiqit_class.id}
        class="btn-widget btn-sm rounded-full px-3 py-1 cursor-pointer"
      >
        {format_usd(@tiqit_class.price, zero_free: true)}
      </button>
    <% else %>
      <div class="btn-widget btn-sm btn-disabled rounded-full px-3 py-1">
        {format_usd(@tiqit_class.price, zero_free: true)}
      </div>
    <% end %>
    """
  end

  attr :balance, Decimal, required: true
  attr :offered_amount, Decimal, default: nil
  attr :ads_count, :integer, default: 0
  attr :id, :string, default: "wallet-balance-arcade-strip"
  attr :daily_gift_available?, :boolean, default: true

  def wallet_strip(assigns) do
    topup_total =
      topup_offer_total(assigns.offered_amount, assigns.daily_gift_available?)

    ads_n =
      case assigns.ads_count do
        n when is_integer(n) and n >= 0 -> n
        _ -> 0
      end

    assigns =
      assigns
      |> assign(:topup_total, topup_total)
      |> assign(:topup_funds_available?, Decimal.gt?(topup_total, 0))
      |> assign(:topup_button_label, topup_button_label(topup_total))
      |> assign(:sponster_ads_available?, ads_n > 0)

    ~H"""
    <div class="wallet-strip-tray">
      <div class="wallet-strip-tray__row">
        <.wallet_balance id={@id} balance={@balance} footer_label="WALLET" />

        <.popover
          id={"#{@id}-topup"}
          placement="top"
          position_strategy="fixed"
          trigger_type="click"
          use_floating_size={false}
          class="w-max max-w-[min(28rem,calc(100vw-1.5rem))] min-w-[17rem] px-4 pt-3.5 pb-4 shadow-xl"
        >
          <:trigger>
            <button class={[
              "btn-wallet-strip-action btn-md leading-none",
              @topup_funds_available? && "connect-strip-cta-border-strobe"
            ]}>
              <.icon name="hero-plus" class="w-4 h-4 shrink-0" />
              <span class="font-bold">{@topup_button_label}</span>
            </button>
          </:trigger>
          <:content>
            <div class="flex w-full flex-col gap-3">
              <p class="text-xs font-semibold text-widget-600 uppercase tracking-wide text-center">
                Top up wallet
              </p>
              <button
                :if={@sponster_ads_available?}
                type="button"
                id={"#{@id}-sponster-open"}
                class="btn-widget btn-widget-emphasis btn-md btn-block flex min-h-14 w-full flex-row items-center justify-between gap-3 rounded-full px-4 py-3.5"
                phx-hook="WalletTopupOpenSponster"
                data-popover-id={"#{@id}-topup"}
                data-drawer-delay-ms="280"
              >
                <%!-- `Sponster_logo_white_horiz.svg` is not shipped; color horiz is in priv/static/images. --%>
                <img
                  src="/images/Sponster_logo_color_horiz.svg"
                  alt="Sponster"
                  class="h-6 w-auto max-w-[8rem] shrink-0 object-contain object-left"
                  decoding="async"
                />
                <span class="shrink-0 whitespace-nowrap text-end text-sm font-semibold tabular-nums opacity-90">
                  {@ads_count} ads • {if @offered_amount,
                    do: format_usd(@offered_amount),
                    else: "$0.00"}
                </span>
              </button>
              <button
                :if={not @sponster_ads_available?}
                type="button"
                id={"#{@id}-sponster-open-disabled"}
                disabled
                aria-disabled="true"
                title="No ads available right now"
                class="btn-widget btn-widget-emphasis btn-md btn-block flex min-h-14 w-full flex-row items-center justify-between gap-3 rounded-full px-4 py-3.5 btn-disabled cursor-not-allowed opacity-80"
              >
                <img
                  src="/images/Sponster_logo_color_horiz.svg"
                  alt="Sponster"
                  class="h-6 w-auto max-w-[8rem] shrink-0 object-contain object-left opacity-60"
                  decoding="async"
                />
                <span class="shrink-0 whitespace-nowrap text-end text-sm font-semibold tabular-nums opacity-70">
                  {@ads_count} ads • {if @offered_amount,
                    do: format_usd(@offered_amount),
                    else: "$0.00"}
                </span>
              </button>
              <button
                :if={@daily_gift_available?}
                type="button"
                class="btn-widget btn-widget-emphasis btn-md btn-block flex min-h-14 w-full flex-row items-center justify-between gap-3 rounded-full px-4 py-3.5"
                phx-click="daily-gift"
              >
                <span class="flex min-w-0 flex-row items-center gap-2">
                  <.icon name="hero-gift" class="h-6 w-6 shrink-0" />
                  <span class="text-sm font-medium">Daily gift</span>
                </span>
                <span class="shrink-0 text-sm font-semibold tabular-nums opacity-90">$0.50</span>
              </button>
              <button
                :if={not @daily_gift_available?}
                type="button"
                class="btn-widget btn-widget-emphasis btn-md btn-block flex min-h-14 w-full flex-row items-center justify-between gap-3 rounded-full px-4 py-3.5 btn-disabled cursor-not-allowed opacity-80"
                disabled
                title="You can claim again 24 hours after your last daily gift"
              >
                <span class="flex min-w-0 flex-row items-center gap-2">
                  <.icon name="hero-gift" class="h-6 w-6 shrink-0" />
                  <span class="text-sm font-medium">Daily gift</span>
                </span>
                <span class="shrink-0 text-sm font-semibold tabular-nums opacity-90">$0.50</span>
              </button>
              <button
                type="button"
                disabled
                aria-disabled="true"
                title="Coming soon"
                class="btn-widget btn-md btn-block flex min-h-14 w-full flex-row items-center gap-3 rounded-full px-4 py-3.5 btn-disabled cursor-not-allowed opacity-70"
              >
                <.icon name="hero-credit-card" class="h-6 w-6 shrink-0" />
                <span class="text-sm font-medium">Credit / Debit</span>
              </button>
            </div>
          </:content>
        </.popover>
      </div>
    </div>
    """
  end

  defp topup_offer_total(offered_amount, daily_gift_available?) do
    ads =
      case offered_amount do
        %Decimal{} = d -> d
        _ -> Decimal.new(0)
      end

    gift = if daily_gift_available?, do: Wallets.daily_gift_amount(), else: Decimal.new(0)
    Decimal.add(ads, gift)
  end

  defp topup_button_label(%Decimal{} = total) do
    if Decimal.gt?(total, 0), do: format_usd(total), else: "Top up"
  end

  @doc """
  Responsive grid/list container for Arqade discovery/catalog browse cards.
  """
  def discovery_grid_class(display_mode \\ "tile")

  def discovery_grid_class("list"), do: "flex flex-col gap-2"

  def discovery_grid_class("tile") do
    "grid grid-cols-2 sm:grid-cols-2 md:grid-cols-3 xl:grid-cols-4 gap-2 sm:gap-3"
  end

  attr :display_mode, :string, required: true
  attr :class, :string, default: ""

  def discovery_view_mode_menu(assigns) do
    ~H"""
    <div
      class={[
        "rounded-2xl border border-base-300 bg-base-100 dark:bg-base-200 shadow-lg p-2 flex flex-row gap-1 shrink-0",
        @class
      ]}
      role="menu"
      aria-label="Discovery display mode"
    >
      <button
        :for={mode <- ~w(tile list)}
        type="button"
        phx-click="set_discovery_display_mode"
        phx-value-mode={mode}
        class={[
          "btn btn-sm btn-square btn-ghost",
          @display_mode == mode && "bg-youdata-300/50 dark:bg-youdata-800/50"
        ]}
        aria-label={discovery_display_mode_label(mode)}
        aria-current={@display_mode == mode && "true"}
        role="menuitem"
      >
        <.icon name={discovery_display_mode_icon(mode)} class="h-5 w-5" />
      </button>
    </div>
    """
  end

  attr :display_mode, :string, required: true
  attr :show_view_menu, :boolean, default: false

  def discovery_view_toolbar(assigns) do
    ~H"""
    <div
      id="discovery-view-toolbar"
      class="fixed right-4 z-40 max-w-[calc(100vw-2rem)] pointer-events-none bottom-[calc(var(--mobile-bottom-nav-offset,5.25rem)+0.75rem)]"
    >
      <div
        id="discovery-view-toolbar-inner"
        phx-click-away={@show_view_menu && "hide_discovery_view_menu"}
        class="flex flex-col items-end gap-2 pointer-events-auto"
      >
        <.discovery_view_mode_menu
          :if={@show_view_menu}
          display_mode={@display_mode}
        />

        <button
          type="button"
          phx-click="toggle_discovery_view_menu"
          class={discovery_fab_class(@show_view_menu)}
          aria-label={"View: #{discovery_display_mode_label(@display_mode)}"}
          aria-expanded={to_string(@show_view_menu)}
        >
          <.icon name={discovery_display_mode_icon(@display_mode)} class="h-5 w-5" />
        </button>
      </div>
    </div>
    """
  end

  attr :navigate, :string, required: true
  attr :image_src, :string, required: true
  attr :image_alt, :string, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :detail, :string, default: nil
  attr :price_info, :map, default: nil
  attr :piece_type, :string, default: nil
  attr :display_mode, :string, default: "tile", values: ~w(tile list)

  @doc """
  Browse card for Arqade catalogs and content groups (matches /home and /me_file group shells).
  """
  def discovery_item_card(%{display_mode: "list"} = assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "group flex flex-row items-stretch gap-3 rounded-lg bg-base-200/50 dark:bg-black shadow-sm overflow-hidden",
        "border border-base-300/60 dark:border-base-content/10",
        "transition-shadow duration-200 hover:shadow-md p-2 sm:p-2.5 min-h-[4.5rem]"
      ]}
    >
      <img
        src={@image_src}
        alt={@image_alt}
        class="h-16 w-16 sm:h-[4.5rem] sm:w-[4.5rem] shrink-0 rounded-md object-cover bg-base-300/40 dark:bg-base-700/40"
      />
      <div class="min-w-0 flex flex-1 flex-col justify-center gap-0.5">
        <h3 class="font-bold text-sm text-base-content leading-snug line-clamp-2">{@title}</h3>
        <p :if={@subtitle} class="text-xs text-base-content/60 truncate">{@subtitle}</p>
        <p :if={@detail} class="text-[11px] text-base-content/50 leading-snug line-clamp-1">{@detail}</p>
        <div :if={@price_info} class="text-[11px] font-medium pt-0.5">
          <span :if={@price_info.min_price} class="text-widget-700">
            from {@price_info.min_price}
          </span>
          <span
            :if={@price_info.min_price && @price_info.free_count > 0}
            class="text-base-content/50"
          >
            ·
          </span>
          <span :if={@price_info.free_count > 0} class="text-base-content/50">
            Includes {@price_info.free_count} FREE {pluralize_discovery_piece_label(
              @piece_type,
              @price_info.free_count
            )}
          </span>
        </div>
      </div>
    </.link>
    """
  end

  def discovery_item_card(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "group flex h-full flex-col rounded-lg bg-base-200/50 dark:bg-black shadow-sm overflow-hidden",
        "border-t-2 border-neutral-300 dark:border-neutral-600",
        "transition-shadow duration-200 hover:shadow-md"
      ]}
    >
      <img
        src={@image_src}
        alt={@image_alt}
        class="aspect-[4/3] sm:aspect-square w-full object-cover bg-base-300/40 dark:bg-base-700/40"
      />
      <div class="flex flex-1 flex-col gap-0.5 p-2 sm:p-3 min-w-0">
        <h3 class="font-bold text-sm sm:text-base text-base-content leading-snug line-clamp-2">{@title}</h3>
        <p :if={@subtitle} class="text-xs text-base-content/60 truncate">{@subtitle}</p>
        <p :if={@detail} class="text-[11px] sm:text-xs text-base-content/50 leading-snug line-clamp-2">{@detail}</p>
        <div :if={@price_info} class="text-[11px] sm:text-xs font-medium mt-auto pt-0.5">
          <span :if={@price_info.min_price} class="text-widget-700">
            from {@price_info.min_price}
          </span>
          <span
            :if={@price_info.min_price && @price_info.free_count > 0}
            class="text-base-content/50"
          >
            ·
          </span>
          <span :if={@price_info.free_count > 0} class="text-base-content/50">
            Includes {@price_info.free_count} FREE {pluralize_discovery_piece_label(
              @piece_type,
              @price_info.free_count
            )}
          </span>
        </div>
      </div>
    </.link>
    """
  end

  defp discovery_display_mode_label("tile"), do: "Tiles"
  defp discovery_display_mode_label("list"), do: "List"
  defp discovery_display_mode_label(_), do: "Tiles"

  defp discovery_display_mode_icon("tile"), do: "hero-squares-2x2"
  defp discovery_display_mode_icon("list"), do: "hero-bars-3-bottom-left"
  defp discovery_display_mode_icon(_), do: "hero-squares-2x2"

  defp discovery_fab_class(active?) do
    [
      "btn btn-lg btn-circle shadow-lg border border-base-300",
      "bg-base-100 dark:bg-base-200 text-base-content",
      "hover:bg-base-200 dark:hover:bg-base-300",
      active? && "ring-2 ring-youdata-500/60"
    ]
  end

  defp pluralize_discovery_piece_label(label, 1), do: label || "item"
  defp pluralize_discovery_piece_label("series", _), do: "series"
  defp pluralize_discovery_piece_label("class", _), do: "classes"
  defp pluralize_discovery_piece_label(label, _) when is_binary(label), do: label <> "s"
  defp pluralize_discovery_piece_label(_, _), do: "items"

  @doc """
  Breadcrumb trail for arqade content hierarchy.

  Hidden in widget context (@base_path == "/widgets") since embedded iframes
  don't benefit from hierarchical navigation — the host page controls that.
  In-app, renders a compact clickable trail rooted at "Discover".
  """
  attr :crumbs, :list, default: []
  attr :base_path, :string, default: ""
  attr :compact, :boolean, default: false

  def arqade_breadcrumbs(assigns) do
    ~H"""
    <nav
      :if={@base_path != "/widgets"}
      class={[
        "shrink-0 text-xs text-base-content/50 flex items-center gap-1 flex-wrap pt-0 mb-1"
      ]}
    >
      <.link navigate="/arqade" class="hover:text-widget-700 transition-colors">Discover</.link>
      <span :for={{label, path} <- @crumbs} class="flex items-center gap-1">
        <span class="text-base-content/30">›</span>
        <.link navigate={path} class="hover:text-widget-700 transition-colors truncate max-w-[120px]">
          {label}
        </.link>
      </span>
    </nav>
    """
  end
end
