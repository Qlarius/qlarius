defmodule QlariusWeb.Admin.SponsterLedgerLive do
  use QlariusWeb, :live_view

  import QlariusWeb.Components.MarketerUI

  alias Qlarius.Wallets
  alias Qlarius.Sponster.LedgerReporting
  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar, LedgerAdEventDetails, LedgerEntriesList}

  @per_page 20

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Sponster Ledger")
     |> assign(:selected_entry, nil)
     |> assign(:entry_details, nil)
     |> assign(:drawer_open, false)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    period = Map.get(params, "period", LedgerReporting.default_period())
    bucket = parse_bucket(Map.get(params, "bucket", "day"))
    page = parse_page(params)

    {start_at, end_at} = LedgerReporting.period_to_range(period)
    ledger_header = Wallets.sponster_ledger_header()

    socket =
      socket
      |> assign(:period, period)
      |> assign(:bucket, bucket)
      |> assign(:start_at, start_at)
      |> assign(:end_at, end_at)
      |> assign(:ledger_header, ledger_header)
      |> assign(:summary, LedgerReporting.summary_stats(start_at, end_at))
      |> assign(:time_series, LedgerReporting.time_series(start_at, end_at, bucket))
      |> assign(:max_series_revenue, max_series_revenue(start_at, end_at, bucket))
      |> assign(:ad_unit_breakdown, LedgerReporting.revenue_by_ad_unit_type(start_at, end_at))
      |> assign(:top_marketers, LedgerReporting.top_marketers(start_at, end_at))
      |> assign(:top_campaigns, LedgerReporting.top_campaigns(start_at, end_at))
      |> assign(:recent_events, LedgerReporting.recent_events(start_at, end_at))
      |> assign(:page, page)
      |> assign(
        :paginated_entries,
        paginate_ledger(ledger_header, page)
      )

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_period", %{"period" => period}, socket) do
    {:noreply, push_patch(socket, to: patch_url(socket, period: period, page: 1))}
  end

  def handle_event("change_bucket", %{"bucket" => bucket}, socket) do
    {:noreply, push_patch(socket, to: patch_url(socket, bucket: bucket))}
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    {:noreply, push_patch(socket, to: patch_url(socket, page: page))}
  end

  def handle_event("select_ledger_entry", %{"entry_id" => entry_id}, socket) do
    entry_id = String.to_integer(entry_id)
    header_id = Wallets.sponster_ledger_header_id()

    entry = Wallets.get_ledger_entry_for_header!(entry_id, header_id)
    entry_details = entry_details_for(entry)

    {:noreply,
     socket
     |> assign(:selected_entry, entry)
     |> assign(:entry_details, entry_details)
     |> assign(:drawer_open, true)}
  end

  def handle_event("close_entry_drawer", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected_entry, nil)
     |> assign(:entry_details, nil)
     |> assign(:drawer_open, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin {assigns}>
      <div class="flex h-screen">
        <AdminSidebar.sidebar current_user={@current_scope.user} />

        <div class="flex min-w-0 grow flex-col">
          <AdminTopbar.topbar current_user={@current_scope.user} />

          <div class="overflow-auto">
            <.page>
              <.page_header
                title="Sponster Ledger"
                subtitle="Platform revenue, ad activity and ledger entries"
              />

              <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
                <form phx-change="change_period">
                  <label class="select select-sm">
                    <span class="label">Period</span>
                    <select name="period">
                      <option
                        :for={{value, label} <- period_options()}
                        value={value}
                        selected={@period == value}
                      >
                        {label}
                      </option>
                    </select>
                  </label>
                </form>
                <div class="join" role="group" aria-label="Group by">
                  <button
                    :for={{bucket, label} <- [day: "Day", week: "Week", month: "Month"]}
                    type="button"
                    phx-click="change_bucket"
                    phx-value-bucket={bucket}
                    aria-pressed={to_string(@bucket == bucket)}
                    class={["join-item btn btn-sm", @bucket == bucket && "btn-active"]}
                  >
                    {label}
                  </button>
                </div>
              </div>

              <div class="mb-8 grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-6">
                <.stat_tile
                  label="Ledger balance"
                  icon="hero-building-library"
                  hint="All-time platform wallet"
                  value_class="text-sponster-500"
                >
                  {format_usd(@summary.ledger_balance)}
                </.stat_tile>
                <.stat_tile
                  label="Sponster revenue"
                  icon="hero-arrow-trending-up"
                  hint="Payable, non-demo in period"
                >
                  {format_usd(@summary.sponster_revenue)}
                </.stat_tile>
                <.stat_tile
                  label="Ad events"
                  icon="hero-cursor-arrow-rays"
                  hint={"#{@summary.payable_events} payable, #{@summary.demo_events} demo"}
                >
                  {@summary.ad_events}
                </.stat_tile>
                <.stat_tile label="Avg per payable" icon="hero-calculator">
                  {format_usd(@summary.avg_revenue_per_payable)}
                </.stat_tile>
                <.stat_tile label="Marketer spend" icon="hero-megaphone">
                  {format_usd(@summary.marketer_spend)}
                </.stat_tile>
                <.stat_tile label="Consumer payouts" icon="hero-user-group">
                  {format_usd(@summary.consumer_payouts)}
                </.stat_tile>
              </div>

              <div class="mb-8 grid items-start gap-8 lg:grid-cols-2">
                <.panel flush title="Events and revenue over time" class="lg:col-span-2">
                  <.data_table :if={@time_series != []} id="ledger-time-series" rows={@time_series}>
                    <:col :let={row} label="Period" class="whitespace-nowrap">
                      {format_period(row.period)}
                    </:col>
                    <:col :let={row} label="Events" class="text-right">{row.events}</:col>
                    <:col :let={row} label="Revenue" class="text-right">
                      <div class="flex items-center justify-end gap-2">
                        <div
                          :if={@max_series_revenue > 0}
                          class="h-2 rounded bg-sponster-400/60"
                          style={"width: #{bar_width(row.sponster_revenue, @max_series_revenue)}px"}
                        />
                        <span>{format_usd(row.sponster_revenue)}</span>
                      </div>
                    </:col>
                    <:col :let={row} label="Marketer" class="text-right">
                      {format_usd(row.marketer_cost)}
                    </:col>
                    <:col :let={row} label="Consumer" class="text-right">
                      {format_usd(row.consumer_collect)}
                    </:col>
                  </.data_table>
                  <.empty_note :if={@time_series == []}>No activity in this period</.empty_note>
                </.panel>

                <.panel flush title="Revenue by ad unit type">
                  <.data_table
                    :if={@ad_unit_breakdown != []}
                    id="ledger-ad-unit-breakdown"
                    rows={@ad_unit_breakdown}
                  >
                    <:col :let={row} label="Type">{row.ad_unit_type}</:col>
                    <:col :let={row} label="Events" class="text-right">{row.events}</:col>
                    <:col :let={row} label="Revenue" class="text-right">
                      {format_usd(row.revenue)}
                    </:col>
                    <:col :let={row} label="Avg" class="text-right">
                      {format_usd(row.avg_per_event)}
                    </:col>
                    <:col :let={row} label="%" class="text-right">{row.pct_of_revenue}%</:col>
                  </.data_table>
                  <.empty_note :if={@ad_unit_breakdown == []}>
                    No payable revenue in this period
                  </.empty_note>
                </.panel>

                <.top_table
                  id="ledger-top-marketers"
                  title="Top marketers"
                  rows={@top_marketers}
                  name_field={:marketer_name}
                />
                <.top_table
                  id="ledger-top-campaigns"
                  title="Top campaigns"
                  rows={@top_campaigns}
                  name_field={:campaign_title}
                />
              </div>

              <.panel flush title="Recent payable events" class="mb-8">
                <.data_table
                  :if={@recent_events != []}
                  id="ledger-recent-events"
                  rows={@recent_events}
                >
                  <:col :let={ev} label="When" class="whitespace-nowrap text-xs text-base-content/60">
                    {format_datetime(ev.created_at, @current_scope)}
                  </:col>
                  <:col :let={ev} label="Marketer">{ev.marketer_name}</:col>
                  <:col :let={ev} label="Campaign" class="max-w-[12rem] truncate">
                    {ev.campaign_title}
                  </:col>
                  <:col :let={ev} label="Type">{ev.ad_unit_type}</:col>
                  <:col :let={ev} label="Sponster" class="text-right">
                    {format_usd(ev.sponster_revenue)}
                  </:col>
                  <:col :let={ev} label="Consumer" class="text-right">
                    {format_usd(ev.consumer_collect)}
                  </:col>
                </.data_table>
                <.empty_note :if={@recent_events == []}>No payable events in this period</.empty_note>
              </.panel>

              <.panel title="Sponster ledger entries">
                <LedgerEntriesList.ledger_entries_list
                  paginated_entries={@paginated_entries}
                  page={@page}
                  current_scope={@current_scope}
                  show_meta_1={false}
                  use_wallet_sidebar={false}
                  list_class="rounded-box"
                  empty_message="No Sponster ledger entries yet."
                />
              </.panel>
            </.page>
          </div>
        </div>
      </div>

      <.entry_drawer
        :if={@drawer_open && @selected_entry}
        selected_entry={@selected_entry}
        entry_details={@entry_details}
        current_scope={@current_scope}
      />
    </Layouts.admin>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :rows, :list, required: true
  attr :name_field, :atom, required: true

  defp top_table(assigns) do
    ~H"""
    <.panel flush title={@title}>
      <.data_table :if={@rows != []} id={@id} rows={@rows}>
        <:col :let={row} label="Name" class="max-w-[14rem] truncate">
          {Map.get(row, @name_field)}
        </:col>
        <:col :let={row} label="Events" class="text-right">{row.events}</:col>
        <:col :let={row} label="Revenue" class="text-right">{format_usd(row.revenue)}</:col>
      </.data_table>
      <.empty_note :if={@rows == []}>No data</.empty_note>
    </.panel>
    """
  end

  slot :inner_block, required: true

  defp empty_note(assigns) do
    ~H"""
    <p class="px-6 py-8 text-center text-sm text-base-content/50">{render_slot(@inner_block)}</p>
    """
  end

  attr :selected_entry, :map, required: true
  attr :entry_details, :map, required: true
  attr :current_scope, :map, required: true

  defp entry_drawer(assigns) do
    ~H"""
    <div
      class="fixed inset-0 z-50 bg-base-300/50 backdrop-blur-xs"
      phx-click="close_entry_drawer"
    />
    <aside class="fixed inset-y-0 right-0 z-50 flex w-full max-w-md flex-col border-l border-base-300 bg-base-100 shadow-xl">
      <header class="flex items-start justify-between gap-4 border-b border-base-300 px-6 py-4">
        <div class="min-w-0">
          <h2 class="text-base font-semibold">Ledger entry</h2>
          <p class="text-xs text-base-content/50">#{@selected_entry.id}</p>
        </div>
        <button
          type="button"
          phx-click="close_entry_drawer"
          class="btn btn-ghost btn-sm btn-square"
          aria-label="Close"
        >
          <.icon name="hero-x-mark" class="size-5" />
        </button>
      </header>
      <div class="flex-1 space-y-6 overflow-y-auto px-6 py-5">
        <div class="space-y-4">
          <dl class="grid grid-cols-2 gap-x-6 gap-y-4">
            <.detail_item label="Amount">
              <span class="text-lg font-semibold text-sponster-500">
                +{format_usd(@selected_entry.amt)}
              </span>
            </.detail_item>
            <.detail_item
              label="Balance after"
              value={format_usd(@selected_entry.running_balance)}
            />
            <.detail_item
              label="Date"
              value={format_datetime(@selected_entry.created_at, @current_scope)}
            />
          </dl>
          <p :if={@selected_entry.description} class="text-sm text-base-content/70">
            {@selected_entry.description}
          </p>
        </div>

        <%= if @entry_details.type == :ad_event do %>
          <LedgerAdEventDetails.summary entry_details={@entry_details} />

          <%= if @entry_details.media_piece do %>
            <h3 class="text-sm font-semibold">Ad preview</h3>
            <%= if @entry_details.media_piece.media_piece_type_id == 2 do %>
              <QlariusWeb.Components.AdsComponents.video_thumbnail
                media_piece={@entry_details.media_piece}
                class="w-full rounded-lg"
                id={"admin-mp-#{@entry_details.media_piece.id}"}
              />
            <% else %>
              <.three_tap_ad media_piece={@entry_details.media_piece} show_banner={true} />
            <% end %>
          <% end %>
        <% end %>
      </div>
    </aside>
    """
  end

  defp period_options do
    [
      {"7d", "Last 7 days"},
      {"30d", "Last 30 days"},
      {"90d", "Last 90 days"},
      {"all", "All time"}
    ]
  end

  defp paginate_ledger(nil, _page) do
    %{entries: [], page_number: 1, page_size: @per_page, total_entries: 0, total_pages: 0}
  end

  defp paginate_ledger(ledger_header, page) do
    Wallets.list_ledger_entries(ledger_header.id, page, @per_page)
  end

  defp max_series_revenue(start_at, end_at, bucket) do
    LedgerReporting.time_series(start_at, end_at, bucket)
    |> Enum.map(& &1.sponster_revenue)
    |> Enum.reduce(Decimal.new(0), fn amt, max ->
      if Decimal.compare(amt, max) == :gt, do: amt, else: max
    end)
    |> Decimal.to_float()
  end

  defp bar_width(revenue, max_revenue) when max_revenue > 0 do
    pct = Decimal.to_float(revenue) / max_revenue
    max(4, round(pct * 80))
  end

  defp bar_width(_, _), do: 0

  defp parse_bucket("week"), do: :week
  defp parse_bucket("month"), do: :month
  defp parse_bucket(_), do: :day

  defp parse_page(params) do
    case Map.get(params, "page") do
      "oldest" ->
        header = Wallets.sponster_ledger_header()
        if header, do: Wallets.list_ledger_entries(header.id, 1, @per_page).total_pages, else: 1

      nil ->
        1

      page_str ->
        String.to_integer(page_str)
    end
  end

  defp patch_url(socket, opts) do
    period = Keyword.get(opts, :period, socket.assigns.period)
    bucket = Keyword.get(opts, :bucket, Atom.to_string(socket.assigns.bucket))
    page = Keyword.get(opts, :page, socket.assigns.page)

    ~p"/admin/sponster_ledger?#{%{period: period, bucket: bucket, page: page}}"
  end

  defp entry_details_for(%{ad_event_id: _} = entry) when not is_nil(entry.ad_event_id) do
    QlariusWeb.LedgerEntryDetails.ad_event_details(entry.ad_event)
  end

  defp entry_details_for(entry) do
    %{type: :other, description: entry.description}
  end

  defp format_usd(amount), do: QlariusWeb.Money.format_usd(amount)

  defp format_period(%NaiveDateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d")
  end

  defp format_period(other), do: to_string(other)

  defp format_datetime(dt, scope) do
    Qlarius.DateTime.format_for_user(dt, scope.user, :standard)
  end
end
