defmodule QlariusWeb.Admin.QaiOracleLive do
  @moduledoc """
  Admin view of MeCP oracle activity: what assistants (Qai and other
  connected clients) read, what they suggest, and what they ask about that
  the trait taxonomy doesn't cover.

  Activity comes from the access log (counts, never content). Taxonomy gaps
  come from `Qlarius.MeCP.TaxonomyGaps`, which is de-identified (no link to
  who asked). The list defaults to subjects raised by 3+ different people;
  admins can switch to All or 10+.
  """

  use QlariusWeb, :live_view

  import QlariusWeb.Components.MarketerUI

  alias Qlarius.MeCP.OracleStats
  alias Qlarius.MeCP.TaxonomyGaps
  alias QlariusWeb.Components.AdminSidebar
  alias QlariusWeb.Components.AdminTopbar

  @windows [7, 30, 90]
  # People filter for taxonomy gaps: {label, minimum distinct people}
  @gap_filters [{"All", 1}, {"3+", 3}, {"10+", 10}]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Qai Oracle")
     |> assign(:days, 30)
     |> assign(:windows, @windows)
     |> assign(:gap_filters, @gap_filters)
     |> assign(:gap_min, TaxonomyGaps.min_people())
     |> assign_data()}
  end

  @impl true
  def handle_event("set_window", %{"days" => days}, socket) do
    {:noreply, socket |> assign(:days, String.to_integer(days)) |> assign_data()}
  end

  def handle_event("set_gap_min", %{"min" => min}, socket) do
    min = String.to_integer(min)

    if Enum.any?(@gap_filters, fn {_label, value} -> value == min end) do
      {:noreply, socket |> assign(:gap_min, min) |> assign_gaps()}
    else
      {:noreply, socket}
    end
  end

  defp assign_data(socket) do
    days = socket.assigns.days

    socket
    |> assign(:totals, OracleStats.totals(days))
    |> assign(:daily, OracleStats.daily(days))
    |> assign(:clients, OracleStats.by_client(days))
    |> assign(:top_traits, OracleStats.top_traits(days))
    |> assign(:suggestions, OracleStats.suggestions_by_trait(days))
    |> assign(:orphans, TaxonomyGaps.orphan_demand(days))
    |> assign_gaps()
  end

  defp assign_gaps(socket) do
    %{days: days, gap_min: min} = socket.assigns

    socket
    |> assign(:gaps, TaxonomyGaps.list_subjects(days, min_people: min))
    |> assign(:hidden_gaps, TaxonomyGaps.hidden_subject_count(days, min_people: min))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin {assigns}>
      <div class="flex h-screen">
        <AdminSidebar.sidebar current_user={@current_scope.user} current_path={@current_path} />

        <div class="flex min-w-0 grow flex-col">
          <AdminTopbar.topbar current_user={@current_scope.user} />

          <div class="overflow-auto">
            <.page>
              <.page_header
                title="Qai Oracle"
                subtitle="What connected assistants read and suggest, and what people ask them about that our traits don't cover. Activity is counted from the MeCP access log (no content is stored). Taxonomy gaps are de-identified."
              >
                <:actions>
                  <.link
                    navigate={~p"/admin/mecp_access_log"}
                    class="btn btn-sm btn-ghost border-0 text-base-content/70"
                  >
                    Access log
                  </.link>
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
                  label="Oracle reads"
                  icon="hero-magnifying-glass"
                  hint={"#{@totals.asks} asks · #{@totals.searches} searches"}
                >
                  {@totals.asks + @totals.searches}
                </.stat_tile>
                <.stat_tile label="Capsule reads" icon="hero-document-text">
                  {@totals.capsules}
                </.stat_tile>
                <.stat_tile label="Suggestions filed" icon="hero-light-bulb">
                  {@totals.suggestions}
                </.stat_tile>
                <.stat_tile
                  label="Active grants"
                  icon="hero-key"
                  hint={"#{@totals.me_files} MeFiles"}
                >
                  {@totals.grants}
                </.stat_tile>
                <.stat_tile
                  label="Taxonomy gaps"
                  icon="hero-sparkles"
                  hint={gap_hint(@gap_min, @hidden_gaps)}
                >
                  {length(@gaps)}
                </.stat_tile>
              </div>

              <div class="space-y-8">
                <.panel
                  flush
                  title="Taxonomy Gaps"
                  description="Subjects assistants asked about that our traits don't cover: searches with no match or only a category-name match, unknown trait names in ask_me or suggest_tag. De-identified: no one can be identified from this list. Filter by how many different people asked. Candidates for new trait sets."
                >
                  <:actions>
                    <div
                      class="inline-flex rounded-lg border border-base-300 bg-base-100 p-0.5"
                      role="group"
                      aria-label="People who asked"
                    >
                      <button
                        :for={{label, min} <- @gap_filters}
                        type="button"
                        phx-click="set_gap_min"
                        phx-value-min={min}
                        aria-pressed={to_string(@gap_min == min)}
                        class={segment_class(@gap_min == min)}
                      >
                        {label}
                      </button>
                    </div>
                  </:actions>
                  <.empty_state :if={@gaps == []} icon="hero-sparkles" title="No gaps to show">
                    Nothing {gap_filter_phrase(@gap_min)} in this window{if @hidden_gaps > 0,
                      do: " (#{subjects(@hidden_gaps)} from fewer people)"}.
                  </.empty_state>
                  <.data_table :if={@gaps != []} id="oracle-gaps" rows={@gaps}>
                    <:col :let={gap} label="Subject">
                      <span class="font-medium">{gap.subject}</span>
                    </:col>
                    <:col :let={gap} label="People" class="text-right font-semibold">
                      {gap.people}
                    </:col>
                    <:col :let={gap} label="Mentions" class="text-right">{gap.mentions}</:col>
                    <:col :let={gap} label="How">
                      <span class="flex flex-wrap gap-1">
                        <span
                          :for={reason <- gap.reasons}
                          class="rounded-full bg-base-200 px-2 py-0.5 text-xs text-base-content/70"
                        >
                          {reason_label(reason)}
                        </span>
                      </span>
                    </:col>
                    <:col :let={gap} label="Nearest trait">
                      <span class="text-base-content/70">{gap.nearest_trait || "None"}</span>
                    </:col>
                    <:col :let={gap} label="Values mentioned">
                      <span class="text-base-content/70">{Enum.join(gap.values, ", ")}</span>
                    </:col>
                    <:col :let={gap} label="Seen" class="whitespace-nowrap text-base-content/60">
                      {seen(gap)}
                    </:col>
                  </.data_table>
                </.panel>

                <.panel
                  flush
                  title="Orphaned Traits Still Wanted"
                  description="Traits in no active survey that assistants still suggest, counting suggestions already filed and new ones refused. People still bring these up: consider putting them back in a survey."
                >
                  <.empty_state :if={@orphans == []} icon="hero-archive-box" title="None">
                    No suggestions for orphaned traits in this window.
                  </.empty_state>
                  <.data_table :if={@orphans != []} id="oracle-orphans" rows={@orphans}>
                    <:col :let={row} label="Trait">{row.trait}</:col>
                    <:col :let={row} label="People" class="text-right font-semibold">
                      {row.people}
                    </:col>
                    <:col :let={row} label="Mentions" class="text-right">{row.mentions}</:col>
                    <:col :let={row} label="Last seen" class="whitespace-nowrap text-base-content/60">
                      {format_day(row.last_seen)}
                    </:col>
                  </.data_table>
                </.panel>

                <.panel flush title="Daily Activity">
                  <.empty_state :if={@daily == []} icon="hero-calendar-days" title="No activity">
                    No oracle activity in this window.
                  </.empty_state>
                  <.data_table :if={@daily != []} id="oracle-daily" rows={Enum.reverse(@daily)}>
                    <:col :let={day} label="Day" class="whitespace-nowrap">{day.day}</:col>
                    <:col :let={day} label="Asks" class="text-right">{day.asks}</:col>
                    <:col :let={day} label="Searches" class="text-right">{day.searches}</:col>
                    <:col :let={day} label="Capsules" class="text-right">{day.capsules}</:col>
                    <:col :let={day} label="Suggestions" class="text-right">
                      {day.suggestions}
                    </:col>
                    <:col :let={day} label="Total" class="text-right font-semibold">
                      {day.total}
                    </:col>
                    <:col :let={day} class="w-40">
                      <div
                        class="h-2 rounded bg-primary/60"
                        style={"width: #{bar_width(day.total, max_total(@daily))}%"}
                      >
                      </div>
                    </:col>
                  </.data_table>
                </.panel>

                <div class="grid gap-8 xl:grid-cols-2">
                  <.panel flush title="By Assistant">
                    <.empty_state :if={@clients == []} icon="hero-cpu-chip" title="No clients">
                      No assistant activity in this window.
                    </.empty_state>
                    <.data_table :if={@clients != []} id="oracle-clients" rows={@clients}>
                      <:col :let={row} label="Assistant">{row.client}</:col>
                      <:col :let={row} label="Events" class="text-right">{row.events}</:col>
                      <:col :let={row} label="Oracle" class="text-right">{row.oracle}</:col>
                      <:col :let={row} label="Capsules" class="text-right">{row.capsules}</:col>
                      <:col :let={row} label="Grants" class="text-right">{row.grants}</:col>
                    </.data_table>
                  </.panel>

                  <.panel flush title="Most-Asked Traits">
                    <.empty_state :if={@top_traits == []} icon="hero-tag" title="No asks">
                      No ask_me reads in this window.
                    </.empty_state>
                    <.data_table :if={@top_traits != []} id="oracle-top-traits" rows={@top_traits}>
                      <:col :let={row} label="Trait">{row.trait}</:col>
                      <:col :let={row} label="Asks" class="text-right">{row.asks}</:col>
                      <:col :let={row} label="Grants" class="text-right">{row.grants}</:col>
                    </.data_table>
                  </.panel>
                </div>

                <.panel
                  flush
                  title="Suggestions by Trait"
                  description="Tags assistants proposed (explicitly or from an observed gap) and what owners did with them."
                >
                  <.empty_state :if={@suggestions == []} icon="hero-light-bulb" title="No suggestions">
                    No suggestions filed in this window.
                  </.empty_state>
                  <.data_table :if={@suggestions != []} id="oracle-suggestions" rows={@suggestions}>
                    <:col :let={row} label="Trait">{row.trait}</:col>
                    <:col :let={row} label="Filed" class="text-right">{row.filed}</:col>
                    <:col :let={row} label="Observed" class="text-right">{row.observed}</:col>
                    <:col :let={row} label="Accepted" class="text-right text-success">
                      {row.accepted}
                    </:col>
                    <:col :let={row} label="Dismissed" class="text-right">{row.dismissed}</:col>
                    <:col :let={row} label="Pending" class="text-right">{row.pending}</:col>
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

  defp subjects(1), do: "1 subject"
  defp subjects(n), do: "#{n} subjects"

  defp gap_hint(1, _hidden), do: "all subjects"
  defp gap_hint(min, hidden), do: "#{hidden} more below #{min} people"

  defp gap_filter_phrase(1), do: "raised"
  defp gap_filter_phrase(min), do: "raised by #{min}+ people"

  defp reason_label("no_match"), do: "no match"
  defp reason_label("weak_match"), do: "weak match"
  defp reason_label("unknown_trait"), do: "unknown trait"
  defp reason_label("not_askable"), do: "orphaned trait"
  defp reason_label(other), do: other

  defp seen(%{first_seen: same, last_seen: same}), do: format_day(same)

  defp seen(%{first_seen: first, last_seen: last}),
    do: "#{format_day(first)} – #{format_day(last)}"

  defp format_day(%Date{} = date), do: Calendar.strftime(date, "%b %-d")
  defp format_day(_), do: "-"

  defp max_total(daily), do: daily |> Enum.map(& &1.total) |> Enum.max(fn -> 0 end)

  defp bar_width(_value, max) when max <= 0, do: 0
  defp bar_width(value, max), do: max(round(value / max * 100), 2)

  defp segment_class(true),
    do: "btn btn-sm border-0 bg-primary/10 text-primary shadow-none hover:bg-primary/15"

  defp segment_class(false), do: "btn btn-sm btn-ghost border-0 text-base-content/70"
end
