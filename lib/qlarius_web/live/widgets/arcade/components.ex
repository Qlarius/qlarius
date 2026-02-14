defmodule QlariusWeb.Widgets.Arcade.Components do
  use Phoenix.Component

  alias Qlarius.Tiqit.Arcade.ContentGroup
  alias Qlarius.Tiqit.Arcade.ContentPiece
  alias Qlarius.Tiqit.Arcade.TiqitClass
  alias Phoenix.LiveView.JS

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

  attr :balance, Decimal, required: true
  attr :piece, ContentPiece, required: true
  attr :group, ContentGroup, required: true

  def tiqit_class_grid(assigns) do
    piece = assigns.piece
    group = assigns.group
    catalog = group.catalog

    durations =
      [piece, group, catalog]
      |> Enum.flat_map(&for tc <- &1.tiqit_classes, do: tc.duration_hours)
      |> Enum.uniq()
      |> Enum.sort()

    assigns =
      assign(assigns,
        catalog: catalog,
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
              <%= for {col, true} <- [{@piece, true}, {@group, @show_group?}, {@catalog, @show_catalog?}] do %>
                <td class="w-40 text-center py-1 px-3">
                  <%= if class = Enum.find(col.tiqit_classes, & &1.duration_hours == duration) do %>
                    <div class="flex justify-center">
                      <.tiqit_class_grid_price balance={@balance} tiqit_class={class} />
                    </div>
                  <% else %>
                    <span class="text-base-content/40 text-sm">-</span>
                  <% end %>
                </td>
              <% end %>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  attr :tiqit_class, TiqitClass, required: true
  attr :balance, Decimal, required: true

  def tiqit_class_grid_price(assigns) do
    ~H"""
    <%= if Decimal.compare(@balance, @tiqit_class.price) != :lt do %>
      <button
        phx-click="select-tiqit-class"
        phx-value-tiqit-class-id={@tiqit_class.id}
        class="btn btn-sm rounded-full btn-primary px-3 py-1 cursor-pointer"
      >
        {format_usd(@tiqit_class.price, zero_free: true)}
      </button>
    <% else %>
      <div class="btn btn-sm rounded-full btn-ghost px-3 py-1 opacity-50 cursor-not-allowed">
        {format_usd(@tiqit_class.price, zero_free: true)}
      </div>
    <% end %>
    """
  end

  attr :balance, Decimal, required: true
  attr :offered_amount, Decimal, default: nil
  attr :id, :string, default: "wallet-balance-arcade-strip"

  def wallet_strip(assigns) do
    ~H"""
    <div class="w-fit mx-auto text-base-content bg-base-200 border-t border-base-300 px-3 py-2 rounded-lg border-1 border-base-300">
      <div class="flex flex-row flex-wrap justify-between items-center space-x-4">
        <div class="flex flex-row items-center justify-center">
          <.wallet_balance id={@id} balance={@balance} />
          <span class="font-normal text-base-content/60 ml-2 mr-3">to spend</span>
        </div>

        <button
          class="btn btn-md rounded-full !bg-sponster-400 hover:!bg-sponster-600 text-white !border-sponster-400 hover:!border-sponster-600 leading-none"
          phx-click="show-topup-modal"
        >
          <.icon name="hero-plus" class="w-4 h-4 mr-0" />
          <span class="font-bold">{if @offered_amount, do: format_usd(@offered_amount), else: "$0.00"}</span>
        </button>
      </div>
    </div>
    """
  end

  attr :show, :boolean, required: true
  attr :balance, Decimal, required: true
  attr :offered_amount, Decimal, default: nil
  attr :ads_count, :integer, default: 0

  def topup_modal(assigns) do
    ~H"""
    <.modal :if={@show} id="topup-modal" show on_cancel={JS.push("close-topup-modal")}>
      <div class="text-center space-y-6 p-8">
        <div class="space-y-4">
          <h2 class="text-xl font-bold text-base-content">Top up your wallet.</h2>
          <div class="mb-6 flex gap-2 justify-center items-center">
            Balance:
            <span class="inline-flex items-center w-auto text-lg bg-sponster-200 dark:bg-sponster-800 text-base-content px-3 py-1 rounded-lg border border-sponster-300 dark:border-sponster-500">
              <span class="font-bold">{format_usd(@balance)}</span>
            </span>
          </div>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-3 w-full divide-y md:divide-y-0 md:divide-x divide-base-300 p-4">
          <div class="flex-1 py-8">
            <h3 class="text-base-content/60 mb-3">Visit your sponsors.</h3>
            <div class="flex flex-col items-center">
              <div class="flex flex-col items-center gap-1">
                <div class="px-4 py-2">
                  <img
                    src="/images/Sponster_logo_color_horiz.svg"
                    alt="Sponster"
                    class="h-auto w-full"
                  />
                </div>
                <div class="flex flex-col items-center">
                  <div class="text-base-content/60 text-md mb-4">
                    {@ads_count} ads for
                    <span class="font-bold text-sponster-500">
                      {if @offered_amount, do: format_usd(@offered_amount), else: "$0.00"}
                    </span>
                  </div>
                </div>
              </div>
              <button
                class="btn btn-primary border-none rounded-full !bg-sponster-500 hover:!bg-sponster-600 text-white btn-lg"
                onclick="parent.postMessage('open_widget','*');self.toggleAnnouncerElements();"
              >
                Show my ads
              </button>
            </div>
          </div>
          <div class="flex-1 py-8">
            <h3 class="text-base-content/60 mb-3">Accept our daily gift.</h3>
            <.icon name="hero-gift" class="h-25 w-25 mb-3 text-base-content/50" />
            <button class="btn btn-primary rounded-full btn-lg" phx-click="topup">
              <.icon name="hero-plus" class="h-5 w-5 mr-2" />$0.50
            </button>
          </div>
          <div class="flex-1 flex flex-col items-center py-8">
            <h3 class="text-base-content/60 mb-3">Add funds of your own.</h3>
            <img
              src="/images/credit_debit_card_payments.png"
              alt="Credit/Debit Card Payments"
              class="h-25 w-25 mb-3"
            />
            <button class="btn btn-primary rounded-full btn-lg" phx-click="topup">
              <.icon name="hero-plus" class="h-5 w-5 mr-2" />Credit/Debit
            </button>
          </div>
        </div>

        <div class="flex justify-center gap-4"></div>
      </div>
    </.modal>
    """
  end
end
