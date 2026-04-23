defmodule QlariusWeb.Widgets.Arcade.Components do
  use Phoenix.Component

  alias Qlarius.Tiqit.Arcade.ContentGroup
  alias Qlarius.Tiqit.Arcade.ContentPiece
  alias Qlarius.Tiqit.Arcade.TiqitClass
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
    any_credit = Decimal.gt?(group_credit, 0) or Decimal.gt?(catalog_credit, 0)

    durations =
      [piece, group, catalog]
      |> Enum.flat_map(&for tc <- &1.tiqit_classes, do: tc.duration_hours)
      |> Enum.uniq()
      |> Enum.sort()

    assigns =
      assign(assigns,
        catalog: catalog,
        group_credit: group_credit,
        catalog_credit: catalog_credit,
        any_credit: any_credit,
        durations: durations,
        group: group,
        piece: piece,
        show_group?: Enum.any?(group.tiqit_classes),
        show_catalog?: Enum.any?(catalog.tiqit_classes)
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
                Duration
              </th>
              <th class="w-40 font-semibold text-base-content text-center py-2 px-3 leading-none">
                Single<br />{@catalog.piece_type |> to_string() |> String.capitalize()}
              </th>
              <th
                :if={@show_group?}
                class="w-40 font-semibold text-base-content text-center py-2 px-3 leading-none"
              >
                Entire {@catalog.group_type |> to_string() |> String.capitalize()}<br />
                <span class="text-base-content/40 text-xs mt-0">
                  ({length(@group.content_pieces)} {pluralize(length(@group.content_pieces), @catalog.piece_type)})
                </span>
              </th>
              <th
                :if={@show_catalog?}
                class="w-40 font-semibold text-base-content text-center py-2 px-3 leading-none"
              >
                Entire {@catalog.type |> to_string() |> String.capitalize()}<br />
                <span class="text-base-content/40 text-xs mt-0">
                  ({length(@catalog.content_groups)} {pluralize(length(@catalog.content_groups), @catalog.group_type)})
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
        <%= if @any_credit do %>
          <div class="alert bg-primary/20 border-primary/30 py-2 px-4 rounded-lg flex flex-col items-center gap-2 mt-4 justify-center text-center">
            <div class="flex items-center justify-center gap-2 w-full">
              <.icon name="hero-arrow-trending-up" class="w-5 h-5 text-primary shrink-0" />
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
          class="btn btn-sm rounded-full btn-primary px-4 cursor-pointer"
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
              class="btn btn-sm rounded-full btn-primary px-4 cursor-pointer"
            >
              {format_usd(@adjusted)}
            </button>
          </div>
        <% else %>
          <div class="flex flex-col items-center gap-0.5">
            <span class="text-xs text-base-content/40 line-through">{format_usd(@original)}</span>
            <div class="btn btn-sm rounded-full !bg-primary/50 !border-primary/50 text-white px-4 !cursor-not-allowed">
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
        class="btn btn-sm rounded-full btn-primary px-3 py-1 cursor-pointer"
      >
        {format_usd(@tiqit_class.price, zero_free: true)}
      </button>
    <% else %>
      <div class="btn btn-sm rounded-full !bg-primary/50 !border-primary/50 text-white px-3 py-1 !cursor-not-allowed">
        {format_usd(@tiqit_class.price, zero_free: true)}
      </div>
    <% end %>
    """
  end

  attr :balance, Decimal, required: true
  attr :offered_amount, Decimal, default: nil
  attr :ads_count, :integer, default: 0
  attr :id, :string, default: "wallet-balance-arcade-strip"

  def wallet_strip(assigns) do
    ~H"""
    <div class="w-fit mx-auto text-base-content bg-base-200 border-t border-base-300 px-3 py-2 rounded-lg border-1 border-base-300">
      <div class="flex flex-row flex-wrap justify-between items-center space-x-4">
        <div class="flex flex-row items-center justify-center">
          <.wallet_balance id={@id} balance={@balance} />
          <span class="font-normal text-base-content/60 ml-2 mr-3">to spend</span>
        </div>

        <.popover id={"#{@id}-topup"} placement="top" trigger_type="click" class="w-56">
          <:trigger>
            <button class="btn btn-md rounded-full !bg-sponster-400 hover:!bg-sponster-600 text-white !border-sponster-400 hover:!border-sponster-600 leading-none">
              <.icon name="hero-plus" class="w-4 h-4 mr-0" />
              <span class="font-bold">{if @offered_amount, do: format_usd(@offered_amount), else: "$0.00"}</span>
            </button>
          </:trigger>
          <:content>
            <div class="p-3 space-y-2">
              <p class="text-xs font-semibold text-base-content/60 uppercase tracking-wide">Top up wallet</p>
              <button
                class="btn btn-sm btn-block justify-start gap-2 !bg-sponster-500 hover:!bg-sponster-600 text-white border-none rounded-lg"
                onclick="parent.postMessage('open_widget','*');"
              >
                <img src="/images/Sponster_logo_white_horiz.svg" alt="Sponster" class="h-4" onerror="this.style.display='none';this.nextElementSibling.style.display='inline';" />
                <span style="display:none;">Sponster</span>
                <span class="ml-auto text-xs opacity-80">{@ads_count} ads • {if @offered_amount, do: format_usd(@offered_amount), else: "$0.00"}</span>
              </button>
              <button
                class="btn btn-sm btn-block justify-start gap-2 btn-primary rounded-lg"
                phx-click="topup"
              >
                <.icon name="hero-gift" class="w-4 h-4" />
                Daily gift
                <span class="ml-auto text-xs opacity-80">$0.50</span>
              </button>
              <button
                class="btn btn-sm btn-block justify-start gap-2 btn-outline rounded-lg"
                phx-click="topup"
              >
                <.icon name="hero-credit-card" class="w-4 h-4" />
                Credit / Debit
              </button>
            </div>
          </:content>
        </.popover>
      </div>
    </div>
    """
  end

  @doc """
  Breadcrumb trail for arqade content hierarchy.

  Hidden in widget context (@base_path == "/widgets") since embedded iframes
  don't benefit from hierarchical navigation — the host page controls that.
  In-app, renders a compact clickable trail rooted at "Discover".
  """
  attr :crumbs, :list, default: []
  attr :base_path, :string, default: ""

  def arqade_breadcrumbs(assigns) do
    ~H"""
    <nav :if={@base_path != "/widgets"} class="text-xs text-base-content/50 flex items-center gap-1 flex-wrap pt-3 mb-3">
      <.link navigate="/arqade" class="hover:text-primary transition-colors">Discover</.link>
      <span :for={{label, path} <- @crumbs} class="flex items-center gap-1">
        <span class="text-base-content/30">›</span>
        <.link navigate={path} class="hover:text-primary transition-colors truncate max-w-[120px]">{label}</.link>
      </span>
    </nav>
    """
  end
end
