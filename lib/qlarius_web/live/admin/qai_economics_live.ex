defmodule QlariusWeb.Admin.QaiEconomicsLive do
  @moduledoc """
  Leadership dashboard for Qai pricing decisions, built on measured usage
  (`qai_messages.usage`), not projections.

  Reliability posture, stated on the page itself: costs are estimates from
  editable rates (provider bills are the ground truth); turns with no usage
  (stopped or failed streams) are counted as unmeasured, never averaged in;
  and because fleeting sessions hard-delete, long windows are floors - the
  daily series is the trustworthy shape.

  The pricing panel prices a session against the measured distribution: a
  flat price has to clear p90 cost, not the mean, or heavy sessions invert
  the margin.
  """

  use QlariusWeb, :live_view

  alias Qlarius.Qai.Economics
  alias QlariusWeb.Components.AdminSidebar
  alias QlariusWeb.Components.AdminTopbar

  @windows [7, 30, 90]
  @default_price 0.25
  @default_engagement_revenue 0.15

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Qai Economics")
     |> assign(:days, 30)
     |> assign(:windows, @windows)
     |> assign(:rates, Economics.default_rates())
     |> assign(:price, @default_price)
     |> assign(:engagement_revenue, @default_engagement_revenue)
     |> assign_data()}
  end

  @impl true
  def handle_event("set_window", %{"days" => days}, socket) do
    {:noreply, socket |> assign(:days, String.to_integer(days)) |> assign_data()}
  end

  def handle_event("set_scenario", params, socket) do
    rates = %{
      frontier: %{
        input: parse_rate(params["frontier_input"], socket.assigns.rates.frontier.input),
        output: parse_rate(params["frontier_output"], socket.assigns.rates.frontier.output)
      },
      cheap: %{
        input: parse_rate(params["cheap_input"], socket.assigns.rates.cheap.input),
        output: parse_rate(params["cheap_output"], socket.assigns.rates.cheap.output)
      }
    }

    {:noreply,
     socket
     |> assign(:rates, rates)
     |> assign(:price, parse_rate(params["price"], socket.assigns.price))
     |> assign(
       :engagement_revenue,
       parse_rate(params["engagement_revenue"], socket.assigns.engagement_revenue)
     )
     |> assign_data()}
  end

  defp assign_data(socket) do
    days = socket.assigns.days
    rates = socket.assigns.rates

    totals = Economics.totals(days)
    breakdown = Economics.model_breakdown(days)
    distribution = Economics.session_cost_distribution(days, rates)

    # Cost totals priced per model row (tier-aware), not the blended total.
    est_cost = breakdown |> Enum.map(&Economics.cost(&1, rates)) |> Enum.sum()
    uncached = breakdown |> Enum.map(&Economics.uncached_cost(&1, rates)) |> Enum.sum()

    cost_per_session = if totals.sessions > 0, do: est_cost / totals.sessions, else: 0.0

    socket
    |> assign(:totals, totals)
    |> assign(:breakdown, breakdown)
    |> assign(:distribution, distribution)
    |> assign(:daily, Economics.daily_series(days))
    |> assign(:suggestions, Economics.suggestion_conversion(days))
    |> assign(:est_cost, est_cost)
    |> assign(:cache_savings, uncached - est_cost)
    |> assign(:cache_hit, Economics.cache_hit_share(totals))
    |> assign(:cost_per_session, cost_per_session)
  end

  defp parse_rate(nil, fallback), do: fallback

  defp parse_rate(value, fallback) do
    case Float.parse(String.trim(value)) do
      {parsed, _} when parsed >= 0 -> parsed
      _ -> fallback
    end
  end

  defp daily_cost(day, rates) do
    # Daily rows carry no model split; frontier rates keep the estimate
    # conservative (matches Economics.cost/2 for model-less rows).
    Economics.cost(day, rates)
  end

  defp usd(value, decimals \\ 4)
  defp usd(value, decimals) when is_number(value), do: "$#{:erlang.float_to_binary(value * 1.0, decimals: decimals)}"
  defp usd(_, _), do: "-"

  defp pct(nil), do: "-"
  defp pct(ratio), do: "#{round(ratio * 100)}%"

  defp tokens(n) when n >= 1_000_000, do: "#{Float.round(n / 1_000_000, 2)}M"
  defp tokens(n) when n >= 1_000, do: "#{Float.round(n / 1_000, 1)}K"
  defp tokens(n), do: "#{n}"

  defp bar_width(_value, max) when max <= 0, do: 0
  defp bar_width(value, max), do: max(round(value / max * 100), 2)

  defp margin_class(margin) when margin > 0, do: "text-success"
  defp margin_class(_), do: "text-error"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin {assigns}>
      <div class="flex h-screen">
        <AdminSidebar.sidebar current_user={@current_scope.user} />

        <div class="flex min-w-0 grow flex-col">
          <AdminTopbar.topbar current_user={@current_scope.user} />

          <div class="overflow-auto">
            <div class="p-6 max-w-6xl">
              <div class="flex justify-between items-center mb-2">
                <h1 class="text-2xl font-bold">Qai Economics</h1>
                <div class="join">
                  <button
                    :for={w <- @windows}
                    phx-click="set_window"
                    phx-value-days={w}
                    class={"join-item btn btn-sm #{if @days == w, do: "btn-active"}"}
                  >
                    {w}d
                  </button>
                </div>
              </div>

              <p class="text-sm text-base-content/60 mb-6">
                Measured from stored per-turn provider usage. Costs are estimates from the
                editable rates below; provider invoices are ground truth. Fleeting sessions
                hard-delete after expiry, so totals in long windows are floors.
              </p>

              <%!-- KPI row --%>
              <div class="stats stats-vertical lg:stats-horizontal shadow-sm bg-base-200 w-full border border-base-300 mb-6">
                <div class="stat">
                  <div class="stat-title text-xs opacity-60">Sessions</div>
                  <div class="stat-value text-xl">{@totals.sessions}</div>
                  <div class="stat-desc">{@totals.me_files} MeFiles</div>
                </div>
                <div class="stat">
                  <div class="stat-title text-xs opacity-60">Assistant Turns</div>
                  <div class="stat-value text-xl">{@totals.turns}</div>
                  <div class="stat-desc">
                    {if @totals.sessions > 0,
                      do: "#{Float.round(@totals.turns / @totals.sessions, 1)}/session"}
                    {if @totals.unmeasured > 0, do: "(#{@totals.unmeasured} unmeasured)"}
                  </div>
                </div>
                <div class="stat">
                  <div class="stat-title text-xs opacity-60">Est. COGS</div>
                  <div class="stat-value text-xl text-primary">{usd(@est_cost, 2)}</div>
                  <div class="stat-desc">{usd(@cost_per_session)}/session avg</div>
                </div>
                <div class="stat">
                  <div class="stat-title text-xs opacity-60">Session Cost p50 / p90</div>
                  <div class="stat-value text-xl">{usd(@distribution.p50)}</div>
                  <div class="stat-desc">p90 {usd(@distribution.p90)} · max {usd(@distribution.max)}</div>
                </div>
                <div class="stat">
                  <div class="stat-title text-xs opacity-60">Cache Hit</div>
                  <div class="stat-value text-xl text-success">{pct(@cache_hit)}</div>
                  <div class="stat-desc">saved {usd(@cache_savings, 2)} vs uncached</div>
                </div>
              </div>

              <%!-- Pricing scenario --%>
              <div class="card bg-base-100 border border-base-300 mb-6">
                <div class="card-body">
                  <h2 class="card-title">Pricing Scenario</h2>
                  <p class="text-sm text-base-content/60">
                    Applied to the measured distribution above. A flat session price should
                    clear p90 cost, not the average, or heavy sessions run negative.
                  </p>

                  <form id="pricing-scenario-form" phx-change="set_scenario" class="grid grid-cols-2 md:grid-cols-5 gap-3 py-2">
                    <label class="form-control">
                      <span class="label-text text-xs">Price / session $</span>
                      <input type="text" name="price" value={@price} class="input input-bordered input-sm" />
                    </label>
                    <label class="form-control">
                      <span class="label-text text-xs">Frontier in $/MTok</span>
                      <input type="text" name="frontier_input" value={@rates.frontier.input} class="input input-bordered input-sm" />
                    </label>
                    <label class="form-control">
                      <span class="label-text text-xs">Frontier out $/MTok</span>
                      <input type="text" name="frontier_output" value={@rates.frontier.output} class="input input-bordered input-sm" />
                    </label>
                    <label class="form-control">
                      <span class="label-text text-xs">Cheap in $/MTok</span>
                      <input type="text" name="cheap_input" value={@rates.cheap.input} class="input input-bordered input-sm" />
                    </label>
                    <label class="form-control">
                      <span class="label-text text-xs">Cheap out $/MTok</span>
                      <input type="text" name="cheap_output" value={@rates.cheap.output} class="input input-bordered input-sm" />
                    </label>
                  </form>

                  <div class="overflow-x-auto">
                    <table class="table table-sm">
                      <thead>
                        <tr>
                          <th>Session priced at {usd(@price, 2)}</th>
                          <th class="text-right">Margin</th>
                          <th class="text-right">Margin %</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr>
                          <td>vs average cost ({usd(@cost_per_session)})</td>
                          <td class={"text-right font-semibold #{margin_class(@price - @cost_per_session)}"}>
                            {usd(@price - @cost_per_session)}
                          </td>
                          <td class="text-right">
                            {if @price > 0, do: pct((@price - @cost_per_session) / @price)}
                          </td>
                        </tr>
                        <tr>
                          <td>vs p50 session ({usd(@distribution.p50)})</td>
                          <td class={"text-right font-semibold #{margin_class(@price - @distribution.p50)}"}>
                            {usd(@price - @distribution.p50)}
                          </td>
                          <td class="text-right">
                            {if @price > 0, do: pct((@price - @distribution.p50) / @price)}
                          </td>
                        </tr>
                        <tr>
                          <td>vs p90 session ({usd(@distribution.p90)})</td>
                          <td class={"text-right font-semibold #{margin_class(@price - @distribution.p90)}"}>
                            {usd(@price - @distribution.p90)}
                          </td>
                          <td class="text-right">
                            {if @price > 0, do: pct((@price - @distribution.p90) / @price)}
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </div>

                  <div class="text-sm text-base-content/70 pt-1">
                    Break-even flat price is p90 cost:
                    <span class="font-semibold">{usd(@distribution.p90)}</span>.
                  </div>
                </div>
              </div>

              <%!-- Sponsorship coverage: funding, not margin --%>
              <div class="card bg-base-100 border border-base-300 mb-6">
                <div class="card-body">
                  <h2 class="card-title">Sponsorship Coverage</h2>
                  <p class="text-sm text-base-content/60">
                    Funding, not margin: sponsorship changes who pays the session price,
                    never the session's margin. This asks whether attention income covers
                    usage - the "attention pays for intelligence" ratio.
                  </p>
                  <form id="sponsorship-coverage-form" phx-change="set_scenario" class="max-w-xs py-1">
                    <label class="form-control">
                      <span class="label-text text-xs">Sponster platform rev / engagement $</span>
                      <input
                        type="text"
                        name="engagement_revenue"
                        value={@engagement_revenue}
                        class="input input-bordered input-sm"
                      />
                    </label>
                  </form>
                  <div class="text-sm text-base-content/70">
                    One engagement at {usd(@engagement_revenue, 2)} covers
                    <span class="font-semibold">
                      {if @cost_per_session > 0,
                        do: Float.round(@engagement_revenue / @cost_per_session, 1),
                        else: "-"}
                    </span>
                    average sessions of COGS, or
                    <span class="font-semibold">
                      {if @price > 0, do: Float.round(@engagement_revenue / @price, 2), else: "-"}
                    </span>
                    sessions at the {usd(@price, 2)} price.
                  </div>
                </div>
              </div>

              <%!-- Daily trend --%>
              <div class="card bg-base-100 border border-base-300 mb-6">
                <div class="card-body">
                  <h2 class="card-title">Daily Trend</h2>
                  <% max_cost = @daily |> Enum.map(&daily_cost(&1, @rates)) |> Enum.max(fn -> 0 end) %>
                  <div class="overflow-x-auto">
                    <table class="table table-sm table-zebra">
                      <thead>
                        <tr>
                          <th>Day</th>
                          <th class="text-right">Sessions</th>
                          <th class="text-right">Turns</th>
                          <th class="text-right">Input</th>
                          <th class="text-right">Cache Read</th>
                          <th class="text-right">Output</th>
                          <th class="text-right">Est. Cost</th>
                          <th class="w-40"></th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr :for={day <- Enum.reverse(@daily)}>
                          <td class="whitespace-nowrap">{day.day}</td>
                          <td class="text-right">{day.sessions}</td>
                          <td class="text-right">{day.turns}</td>
                          <td class="text-right">{tokens(day.input)}</td>
                          <td class="text-right">{tokens(day.cache_read)}</td>
                          <td class="text-right">{tokens(day.output)}</td>
                          <td class="text-right">{usd(daily_cost(day, @rates))}</td>
                          <td>
                            <div
                              class="bg-primary/60 rounded h-2"
                              style={"width: #{bar_width(daily_cost(day, @rates), max_cost)}%"}
                            >
                            </div>
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                  <p :if={@daily == []} class="text-sm text-base-content/60">
                    No measured turns in this window yet.
                  </p>
                </div>
              </div>

              <%!-- Model breakdown --%>
              <div class="card bg-base-100 border border-base-300 mb-6">
                <div class="card-body">
                  <h2 class="card-title">By Model</h2>
                  <div class="overflow-x-auto">
                    <table class="table table-sm">
                      <thead>
                        <tr>
                          <th>Model</th>
                          <th class="text-right">Turns</th>
                          <th class="text-right">Input</th>
                          <th class="text-right">Cache Read</th>
                          <th class="text-right">Cache Write</th>
                          <th class="text-right">Output</th>
                          <th class="text-right">Est. Cost</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr :for={row <- @breakdown}>
                          <td class="font-mono text-xs">{row.model}</td>
                          <td class="text-right">{row.turns}</td>
                          <td class="text-right">{tokens(row.input)}</td>
                          <td class="text-right">{tokens(row.cache_read)}</td>
                          <td class="text-right">{tokens(row.cache_write)}</td>
                          <td class="text-right">{tokens(row.output)}</td>
                          <td class="text-right">{usd(Economics.cost(row, @rates))}</td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>

              <%!-- Suggestion conversion --%>
              <div class="card bg-base-100 border border-base-300 mb-6">
                <div class="card-body">
                  <h2 class="card-title">Suggestion Loop (value beyond margin)</h2>
                  <p class="text-sm text-base-content/60">
                    Accepted suggestions are MeFile density created per session - the data
                    flywheel side of the unit economics.
                  </p>
                  <div class="overflow-x-auto">
                    <table class="table table-sm">
                      <thead>
                        <tr>
                          <th>Client</th>
                          <th class="text-right">Filed</th>
                          <th class="text-right">Accepted</th>
                          <th class="text-right">Dismissed</th>
                          <th class="text-right">Pending</th>
                          <th class="text-right">Acceptance</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr :for={row <- @suggestions}>
                          <td>{row.client}</td>
                          <td class="text-right">{row.filed}</td>
                          <td class="text-right text-success">{row.accepted}</td>
                          <td class="text-right">{row.dismissed}</td>
                          <td class="text-right">{row.pending}</td>
                          <td class="text-right font-semibold">{pct(row.acceptance_rate)}</td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                  <p :if={@suggestions == []} class="text-sm text-base-content/60">
                    No suggestions filed in this window.
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end
end
