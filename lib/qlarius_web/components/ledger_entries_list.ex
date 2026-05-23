defmodule QlariusWeb.Components.LedgerEntriesList do
  @moduledoc """
  Shared paginated ledger entry list (wallet and admin Sponster ledger).
  """
  use QlariusWeb, :html

  alias Qlarius.DateTime, as: QlariusDateTime

  attr :paginated_entries, :map, required: true
  attr :page, :integer, required: true

  def ledger_entries_pagination(assigns) do
    ~H"""
    <div class="flex justify-center mb-4 space-x-2">
      <div class="join [--radius-field:9999px]">
        <button
          phx-click="paginate"
          phx-value-page="1"
          class={"join-item btn btn-md #{if @page < 2, do: "btn-disabled"}"}
        >
          Newest
        </button>
        <button
          phx-click="paginate"
          phx-value-page={if @page > 1, do: @page - 1, else: 1}
          class={"join-item btn btn-md #{if @page < 2, do: "btn-disabled"}"}
        >
          <.icon name="hero-chevron-left" class="h-4 w-4" />
        </button>
        <div class="join-item btn btn-md btn-neutral">
          Page {@page}
        </div>
        <button
          phx-click="paginate"
          phx-value-page={@page + 1}
          class={"join-item btn btn-md #{if @page == @paginated_entries.total_pages, do: "btn-disabled"}"}
        >
          <.icon name="hero-chevron-right" class="h-4 w-4" />
        </button>
        <button
          phx-click="paginate"
          phx-value-page="oldest"
          class={"join-item btn btn-md #{if @page == @paginated_entries.total_pages, do: "btn-disabled"}"}
        >
          Oldest
        </button>
      </div>
    </div>
    """
  end

  attr :paginated_entries, :map, required: true
  attr :page, :integer, required: true
  attr :current_scope, :map, required: true
  attr :show_meta_1, :boolean, default: true
  attr :use_wallet_sidebar, :boolean, default: true
  attr :list_class, :string, default: nil
  attr :empty_message, :string, default: "No ledger activity to display."
  attr :show_pagination, :boolean, default: true

  def ledger_entries_list(assigns) do
    ~H"""
    <%= if Enum.empty?(@paginated_entries.entries) do %>
      <p class="text-center text-base-content/60 py-8">{@empty_message}</p>
    <% else %>
      <.ledger_entries_pagination
        :if={@show_pagination}
        paginated_entries={@paginated_entries}
        page={@page}
      />

      <ul class={[
        "list bg-base-200 dark:!bg-base-200 shadow-md overflow-hidden",
        @list_class || "-mx-4 sm:mx-0 sm:rounded-box"
      ]}>
        <li
          :for={entry <- @paginated_entries.entries}
          class="list-row cursor-pointer transition-all duration-200 !rounded-none hover:bg-base-200/70 dark:hover:bg-base-300/35"
          phx-click={select_click(@use_wallet_sidebar)}
          phx-value-entry_id={entry.id}
        >
          <div class="flex flex-col items-start justify-start mr-1">
            <span class={[
              "inline-flex items-center justify-center rounded-full w-8 h-8",
              if(Decimal.compare(entry.amt, 0) == :gt,
                do: "!bg-sponster-200 dark:!bg-sponster-800",
                else: "!bg-tiqit-200 dark:!bg-tiqit-800"
              )
            ]}>
              <.icon name={icon_for_entry(entry)} class="h-5 w-5 text-base-content" />
            </span>
          </div>
          <div class="list-col-grow">
            <div class="text-lg leading-snug">{entry.description}</div>
            <div :if={@show_meta_1 && entry.meta_1} class="text-base-content/50 text-sm">
              {entry.meta_1}
            </div>
            <div class="text-base-content/50 text-sm">
              {format_date(entry.created_at, @current_scope)}
            </div>
          </div>
          <div class="flex items-start">
            <div class="text-right mr-2">
              <div class="flex items-center gap-1">
                <span
                  :if={Decimal.compare(entry.amt, 0) != 0}
                  class={[
                    "badge badge-md p-1 mr-1",
                    if(Decimal.compare(entry.amt, 0) == :gt,
                      do: "!bg-sponster-200 dark:!bg-sponster-800",
                      else: "!bg-tiqit-200 dark:!bg-tiqit-800"
                    )
                  ]}
                >
                  <.icon
                    name={
                      if(Decimal.compare(entry.amt, 0) == :gt,
                        do: "hero-plus",
                        else: "hero-minus"
                      )
                    }
                    class="h-3 w-3 text-base-content"
                  />
                </span>
                <span class={[
                  "text-lg font-bold",
                  if(Decimal.compare(entry.amt, 0) == :gt,
                    do: "text-sponster-500 dark:text-sponster-300",
                    else: "text-tiqit-500"
                  )
                ]}>
                  {format_currency(Decimal.abs(entry.amt))}
                </span>
              </div>
              <div class="text-base-content/50 text-sm">
                {format_currency(entry.running_balance)}
              </div>
            </div>
            <div class="text-base-content/50">
              <.icon name="hero-chevron-right" class="h-6 w-6" />
            </div>
          </div>
        </li>
      </ul>
    <% end %>
    """
  end

  defp select_click(true) do
    %JS{}
    |> JS.push("select_ledger_entry", loading: "#right-sidebar-container")
    |> JS.add_class("translate-x-0", to: "#right-sidebar")
    |> JS.remove_class("translate-x-full", to: "#right-sidebar")
    |> JS.remove_class("opacity-0 pointer-events-none", to: "#right-sidebar-bg")
  end

  defp select_click(false), do: "select_ledger_entry"

  defp format_currency(amount) do
    "$#{:erlang.float_to_binary(Decimal.to_float(amount), decimals: 2)}"
  end

  defp format_date(datetime, current_scope) do
    QlariusDateTime.format_for_user(datetime, current_scope.user, :short)
  end

  defp icon_for_entry(%{tiqit_id: tiqit_id}) when not is_nil(tiqit_id), do: "hero-ticket"
  defp icon_for_entry(%{ad_event_id: ad_event_id}) when not is_nil(ad_event_id), do: "hero-film"
  defp icon_for_entry(entry), do: icon_for_meta_1(entry.meta_1)

  defp icon_for_meta_1("Tip/Donation"), do: "hero-gift"
  defp icon_for_meta_1("Tiqit Purchase"), do: "hero-ticket"
  defp icon_for_meta_1("Tiqit Refund"), do: "hero-arrow-uturn-left"
  defp icon_for_meta_1("Tiqit Undo"), do: "hero-arrow-uturn-left"
  defp icon_for_meta_1("Referral Bonus"), do: "hero-user-group"
  defp icon_for_meta_1("Text/Jump"), do: "hero-arrow-right-start-on-rectangle"
  defp icon_for_meta_1("Banner Tap"), do: "hero-photo"
  defp icon_for_meta_1("Video Ad"), do: "hero-film"
  defp icon_for_meta_1(_), do: "hero-cube"
end
