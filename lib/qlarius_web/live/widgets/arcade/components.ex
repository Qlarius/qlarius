defmodule QlariusWeb.Widgets.Arcade.Components do
  use Phoenix.Component

  alias Qlarius.Tiqit.Arcade.ContentGroup
  alias Qlarius.Tiqit.Arcade.ContentPiece
  alias Qlarius.Tiqit.Arcade.TiqitClass

  import QlariusWeb.CoreComponents
  import QlariusWeb.Money
  import QlariusWeb.TiqitClassHTML
  import QlariusWeb.Components.CustomComponentsMobile

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
                  ({length(@group.content_pieces)} episodes)
                </span>
              </th>
              <th
                :if={@show_catalog?}
                class="w-40 font-semibold text-base-content text-center py-2 px-3 leading-none"
              >
                Entire Site<br />
                <span class="text-base-content/40 text-xs mt-0">
                  (9 series)
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
        {format_usd(@tiqit_class.price)}
      </button>
    <% else %>
      <div class="btn btn-xs btn-primary px-3 py-1 rounded disabled line-through">
        {format_usd(@tiqit_class.price)}
      </div>
    <% end %>
    """
  end

  attr :balance, Decimal, required: true
  attr :offered_amount, Decimal, required: true

  def wallet_strip(assigns) do
    ~H"""
    <div class="w-fit mx-auto text-base-content bg-base-200 border-t border-base-300 px-3 py-2 rounded-lg border-1 border-base-300">
      <div class="flex flex-row flex-wrap justify-between items-center space-x-4">
        <div class="flex flex-row items-center justify-center">
          <.wallet_balance balance={@balance} />
          <span class="font-normal text-base-content/60 ml-2 mr-3">to spend</span>
        </div>

        <button
          class="btn btn-md rounded-full !bg-sponster-400 hover:!bg-sponster-600 text-white !border-sponster-400 hover:!border-sponster-600 leading-none"
          phx-click="show-topup-modal"
        >
          <.icon name="hero-arrow-left" class="w-4 h-4 mr-0" /> Top up •
          <span class="font-bold">{format_usd(@offered_amount)}</span>
        </button>
      </div>
    </div>
    """
  end
end
