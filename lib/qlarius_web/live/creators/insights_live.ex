defmodule QlariusWeb.Creators.InsightsLive do
  use QlariusWeb, :live_view

  import QlariusWeb.Components.MarketerUI

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
        <AdminSidebar.sidebar current_user={@current_scope.user} current_path={@current_path} />
        <div class="flex min-w-0 grow flex-col">
          <AdminTopbar.topbar current_user={@current_scope.user} />
          <div class="overflow-auto flex-1">
            <.page>
              <.page_header
                title="Insights"
                subtitle="Totals only. No visitor-level detail."
                back_to={~p"/creators/#{@creator.id}"}
                back_label={@creator.name}
              >
                <:actions>
                  <.link
                    navigate={~p"/creators/#{@creator.id}/audiences"}
                    class="btn btn-sm btn-ghost"
                  >
                    Audiences
                  </.link>
                  <.link
                    navigate={~p"/creators/#{@creator.id}/trait-groups"}
                    class="btn btn-sm btn-ghost"
                  >
                    Trait groups
                  </.link>
                </:actions>
              </.page_header>

              <div class="space-y-8">
                <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
                  <.stat_tile label="Impressions" icon="hero-eye">
                    {@funnel.impressions}
                  </.stat_tile>
                  <.stat_tile label="Clicks" icon="hero-cursor-arrow-rays">
                    {@funnel.clicks}
                  </.stat_tile>
                  <.stat_tile label="Purchases" icon="hero-shopping-bag">
                    {@funnel.purchases}
                  </.stat_tile>
                  <.stat_tile label="Revenue" icon="hero-banknotes">
                    {Money.format_usd(@funnel.revenue)}
                  </.stat_tile>
                </div>

                <.panel
                  title="Recommended vs organic"
                  description="Split on whether the action had a matched audience band."
                >
                  <div class="grid grid-cols-2 gap-4">
                    <.stat_tile label="Recommended" icon="hero-sparkles">
                      {@split.recommended}
                    </.stat_tile>
                    <.stat_tile label="Organic" icon="hero-globe-alt">
                      {@split.organic}
                    </.stat_tile>
                  </div>
                </.panel>

                <.panel title="Per-audience conversion" flush>
                  <.empty_state
                    :if={@audiences == []}
                    icon="hero-user-group"
                    title="No audiences yet"
                  >
                    Create one to see how each converts.
                  </.empty_state>
                  <.data_table :if={@audiences != []} id="audience-conversion" rows={@audiences}>
                    <:col :let={row} label="Audience">
                      <.link
                        navigate={~p"/creators/#{@creator.id}/audiences/#{row.target_id}/edit"}
                        class="font-medium hover:underline"
                      >
                        {row.title}
                      </.link>
                    </:col>
                    <:col :let={row} label="Reach">{row.reach}</:col>
                    <:col :let={row} label="Clicks">{row.clicks}</:col>
                    <:col :let={row} label="Purchases">{row.purchases}</:col>
                    <:col :let={row} label="Conversion">{conversion_label(row.conversion)}</:col>
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

  defp conversion_label(%Decimal{} = rate) do
    rate
    |> Decimal.mult(100)
    |> Decimal.round(1)
    |> Decimal.to_string(:normal)
    |> then(&"#{&1}%")
  end

  defp conversion_label(_), do: "0%"
end
