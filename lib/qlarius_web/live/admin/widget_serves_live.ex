defmodule QlariusWeb.Admin.WidgetServesLive do
  @moduledoc """
  Loads of the third-party Sponster bar (`/widgets/ads_ext`): volume per
  publisher and host, and the rows that look automated or abusive.

  All state lives in the URL so a filtered view can be shared.
  """

  use QlariusWeb, :live_view

  import QlariusWeb.Components.MarketerUI

  alias Qlarius.Sponster.WidgetServeReporting, as: Reporting
  alias QlariusWeb.Components.AdminSidebar
  alias QlariusWeb.Components.AdminTopbar

  @tabs [
    {"publishers", "Publishers"},
    {"hosts", "Hosts"},
    {"suspicious", "Suspicious"},
    {"log", "Log"}
  ]
  @per_page 50

  @publisher_sorts ~w(name loads unique_pages unique_ips authed_share loads_per_ip hosts flagged flagged_share last_seen)
  @host_sorts ~w(host loads unique_pages unique_ips authed_share loads_per_ip recipients flagged flagged_share last_seen)

  @flag_labels %{
    burst: "Burst",
    page_id_churn: "Page id churn",
    shared_page_id: "Shared page id",
    reconnect_storm: "Reconnect storm",
    bot_agent: "Bot agent",
    bad_host: "Bad host"
  }

  @flag_descriptions %{
    burst: "One IP loading one publisher's bar more than 30 times in 10 minutes.",
    page_id_churn:
      "One IP minting more than 10 page ids in an hour: reloads that each start a new page.",
    shared_page_id: "One page id seen from more than 3 IPs.",
    reconnect_storm: "More than 20 connects on a single page load.",
    bot_agent: "A crawler or automation user agent, or none at all from the embed script.",
    bad_host: "No publisher page, or a Qadabra page posing as one."
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Widget serves")}
  end

  @impl true
  def handle_params(params, _url, socket) do
    period =
      if Map.has_key?(Map.new(Reporting.periods()), params["period"]),
        do: params["period"],
        else: Reporting.default_period()

    bucket = parse_bucket(params["bucket"], period)
    tab = if params["tab"] in Enum.map(@tabs, &elem(&1, 0)), do: params["tab"], else: "publishers"
    page = parse_page(params["page"])
    filters = parse_filters(params)
    range = Reporting.period_to_range(period)

    hosts = Reporting.by_host(range, filters)
    series = Reporting.time_series(range, bucket, filters)
    devices = Reporting.by_device(range, filters)

    socket =
      socket
      |> assign(:period, period)
      |> assign(:bucket, bucket)
      |> assign(:tab, tab)
      |> assign(:page, page)
      |> assign(:filters, filters)
      |> assign(:kpis, Reporting.kpis(range, filters))
      |> assign(:series, series)
      |> assign(:series_max, series |> Enum.map(& &1.total) |> Enum.max(fn -> 0 end))
      |> assign(:top_hosts, Enum.take(hosts, 8))
      |> assign(:devices, devices)
      |> assign(:device_total, devices |> Enum.map(& &1.loads) |> Enum.sum())
      |> assign_tab(tab, params, range, filters, hosts)

    {:noreply, assign(socket, :query, current_query(socket.assigns))}
  end

  defp assign_tab(socket, "publishers", params, range, filters, _hosts) do
    {sort, dir} = parse_sort(params, @publisher_sorts, "loads")

    socket
    |> assign(:sort, sort)
    |> assign(:dir, dir)
    |> assign(:rows, range |> Reporting.by_recipient(filters) |> sort_rows(sort, dir))
  end

  defp assign_tab(socket, "hosts", params, _range, _filters, hosts) do
    {sort, dir} = parse_sort(params, @host_sorts, "loads")

    socket
    |> assign(:sort, sort)
    |> assign(:dir, dir)
    |> assign(:rows, sort_rows(hosts, sort, dir))
  end

  defp assign_tab(socket, "suspicious", _params, range, filters, _hosts) do
    groups =
      range
      |> Reporting.suspicious(filters)
      |> Enum.group_by(& &1.kind)

    socket
    |> assign(:sort, nil)
    |> assign(:dir, nil)
    |> assign(:suspicious, Enum.map(Reporting.flags(), &{&1, Map.get(groups, &1, [])}))
  end

  defp assign_tab(socket, "log", _params, range, filters, _hosts) do
    socket
    |> assign(:sort, nil)
    |> assign(:dir, nil)
    |> assign(:log, Reporting.recent(range, filters, socket.assigns.page, @per_page))
  end

  @impl true
  def handle_event("change_period", %{"period" => period}, socket) do
    {:noreply, push_patch(socket, to: patch_url(socket, period: period, bucket: nil, page: nil))}
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:tabs, @tabs)
      |> assign(:flag_labels, @flag_labels)
      |> assign(:flag_descriptions, @flag_descriptions)

    ~H"""
    <Layouts.admin {assigns}>
      <div class="flex h-screen">
        <AdminSidebar.sidebar current_user={@current_scope.user} current_path={@current_path} />

        <div class="flex min-w-0 grow flex-col">
          <AdminTopbar.topbar current_user={@current_scope.user} />

          <div class="overflow-auto">
            <.page>
              <.page_header
                title="Widget serves"
                subtitle="Loads of the Sponster bar on publisher sites. A reconnect from the same page counts once."
              />

              <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
                <form id="widget-serves-period" phx-change="change_period">
                  <label class="select select-sm">
                    <span class="label">Period</span>
                    <select name="period">
                      <option
                        :for={{value, label} <- Reporting.periods()}
                        value={value}
                        selected={@period == value}
                      >
                        {label}
                      </option>
                    </select>
                  </label>
                </form>
                <div class="join" role="group" aria-label="Group by">
                  <.link
                    :for={{bucket, label} <- [hour: "Hour", day: "Day"]}
                    patch={patch_url(@query, bucket: bucket)}
                    aria-pressed={to_string(@bucket == bucket)}
                    class={["join-item btn btn-sm", @bucket == bucket && "btn-active"]}
                  >
                    {label}
                  </.link>
                </div>
              </div>

              <div :if={active_filters(@filters) != []} class="mb-4 flex flex-wrap items-center gap-2">
                <span class="text-xs text-base-content/60">Filtered by</span>
                <.link
                  :for={{key, label} <- active_filters(@filters)}
                  id={"widget-serves-filter-#{key}"}
                  patch={patch_url(@query, [{key, nil}, page: nil])}
                  class="inline-flex items-center gap-1 rounded-md border border-base-300 bg-base-200 px-2 py-0.5 text-xs hover:bg-base-300"
                >
                  {label} <.icon name="hero-x-mark" class="size-3" />
                </.link>
                <.link
                  patch={
                    patch_url(@query,
                      recipient_id: nil,
                      host: nil,
                      ip: nil,
                      page_load_id: nil,
                      flag: nil,
                      page: nil
                    )
                  }
                  class="text-xs text-primary hover:underline"
                >
                  Clear all
                </.link>
              </div>

              <div class="mb-8 grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-6">
                <.stat_tile
                  label="Loads"
                  icon="hero-signal"
                  hint={"#{num(@kpis.reconnects)} reconnects not counted"}
                >
                  {num(@kpis.loads)}
                </.stat_tile>
                <.stat_tile
                  label="Unique pages"
                  icon="hero-document"
                  hint={"#{num(@kpis.direct_opens)} direct opens"}
                >
                  {num(@kpis.unique_pages)}
                </.stat_tile>
                <.stat_tile
                  label="Unique IPs"
                  icon="hero-globe-alt"
                  hint={"#{ratio(@kpis.loads, @kpis.unique_ips)} loads per IP"}
                >
                  {num(@kpis.unique_ips)}
                </.stat_tile>
                <.stat_tile
                  label="Signed in"
                  icon="hero-user-circle"
                  hint={"#{num(@kpis.authed)} loads"}
                >
                  {pct(@kpis.authed_share)}
                </.stat_tile>
                <.stat_tile
                  label="Active publishers"
                  icon="hero-building-storefront"
                  hint={"#{num(@kpis.hosts)} hosts"}
                >
                  {num(@kpis.recipients)}
                </.stat_tile>
                <.stat_tile
                  label="Suspicious"
                  icon="hero-shield-exclamation"
                  hint={"#{num(@kpis.flagged)} flagged loads"}
                  value_class={@kpis.flagged > 0 && "text-warning"}
                >
                  {pct(@kpis.flagged_share)}
                </.stat_tile>
              </div>

              <div class="mb-8 grid items-start gap-8 lg:grid-cols-3">
                <.panel title="Loads over time" class="lg:col-span-3">
                  <.loads_chart series={@series} max={@series_max} bucket={@bucket} />
                </.panel>

                <.panel title="Top hosts" class="lg:col-span-2">
                  <.bar_list
                    id="widget-serves-top-hosts"
                    rows={
                      Enum.map(
                        @top_hosts,
                        &{&1.host || "No publisher page", &1.loads, %{host: &1.host}}
                      )
                    }
                    total={@kpis.loads}
                    patch_fn={fn filter -> patch_url(@query, Map.to_list(filter) ++ [page: nil]) end}
                  />
                </.panel>

                <.panel title="Devices">
                  <.bar_list
                    id="widget-serves-devices"
                    rows={Enum.map(@devices, &{&1.device, &1.loads, nil})}
                    total={@device_total}
                    patch_fn={nil}
                  />
                </.panel>
              </div>

              <div role="tablist" class="tabs tabs-border mb-4">
                <.link
                  :for={{value, label} <- @tabs}
                  id={"widget-serves-tab-#{value}"}
                  role="tab"
                  patch={patch_url(@query, tab: value, sort: nil, dir: nil, page: nil)}
                  class={["tab", @tab == value && "tab-active"]}
                >
                  {label}
                  <span
                    :if={value == "suspicious" && @kpis.flagged > 0}
                    class="ml-2 rounded-full bg-warning/15 px-2 text-xs text-warning"
                  >
                    {num(@kpis.flagged)}
                  </span>
                </.link>
              </div>

              <.panel :if={@tab == "publishers"} flush>
                <.empty_state :if={@rows == []} icon="hero-signal-slash" title="No loads">
                  No widget loads in this period.
                </.empty_state>
                <.sortable_table
                  :if={@rows != []}
                  id="widget-serves-publishers"
                  rows={@rows}
                  sort={@sort}
                  dir={@dir}
                  sort_url={fn sort, dir -> patch_url(@query, sort: sort, dir: dir) end}
                  row_patch={
                    fn row -> patch_url(@query, recipient_id: row.recipient_id, page: nil) end
                  }
                  columns={[
                    {"name", "Publisher", "", & &1.name},
                    {"loads", "Loads", "text-right", &num(&1.loads)},
                    {"unique_pages", "Pages", "text-right", &num(&1.unique_pages)},
                    {"unique_ips", "IPs", "text-right", &num(&1.unique_ips)},
                    {"loads_per_ip", "Loads / IP", "text-right", & &1.loads_per_ip},
                    {"authed_share", "Signed in", "text-right", &pct(&1.authed_share)},
                    {"hosts", "Hosts", "text-right", &num(&1.hosts)},
                    {"flagged_share", "Suspicious", "text-right", &flagged_cell(&1)},
                    {"last_seen", "Last load", "whitespace-nowrap",
                     &when_at(&1.last_seen, @current_scope)}
                  ]}
                />
              </.panel>

              <.panel :if={@tab == "hosts"} flush>
                <.empty_state :if={@rows == []} icon="hero-signal-slash" title="No loads">
                  No widget loads in this period.
                </.empty_state>
                <.sortable_table
                  :if={@rows != []}
                  id="widget-serves-hosts"
                  rows={@rows}
                  sort={@sort}
                  dir={@dir}
                  sort_url={fn sort, dir -> patch_url(@query, sort: sort, dir: dir) end}
                  row_patch={fn row -> patch_url(@query, host: row.host, page: nil) end}
                  columns={[
                    {"host", "Host", "", &(&1.host || "No publisher page")},
                    {"loads", "Loads", "text-right", &num(&1.loads)},
                    {"unique_pages", "Pages", "text-right", &num(&1.unique_pages)},
                    {"unique_ips", "IPs", "text-right", &num(&1.unique_ips)},
                    {"loads_per_ip", "Loads / IP", "text-right", & &1.loads_per_ip},
                    {"authed_share", "Signed in", "text-right", &pct(&1.authed_share)},
                    {"recipients", "Publishers", "text-right", &num(&1.recipients)},
                    {"flagged_share", "Suspicious", "text-right", &flagged_cell(&1)},
                    {"last_seen", "Last load", "whitespace-nowrap",
                     &when_at(&1.last_seen, @current_scope)}
                  ]}
                />
              </.panel>

              <div :if={@tab == "suspicious"} class="space-y-6">
                <.panel
                  :for={{kind, entries} <- @suspicious}
                  id={"widget-serves-suspicious-#{kind}"}
                  flush
                  title={"#{@flag_labels[kind]} (#{length(entries)})"}
                  description={@flag_descriptions[kind]}
                >
                  <p :if={entries == []} class="px-6 py-4 text-sm text-base-content/50">
                    Nothing flagged.
                  </p>
                  <.data_table
                    :if={entries != []}
                    id={"widget-serves-suspicious-#{kind}-table"}
                    rows={entries}
                  >
                    <:col :let={entry} label="Subject" class="max-w-[28rem] break-all">
                      {entry.subject}
                    </:col>
                    <:col :let={entry} label="Loads" class="text-right">{num(entry.count)}</:col>
                    <:col :let={entry} label="First seen" class="whitespace-nowrap">
                      {when_at(entry.first_seen, @current_scope)}
                    </:col>
                    <:col :let={entry} label="Last seen" class="whitespace-nowrap">
                      {when_at(entry.last_seen, @current_scope)}
                    </:col>
                    <:col :let={entry} class="text-right">
                      <.link
                        patch={
                          patch_url(@query, Map.to_list(entry.filter) ++ [tab: "log", page: nil])
                        }
                        class="text-sm text-primary hover:underline"
                      >
                        View loads
                      </.link>
                    </:col>
                  </.data_table>
                </.panel>
              </div>

              <.panel :if={@tab == "log"} flush>
                <.empty_state :if={@log.rows == []} icon="hero-signal-slash" title="No loads">
                  No widget loads match these filters.
                </.empty_state>
                <.data_table :if={@log.rows != []} id="widget-serves-log" rows={@log.rows}>
                  <:col :let={row} label="When" class="whitespace-nowrap text-xs text-base-content/60">
                    {when_at(row.created_at, @current_scope)}
                  </:col>
                  <:col :let={row} label="Publisher">
                    <.link
                      :if={row.recipient_id}
                      patch={patch_url(@query, recipient_id: row.recipient_id, page: nil)}
                      class="hover:underline"
                    >
                      {row.recipient_name}
                    </.link>
                    <span :if={!row.recipient_id} class="text-base-content/50">
                      {row.recipient_name}
                    </span>
                  </:col>
                  <:col :let={row} label="Host" class="max-w-[14rem] truncate">
                    <.link
                      :if={row.host}
                      patch={patch_url(@query, host: row.host, page: nil)}
                      title={row.host_page_url}
                      class="hover:underline"
                    >
                      {row.host}
                    </.link>
                    <span :if={!row.host} class="text-base-content/50">-</span>
                  </:col>
                  <:col :let={row} label="IP">
                    <.link
                      :if={row.ip_address}
                      patch={patch_url(@query, ip: row.ip_address, page: nil)}
                      class="hover:underline"
                    >
                      {row.ip_address}
                    </.link>
                  </:col>
                  <:col :let={row} label="Viewer">
                    {if row.authed, do: "Signed in", else: "Anonymous"}
                  </:col>
                  <:col :let={row} label="Connects" class="text-right">{row.connect_count}</:col>
                  <:col :let={row} label="Device">{row.device || "-"}</:col>
                  <:col
                    :let={row}
                    label="User agent"
                    class="max-w-[16rem] truncate text-xs text-base-content/60"
                  >
                    <span title={row.user_agent}>{row.user_agent || "-"}</span>
                  </:col>
                  <:col :let={row} label="Flags">
                    <div class="flex flex-wrap gap-1">
                      <.link
                        :for={flag <- row.flags}
                        patch={patch_url(@query, flag: flag, page: nil)}
                        class="rounded-full bg-warning/15 px-2 py-0.5 text-xs text-warning"
                      >
                        {@flag_labels[flag]}
                      </.link>
                    </div>
                  </:col>
                </.data_table>
                <:footer :if={@log.total > @log.per_page}>
                  <div class="flex items-center justify-between text-sm">
                    <span class="text-base-content/60">
                      Page {@log.page} of {page_count(@log)} · {num(@log.total)} loads
                    </span>
                    <div class="join">
                      <.link
                        :if={@log.page > 1}
                        patch={patch_url(@query, page: @log.page - 1)}
                        class="join-item btn btn-sm"
                      >
                        Newer
                      </.link>
                      <.link
                        :if={@log.page < page_count(@log)}
                        patch={patch_url(@query, page: @log.page + 1)}
                        class="join-item btn btn-sm"
                      >
                        Older
                      </.link>
                    </div>
                  </div>
                </:footer>
              </.panel>
            </.page>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  attr :series, :list, required: true
  attr :max, :integer, required: true
  attr :bucket, :atom, required: true

  defp loads_chart(assigns) do
    ~H"""
    <div :if={@max == 0} class="py-10 text-center text-sm text-base-content/50">
      No loads in this period.
    </div>
    <div :if={@max > 0}>
      <div class="mb-3 flex items-center gap-4 text-xs text-base-content/60">
        <span class="inline-flex items-center gap-1.5">
          <span class="size-2.5 rounded-sm bg-sponster-500"></span> Signed in
        </span>
        <span class="inline-flex items-center gap-1.5">
          <span class="size-2.5 rounded-sm bg-sponster-300/70"></span> Anonymous
        </span>
        <span class="inline-flex items-center gap-1.5">
          <span class="size-2.5 rounded-sm bg-warning"></span> Contains suspicious loads
        </span>
        <span class="ml-auto">Peak {num(@max)} per {@bucket}</span>
      </div>
      <div id="widget-serves-chart" class="flex h-40 items-end gap-px">
        <div
          :for={point <- @series}
          class="flex h-full min-w-0 flex-1 flex-col justify-end"
          title={"#{bucket_label(point.at, @bucket)}: #{point.total} loads (#{point.authed} signed in, #{point.flagged} suspicious)"}
        >
          <div :if={point.flagged > 0} class="mb-px h-1 w-full rounded-sm bg-warning"></div>
          <div
            class="w-full rounded-t-sm bg-sponster-300/70"
            style={"height: #{height(point.anon, @max)}%"}
          >
          </div>
          <div class="w-full bg-sponster-500" style={"height: #{height(point.authed, @max)}%"}></div>
        </div>
      </div>
      <div class="mt-2 flex justify-between text-xs text-base-content/50">
        <span>{bucket_label(List.first(@series).at, @bucket)}</span>
        <span>{bucket_label(List.last(@series).at, @bucket)}</span>
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :total, :integer, required: true
  attr :patch_fn, :any, required: true

  defp bar_list(assigns) do
    assigns =
      assign(assigns, :max, assigns.rows |> Enum.map(&elem(&1, 1)) |> Enum.max(fn -> 0 end))

    ~H"""
    <p :if={@rows == []} class="py-6 text-center text-sm text-base-content/50">
      No loads in this period.
    </p>
    <ul :if={@rows != []} id={@id} class="space-y-2">
      <li :for={{label, count, filter} <- @rows} class="text-sm">
        <div class="mb-1 flex items-baseline justify-between gap-3">
          <.link
            :if={@patch_fn && filter && filter.host}
            patch={@patch_fn.(filter)}
            class="min-w-0 truncate hover:underline"
          >
            {label}
          </.link>
          <span :if={!(@patch_fn && filter && filter.host)} class="min-w-0 truncate">{label}</span>
          <span class="shrink-0 text-base-content/60">
            {num(count)} · {pct(share(count, @total))}
          </span>
        </div>
        <div class="h-2 rounded bg-base-200">
          <div class="h-2 rounded bg-sponster-400/70" style={"width: #{height(count, @max)}%"}></div>
        </div>
      </li>
    </ul>
    """
  end

  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :columns, :list, required: true
  attr :sort, :string, required: true
  attr :dir, :string, required: true
  attr :sort_url, :any, required: true
  attr :row_patch, :any, required: true

  defp sortable_table(assigns) do
    ~H"""
    <div class="overflow-x-auto">
      <table class="w-full text-left text-sm">
        <thead class="border-b border-base-300 bg-base-200/40 text-xs text-base-content/60">
          <tr>
            <th :for={{key, label, class, _fun} <- @columns} class={["px-6 py-3 font-medium", class]}>
              <.link
                patch={@sort_url.(key, next_dir(key, @sort, @dir))}
                class="inline-flex items-center gap-1 hover:text-base-content"
                aria-sort={aria_sort(key, @sort, @dir)}
              >
                {label}
                <.icon
                  :if={key == @sort}
                  name={if @dir == "asc", do: "hero-chevron-up", else: "hero-chevron-down"}
                  class="size-3"
                />
              </.link>
            </th>
          </tr>
        </thead>
        <tbody id={@id} class="divide-y divide-base-300">
          <tr :for={row <- @rows} class="transition-colors hover:bg-base-200/40">
            <td
              :for={{_key, _label, class, fun} <- @columns}
              class={["px-6 py-3 align-middle", class]}
            >
              <.link patch={@row_patch.(row)} class="block">{fun.(row)}</.link>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  defp flagged_cell(%{flagged: 0}), do: "-"
  defp flagged_cell(row), do: "#{pct(row.flagged_share)} (#{num(row.flagged)})"

  defp next_dir(key, key, "desc"), do: "asc"
  defp next_dir(key, key, "asc"), do: "desc"
  defp next_dir("name", _sort, _dir), do: "asc"
  defp next_dir("host", _sort, _dir), do: "asc"
  defp next_dir(_key, _sort, _dir), do: "desc"

  defp aria_sort(key, key, "asc"), do: "ascending"
  defp aria_sort(key, key, "desc"), do: "descending"
  defp aria_sort(_key, _sort, _dir), do: "none"

  defp sort_rows(rows, sort, dir) do
    key = String.to_existing_atom(sort)
    direction = if dir == "asc", do: :asc, else: :desc
    Enum.sort_by(rows, &sort_value(Map.get(&1, key)), direction)
  end

  defp sort_value(nil), do: ""
  defp sort_value(%NaiveDateTime{} = at), do: NaiveDateTime.to_iso8601(at)
  defp sort_value(value) when is_binary(value), do: String.downcase(value)
  defp sort_value(value), do: value

  defp parse_sort(params, allowed, default) do
    sort = if params["sort"] in allowed, do: params["sort"], else: default
    dir = if params["dir"] in ["asc", "desc"], do: params["dir"], else: next_dir(sort, nil, nil)
    {sort, dir}
  end

  defp parse_bucket("hour", _period), do: :hour
  defp parse_bucket("day", _period), do: :day
  defp parse_bucket(_, "24h"), do: :hour
  defp parse_bucket(_, _), do: :day

  defp parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {n, ""} when n > 0 -> n
      _ -> 1
    end
  end

  defp parse_page(_), do: 1

  defp parse_filters(params) do
    flag = Enum.find(Reporting.flags(), &(Atom.to_string(&1) == params["flag"]))

    %{
      recipient_id: blank(params["recipient_id"]),
      host: blank(params["host"]),
      ip: blank(params["ip"]),
      page_load_id: blank(params["page_load_id"]),
      flag: flag
    }
  end

  defp blank(value) when is_binary(value) and value != "", do: value
  defp blank(_), do: nil

  defp active_filters(filters) do
    [
      filters.recipient_id && {:recipient_id, "Publisher ##{filters.recipient_id}"},
      filters.host && {:host, "Host #{filters.host}"},
      filters.ip && {:ip, "IP #{filters.ip}"},
      filters.page_load_id && {:page_load_id, "Page #{filters.page_load_id}"},
      filters.flag && {:flag, "Flag: #{@flag_labels[filters.flag]}"}
    ]
    |> Enum.filter(& &1)
  end

  @param_keys ~w(period bucket tab sort dir page recipient_id host ip page_load_id flag)a

  defp current_query(assigns) do
    %{
      period: assigns.period,
      bucket: assigns.bucket,
      tab: assigns.tab,
      sort: assigns[:sort],
      dir: assigns[:dir],
      page: if(assigns.page > 1, do: assigns.page),
      recipient_id: assigns.filters.recipient_id,
      host: assigns.filters.host,
      ip: assigns.filters.ip,
      page_load_id: assigns.filters.page_load_id,
      flag: assigns.filters.flag
    }
  end

  defp patch_url(%Phoenix.LiveView.Socket{assigns: assigns}, overrides),
    do: patch_url(assigns.query, overrides)

  defp patch_url(current, overrides) do
    query =
      current
      |> Map.merge(Map.new(overrides))
      |> Map.take(@param_keys)
      |> Enum.reject(fn {_k, v} -> v in [nil, ""] end)
      |> Map.new(fn {k, v} -> {k, to_string(v)} end)

    ~p"/admin/widget_serves?#{query}"
  end

  defp page_count(%{total: total, per_page: per_page}),
    do: max(div(total + per_page - 1, per_page), 1)

  defp height(_value, max) when max <= 0, do: 0
  defp height(0, _max), do: 0
  defp height(value, max), do: Float.round(value / max * 100, 2)

  defp share(_part, 0), do: 0.0
  defp share(part, total), do: part / total

  defp ratio(_loads, 0), do: "0"
  defp ratio(loads, ips), do: :erlang.float_to_binary(loads / ips, decimals: 1)

  defp pct(ratio) when is_number(ratio) do
    value = ratio * 100

    cond do
      value == 0 -> "0%"
      value < 1 -> "<1%"
      true -> "#{round(value)}%"
    end
  end

  defp num(n) when is_integer(n) do
    n
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  defp num(n), do: to_string(n)

  defp bucket_label(at, :hour), do: Calendar.strftime(at, "%b %-d %H:00 UTC")
  defp bucket_label(at, :day), do: Calendar.strftime(at, "%b %-d")

  defp when_at(at, scope), do: Qlarius.DateTime.format_for_user(at, scope.user, :standard)
end
