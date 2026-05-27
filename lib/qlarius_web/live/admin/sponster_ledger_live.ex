defmodule QlariusWeb.Admin.SponsterLedgerLive do
  use QlariusWeb, :live_view

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
            <div class="p-6">
              <div class="flex flex-wrap justify-between items-start gap-4 mb-6">
                <div>
                  <h1 class="text-3xl font-bold">Sponster Ledger</h1>
                  <p class="text-base-content/60 mt-1">
                    Platform revenue, ad activity, and ledger entries
                  </p>
                </div>
                <div class="flex flex-wrap gap-2 items-center">
                  <form phx-change="change_period" class="flex gap-1">
                    <select
                      name="period"
                      class="select select-bordered select-sm"
                      value={@period}
                    >
                      <option value="7d">Last 7 days</option>
                      <option value="30d">Last 30 days</option>
                      <option value="90d">Last 90 days</option>
                      <option value="all">All time</option>
                    </select>
                  </form>
                  <div class="join">
                    <button
                      type="button"
                      phx-click="change_bucket"
                      phx-value-bucket="day"
                      class={["join-item btn btn-sm", @bucket == :day && "btn-active"]}
                    >
                      Day
                    </button>
                    <button
                      type="button"
                      phx-click="change_bucket"
                      phx-value-bucket="week"
                      class={["join-item btn btn-sm", @bucket == :week && "btn-active"]}
                    >
                      Week
                    </button>
                    <button
                      type="button"
                      phx-click="change_bucket"
                      phx-value-bucket="month"
                      class={["join-item btn btn-sm", @bucket == :month && "btn-active"]}
                    >
                      Month
                    </button>
                  </div>
                </div>
              </div>

              <div class="stats stats-vertical sm:stats-horizontal shadow w-full mb-6">
                <div class="stat">
                  <div class="stat-title">Ledger balance</div>
                  <div class="stat-value text-sponster-500">
                    {format_usd(@summary.ledger_balance)}
                  </div>
                  <div class="stat-desc">All-time platform wallet</div>
                </div>
                <div class="stat">
                  <div class="stat-title">Sponster revenue</div>
                  <div class="stat-value">{format_usd(@summary.sponster_revenue)}</div>
                  <div class="stat-desc">Payable, non-demo in period</div>
                </div>
                <div class="stat">
                  <div class="stat-title">Ad events</div>
                  <div class="stat-value">{@summary.ad_events}</div>
                  <div class="stat-desc">
                    {@summary.payable_events} payable · {@summary.demo_events} demo
                  </div>
                </div>
                <div class="stat">
                  <div class="stat-title">Avg / payable</div>
                  <div class="stat-value text-lg">
                    {format_usd(@summary.avg_revenue_per_payable)}
                  </div>
                </div>
                <div class="stat">
                  <div class="stat-title">Marketer spend</div>
                  <div class="stat-value text-lg">{format_usd(@summary.marketer_spend)}</div>
                </div>
                <div class="stat">
                  <div class="stat-title">Consumer payouts</div>
                  <div class="stat-value text-lg">{format_usd(@summary.consumer_payouts)}</div>
                </div>
              </div>

              <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
                <div class="card bg-base-200 shadow-sm">
                  <div class="card-body p-4">
                    <h2 class="card-title text-base">Events &amp; revenue over time</h2>
                    <div class="overflow-x-auto">
                      <table class="table table-sm">
                        <thead>
                          <tr>
                            <th>Period</th>
                            <th class="text-right">Events</th>
                            <th class="text-right">Revenue</th>
                            <th class="text-right">Marketer</th>
                            <th class="text-right">Consumer</th>
                          </tr>
                        </thead>
                        <tbody>
                          <tr :for={row <- @time_series}>
                            <td class="whitespace-nowrap">{format_period(row.period)}</td>
                            <td class="text-right">{row.events}</td>
                            <td class="text-right">
                              <div class="flex items-center justify-end gap-2">
                                <div
                                  :if={@max_series_revenue > 0}
                                  class="h-2 rounded bg-sponster-400/60"
                                  style={"width: #{bar_width(row.sponster_revenue, @max_series_revenue)}px"}
                                />
                                <span>{format_usd(row.sponster_revenue)}</span>
                              </div>
                            </td>
                            <td class="text-right">{format_usd(row.marketer_cost)}</td>
                            <td class="text-right">{format_usd(row.consumer_collect)}</td>
                          </tr>
                          <tr :if={@time_series == []}>
                            <td colspan="5" class="text-center text-base-content/50">
                              No activity in this period
                            </td>
                          </tr>
                        </tbody>
                      </table>
                    </div>
                  </div>
                </div>

                <div class="card bg-base-200 shadow-sm">
                  <div class="card-body p-4">
                    <h2 class="card-title text-base">Revenue by ad unit type</h2>
                    <div class="overflow-x-auto">
                      <table class="table table-sm">
                        <thead>
                          <tr>
                            <th>Type</th>
                            <th class="text-right">Events</th>
                            <th class="text-right">Revenue</th>
                            <th class="text-right">Avg</th>
                            <th class="text-right">%</th>
                          </tr>
                        </thead>
                        <tbody>
                          <tr :for={row <- @ad_unit_breakdown}>
                            <td>{row.ad_unit_type}</td>
                            <td class="text-right">{row.events}</td>
                            <td class="text-right">{format_usd(row.revenue)}</td>
                            <td class="text-right">{format_usd(row.avg_per_event)}</td>
                            <td class="text-right">{row.pct_of_revenue}%</td>
                          </tr>
                          <tr :if={@ad_unit_breakdown == []}>
                            <td colspan="5" class="text-center text-base-content/50">
                              No payable revenue in this period
                            </td>
                          </tr>
                        </tbody>
                      </table>
                    </div>
                  </div>
                </div>
              </div>

              <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
                <.top_table title="Top marketers" rows={@top_marketers} name_field={:marketer_name} />
                <.top_table title="Top campaigns" rows={@top_campaigns} name_field={:campaign_title} />
              </div>

              <div class="card bg-base-200 shadow-sm mb-6">
                <div class="card-body p-4">
                  <h2 class="card-title text-base">Recent payable events</h2>
                  <div class="overflow-x-auto">
                    <table class="table table-sm">
                      <thead>
                        <tr>
                          <th>When</th>
                          <th>Marketer</th>
                          <th>Campaign</th>
                          <th>Type</th>
                          <th class="text-right">Sponster</th>
                          <th class="text-right">Consumer</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr :for={ev <- @recent_events}>
                          <td class="whitespace-nowrap text-xs">
                            {format_datetime(ev.created_at, @current_scope)}
                          </td>
                          <td>{ev.marketer_name}</td>
                          <td class="max-w-[8rem] truncate">{ev.campaign_title}</td>
                          <td>{ev.ad_unit_type}</td>
                          <td class="text-right">{format_usd(ev.sponster_revenue)}</td>
                          <td class="text-right">{format_usd(ev.consumer_collect)}</td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>

              <div class="card bg-base-200 shadow-sm">
                <div class="card-body p-4">
                  <h2 class="card-title text-base mb-4">Sponster ledger entries</h2>
                  <LedgerEntriesList.ledger_entries_list
                    paginated_entries={@paginated_entries}
                    page={@page}
                    current_scope={@current_scope}
                    show_meta_1={false}
                    use_wallet_sidebar={false}
                    list_class="rounded-box"
                    empty_message="No Sponster ledger entries yet."
                  />
                </div>
              </div>
            </div>
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

  attr :title, :string, required: true
  attr :rows, :list, required: true
  attr :name_field, :atom, required: true

  defp top_table(assigns) do
    ~H"""
    <div class="card bg-base-200 shadow-sm">
      <div class="card-body p-4">
        <h2 class="card-title text-base">{@title}</h2>
        <div class="overflow-x-auto">
          <table class="table table-sm">
            <thead>
              <tr>
                <th>Name</th>
                <th class="text-right">Events</th>
                <th class="text-right">Revenue</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={row <- @rows}>
                <td class="max-w-[12rem] truncate">{Map.get(row, @name_field)}</td>
                <td class="text-right">{row.events}</td>
                <td class="text-right">{format_usd(row.revenue)}</td>
              </tr>
              <tr :if={@rows == []}>
                <td colspan="3" class="text-center text-base-content/50">No data</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
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
    <div class="fixed inset-y-0 right-0 z-50 w-full max-w-md bg-base-100 border-l border-base-300 shadow-xl flex flex-col">
      <div class="flex items-center justify-between px-4 py-4 border-b border-base-300">
        <h3 class="text-lg font-semibold">Ledger entry</h3>
        <button type="button" phx-click="close_entry_drawer" class="btn btn-ghost btn-sm btn-circle">
          <.icon name="hero-x-mark" class="h-5 w-5" />
        </button>
      </div>
      <div class="flex-1 overflow-y-auto p-4 space-y-4">
        <div class="bg-base-200 rounded-lg p-4">
          <div class="flex justify-between mb-2">
            <span class="text-sm text-base-content/70">Amount</span>
            <span class="tabular-amount font-bold text-sponster-500">
              +{format_usd(@selected_entry.amt)}
            </span>
          </div>
          <div class="flex justify-between">
            <span class="text-sm text-base-content/70">Balance after</span>
            <span class="tabular-amount text-sm">{format_usd(@selected_entry.running_balance)}</span>
          </div>
          <div class="flex justify-between mt-2">
            <span class="text-sm text-base-content/70">Date</span>
            <span class="text-sm">
              {format_datetime(@selected_entry.created_at, @current_scope)}
            </span>
          </div>
          <p class="text-sm mt-2">{@selected_entry.description}</p>
        </div>

        <%= if @entry_details.type == :ad_event do %>
          <LedgerAdEventDetails.summary entry_details={@entry_details} />

          <%= if @entry_details.media_piece do %>
            <h4 class="font-medium">Ad preview</h4>
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
    </div>
    """
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
