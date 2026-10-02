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

  import QlariusWeb.Components.MarketerUI

  alias Qlarius.Qai.Economics
  alias QlariusWeb.Components.AdminSidebar
  alias QlariusWeb.Components.AdminTopbar

  @windows [7, 30, 90]
  @default_price 0.25

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Qai Economics")
     |> assign(:days, 30)
     |> assign(:windows, @windows)
     |> assign(:rates, Economics.default_rates())
     |> assign(:price, @default_price)
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

  defp usd(value, decimals) when is_number(value),
    do: "$#{:erlang.float_to_binary(value * 1.0, decimals: decimals)}"

  defp usd(_, _), do: "-"

  defp pct(nil), do: "-"
  defp pct(ratio), do: "#{round(ratio * 100)}%"

  defp tokens(n) when n >= 1_000_000, do: "#{Float.round(n / 1_000_000, 2)}M"
  defp tokens(n) when n >= 1_000, do: "#{Float.round(n / 1_000, 1)}K"
  defp tokens(n), do: "#{n}"

  defp max_daily_cost(daily, rates) do
    daily |> Enum.map(&daily_cost(&1, rates)) |> Enum.max(fn -> 0 end)
  end

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
            <.page>
              <.page_header
                title="Qai Economics"
                subtitle="Measured from stored per-turn provider usage. Costs are estimates from the editable rates below; provider invoices are ground truth. Fleeting sessions hard-delete after expiry, so totals in long windows are floors."
              >
                <:actions>
                  <div class="inline-flex rounded-lg border border-base-300 bg-base-100 p-0.5">
                    <button
                      :for={w <- @windows}
                      type="button"
                      phx-click="set_window"
                      phx-value-days={w}
                      aria-pressed={to_string(@days == w)}
                      class={segment_class(@days == w)}
                    >
                      {w}d
                    </button>
                  </div>
                </:actions>
              </.page_header>

              <div class="mb-8 grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
                <.stat_tile
                  label="Sessions"
                  icon="hero-chat-bubble-left-right"
                  hint={"#{@totals.me_files} MeFiles"}
                >
                  {@totals.sessions}
                </.stat_tile>
                <.stat_tile label="Assistant turns" icon="hero-arrow-path" hint={turns_hint(@totals)}>
                  {@totals.turns}
                </.stat_tile>
                <.stat_tile
                  label="Est. COGS"
                  icon="hero-banknotes"
                  hint={"#{usd(@cost_per_session)}/session avg"}
                >
                  {usd(@est_cost, 2)}
                </.stat_tile>
                <.stat_tile
                  label="Session cost p50 / p90"
                  icon="hero-chart-bar"
                  hint={"p90 #{usd(@distribution.p90)} · max #{usd(@distribution.max)}"}
                >
                  {usd(@distribution.p50)}
                </.stat_tile>
                <.stat_tile
                  label="Cache hit"
                  icon="hero-bolt"
                  value_class="text-success"
                  hint={"saved #{usd(@cache_savings, 2)} vs uncached"}
                >
                  {pct(@cache_hit)}
                </.stat_tile>
              </div>

              <div class="space-y-8">
                <.panel
                  title="Pricing Scenario"
                  description="Applied to the measured distribution above. A flat session price should clear p90 cost, not the average, or heavy sessions run negative."
                >
                  <form
                    id="pricing-scenario-form"
                    phx-change="set_scenario"
                    class="grid grid-cols-2 gap-3 md:grid-cols-5"
                  >
                    <.rate_input name="price" label="Price / session $" value={@price} />
                    <.rate_input
                      name="frontier_input"
                      label="Frontier in $/MTok"
                      value={@rates.frontier.input}
                    />
                    <.rate_input
                      name="frontier_output"
                      label="Frontier out $/MTok"
                      value={@rates.frontier.output}
                    />
                    <.rate_input
                      name="cheap_input"
                      label="Cheap in $/MTok"
                      value={@rates.cheap.input}
                    />
                    <.rate_input
                      name="cheap_output"
                      label="Cheap out $/MTok"
                      value={@rates.cheap.output}
                    />
                  </form>

                  <div class="-mx-6 overflow-x-auto border-y border-base-300">
                    <table class="w-full text-left text-sm">
                      <thead class="border-b border-base-300 bg-base-200/40 text-xs text-base-content/60">
                        <tr>
                          <th class="px-6 py-3 font-medium">Session priced at {usd(@price, 2)}</th>
                          <th class="px-6 py-3 text-right font-medium">Margin</th>
                          <th class="px-6 py-3 text-right font-medium">Margin %</th>
                        </tr>
                      </thead>
                      <tbody class="divide-y divide-base-300">
                        <tr
                          :for={
                            {label, cost} <- [
                              {"vs average cost", @cost_per_session},
                              {"vs p50 session", @distribution.p50},
                              {"vs p90 session", @distribution.p90}
                            ]
                          }
                          class="transition-colors hover:bg-base-200/40"
                        >
                          <td class="px-6 py-3">
                            {label} <span class="text-base-content/50">({usd(cost)})</span>
                          </td>
                          <td class={[
                            "px-6 py-3 text-right font-semibold",
                            margin_class(@price - cost)
                          ]}>
                            {usd(@price - cost)}
                          </td>
                          <td class="px-6 py-3 text-right">
                            {if @price > 0, do: pct((@price - cost) / @price)}
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </div>

                  <p class="text-sm text-base-content/70">
                    Break-even flat price is p90 cost: <span class="font-semibold">{usd(@distribution.p90)}</span>.
                  </p>
                </.panel>

                <.panel flush title="Daily Trend">
                  <.empty_state :if={@daily == []} icon="hero-calendar-days" title="No measured turns">
                    No measured turns in this window yet.
                  </.empty_state>
                  <.data_table :if={@daily != []} id="qai-daily-trend" rows={Enum.reverse(@daily)}>
                    <:col :let={day} label="Day" class="whitespace-nowrap">{day.day}</:col>
                    <:col :let={day} label="Sessions" class="text-right">{day.sessions}</:col>
                    <:col :let={day} label="Turns" class="text-right">{day.turns}</:col>
                    <:col :let={day} label="Input" class="text-right">{tokens(day.input)}</:col>
                    <:col :let={day} label="Cache read" class="text-right">
                      {tokens(day.cache_read)}
                    </:col>
                    <:col :let={day} label="Output" class="text-right">{tokens(day.output)}</:col>
                    <:col :let={day} label="Est. cost" class="text-right">
                      {usd(daily_cost(day, @rates))}
                    </:col>
                    <:col :let={day} class="w-40">
                      <div
                        class="h-2 rounded bg-primary/60"
                        style={"width: #{bar_width(daily_cost(day, @rates), max_daily_cost(@daily, @rates))}%"}
                      >
                      </div>
                    </:col>
                  </.data_table>
                </.panel>

                <.panel flush title="By Model">
                  <.empty_state :if={@breakdown == []} icon="hero-cpu-chip" title="No model usage">
                    No measured turns in this window yet.
                  </.empty_state>
                  <.data_table :if={@breakdown != []} id="qai-model-breakdown" rows={@breakdown}>
                    <:col :let={row} label="Model">
                      <span class="font-mono text-xs">{row.model}</span>
                    </:col>
                    <:col :let={row} label="Turns" class="text-right">{row.turns}</:col>
                    <:col :let={row} label="Input" class="text-right">{tokens(row.input)}</:col>
                    <:col :let={row} label="Cache read" class="text-right">
                      {tokens(row.cache_read)}
                    </:col>
                    <:col :let={row} label="Cache write" class="text-right">
                      {tokens(row.cache_write)}
                    </:col>
                    <:col :let={row} label="Output" class="text-right">{tokens(row.output)}</:col>
                    <:col :let={row} label="Est. cost" class="text-right">
                      {usd(Economics.cost(row, @rates))}
                    </:col>
                  </.data_table>
                </.panel>

                <.panel
                  flush
                  title="Suggestion Loop (value beyond margin)"
                  description="Accepted suggestions are MeFile density created per session, the data flywheel side of the unit economics."
                >
                  <.empty_state
                    :if={@suggestions == []}
                    icon="hero-light-bulb"
                    title="No suggestions"
                  >
                    No suggestions filed in this window.
                  </.empty_state>
                  <.data_table :if={@suggestions != []} id="qai-suggestions" rows={@suggestions}>
                    <:col :let={row} label="Client">{row.client}</:col>
                    <:col :let={row} label="Filed" class="text-right">{row.filed}</:col>
                    <:col :let={row} label="Accepted" class="text-right text-success">
                      {row.accepted}
                    </:col>
                    <:col :let={row} label="Dismissed" class="text-right">{row.dismissed}</:col>
                    <:col :let={row} label="Pending" class="text-right">{row.pending}</:col>
                    <:col :let={row} label="Acceptance" class="text-right font-semibold">
                      {pct(row.acceptance_rate)}
                    </:col>
                  </.data_table>
                </.panel>
              </div>
            </.page>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :value, :any, required: true

  defp rate_input(assigns) do
    ~H"""
    <label class="block">
      <span class="mb-1 block text-xs text-base-content/60">{@label}</span>
      <input type="text" name={@name} value={@value} class="input input-sm w-full" />
    </label>
    """
  end

  defp turns_hint(totals) do
    [
      totals.sessions > 0 && "#{Float.round(totals.turns / totals.sessions, 1)}/session",
      totals.unmeasured > 0 && "(#{totals.unmeasured} unmeasured)"
    ]
    |> Enum.filter(& &1)
    |> Enum.join(" ")
    |> case do
      "" -> nil
      hint -> hint
    end
  end

  defp segment_class(true),
    do: "btn btn-sm border-0 bg-primary/10 text-primary shadow-none hover:bg-primary/15"

  defp segment_class(false), do: "btn btn-sm btn-ghost border-0 text-base-content/70"
end
