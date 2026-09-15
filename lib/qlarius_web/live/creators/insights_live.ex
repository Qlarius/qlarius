defmodule QlariusWeb.Creators.InsightsLive do
  use QlariusWeb, :live_view

  alias Qlarius.Creators
  alias Qlarius.Tiqit.ContentEngagement
  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}
  alias QlariusWeb.Money

  @impl true
  def mount(%{"creator_id" => creator_id}, _session, socket) do
    creator = Creators.accessible_creator!(socket.assigns.current_scope, creator_id)
    report = ContentEngagement.report_for_creator(creator.id)

    {:ok,
     socket
     |> assign(:creator, creator)
     |> assign(:page_title, "Insights")
     |> assign(:funnel, report.funnel)
     |> assign(:split, report.split)
     |> assign(:audiences, report.audiences)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin {assigns}>
      <div class="flex h-screen">
        <AdminSidebar.sidebar current_user={@current_scope.user} />
        <div class="flex min-w-0 grow flex-col">
          <AdminTopbar.topbar current_user={@current_scope.user} />
          <div class="overflow-auto p-6 space-y-6">
            <div class="flex items-center justify-between gap-4">
              <div>
                <h1 class="text-2xl font-bold">Insights</h1>
                <p class="text-base-content/60">{@creator.name}</p>
              </div>
              <div class="flex gap-2">
                <.link navigate={~p"/creators/#{@creator.id}/audiences"} class="btn btn-ghost">
                  Audiences
                </.link>
                <.link navigate={~p"/creators/#{@creator.id}"} class="btn btn-ghost">
                  Back
                </.link>
              </div>
            </div>

            <p class="text-sm text-base-content/60">
              Totals only — no visitor-level detail.
            </p>

            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
              <.stat title="Impressions" value={@funnel.impressions} />
              <.stat title="Clicks" value={@funnel.clicks} />
              <.stat title="Purchases" value={@funnel.purchases} />
              <.stat title="Revenue" value={Money.format_usd(@funnel.revenue)} />
            </div>

            <div class="card bg-base-100 shadow">
              <div class="card-body">
                <h2 class="card-title text-lg">Recommended vs organic</h2>
                <p class="text-sm text-base-content/60">
                  Split on whether the action had a matched audience band.
                </p>
                <div class="grid grid-cols-2 gap-4 mt-2">
                  <.stat title="Recommended" value={@split.recommended} />
                  <.stat title="Organic" value={@split.organic} />
                </div>
              </div>
            </div>

            <div class="card bg-base-100 shadow">
              <div class="card-body">
                <h2 class="card-title text-lg">Per-audience conversion</h2>
                <p :if={@audiences == []} class="text-sm text-base-content/60">
                  No audiences yet. Create one to see how each converts.
                </p>
                <div :if={@audiences != []} class="overflow-x-auto">
                  <table class="table">
                    <thead>
                      <tr>
                        <th>Audience</th>
                        <th>Reach</th>
                        <th>Clicks</th>
                        <th>Purchases</th>
                        <th>Conversion</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr :for={row <- @audiences}>
                        <td>
                          <.link
                            navigate={~p"/creators/#{@creator.id}/audiences/#{row.target_id}"}
                            class="link"
                          >
                            {row.title}
                          </.link>
                        </td>
                        <td>{row.reach}</td>
                        <td>{row.clicks}</td>
                        <td>{row.purchases}</td>
                        <td>{conversion_label(row.conversion)}</td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  defp stat(assigns) do
    ~H"""
    <div class="stats shadow bg-base-100">
      <div class="stat">
        <div class="stat-title">{@title}</div>
        <div class="stat-value text-xl">{@value}</div>
      </div>
    </div>
    """
  end

  defp conversion_label(%Decimal{} = rate) do
    rate
    |> Decimal.mult(100)
    |> Decimal.round(1)
    |> Decimal.to_string(:normal)
    |> then(&"#{&1}%")
  end

  defp conversion_label(_), do: "0%"
end
