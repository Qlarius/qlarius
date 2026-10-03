defmodule QlariusWeb.Admin.MeCPAccessLogLive do
  @moduledoc """
  Admin view of the MeCP audit trail: every external read of MeFile data
  through the gateway, newest first. Shapes only, never values.
  """

  use QlariusWeb, :live_view
  import Ecto.Query
  import QlariusWeb.Components.MarketerUI

  alias QlariusWeb.Components.AdminSidebar
  alias QlariusWeb.Components.AdminTopbar
  alias Qlarius.MeCP.AccessLog
  alias Qlarius.MeCP.AccessLog.AccessEvent
  alias Qlarius.MeCP.Clients.Client
  alias Qlarius.MeCP.Grants.Grant
  alias Qlarius.Repo
  alias Qlarius.DateTime, as: QlariusDateTime

  @per_page 50

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "MeCP Access Log")
     |> assign(:kind_filter, nil)
     |> assign(:page, 1)
     |> assign(:per_page, @per_page)
     |> assign_metrics()
     |> assign_events()}
  end

  @impl true
  def handle_event("filter_kind", %{"kind" => kind}, socket) do
    kind = if kind == "all", do: nil, else: kind

    {:noreply,
     socket
     |> assign(:kind_filter, kind)
     |> assign(:page, 1)
     |> assign_events()}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    {:noreply,
     socket
     |> assign(:page, String.to_integer(page))
     |> assign_events()}
  end

  defp assign_events(socket) do
    kind = socket.assigns.kind_filter
    page = socket.assigns.page

    events = AccessLog.list_events(kind: kind, page: page, per_page: @per_page)
    total_count = AccessLog.count_events(kind)

    socket
    |> assign(:events, events)
    |> assign(:total_count, total_count)
    |> assign(:total_pages, max(ceil(total_count / @per_page), 1))
  end

  defp assign_metrics(socket) do
    now = DateTime.utc_now()

    active_grants =
      Repo.one(
        from g in Grant,
          where: is_nil(g.revoked_at) and (is_nil(g.expires_at) or g.expires_at > ^now),
          select: count(g.id)
      )

    socket
    |> assign(:counts_by_kind, AccessLog.counts_by_kind())
    |> assign(:active_grants, active_grants)
    |> assign(:client_count, Repo.one(from c in Client, select: count(c.id)))
    |> assign(
      :events_7d,
      Repo.one(from e in AccessEvent, where: e.occurred_at > ago(7, "day"), select: count(e.id))
    )
  end

  defp kind_tone("capsule"), do: "info"
  defp kind_tone("oracle"), do: "success"
  defp kind_tone("rerank"), do: "warning"
  defp kind_tone(_), do: "neutral"

  defp format_date(datetime, assigns) do
    user = assigns.current_scope.user
    QlariusDateTime.format_for_user(datetime, user, :standard)
  end

  defp truncate_digest(nil), do: "-"
  defp truncate_digest(digest), do: String.slice(digest, 0, 12)

  # The MeFile actually served: recorded per event since proxy resolution
  # landed; older events fall back to the grant's approval-time snapshot.
  defp served_me_file_id(event) do
    event.response_shape["me_file_id"] || event.mecp_grant.me_file_id
  end

  defp owner_label(%{mecp_grant: %{user: %{alias: alias_}}}) when is_binary(alias_), do: alias_
  defp owner_label(%{mecp_grant: %{user_id: user_id}}) when not is_nil(user_id), do: "##{user_id}"
  defp owner_label(_event), do: "-"

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
                title="MeCP Access Log"
                count={@total_count}
                subtitle="Every external read of MeFile data through the gateway, newest first. Shapes only, never values."
              />

              <div class="mb-6 grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
                <.stat_tile label="Capsule reads" icon="hero-document-text">
                  {Map.get(@counts_by_kind, "capsule", 0)}
                </.stat_tile>
                <.stat_tile label="Oracle answers" icon="hero-question-mark-circle">
                  {Map.get(@counts_by_kind, "oracle", 0)}
                </.stat_tile>
                <.stat_tile label="Active grants" icon="hero-key">{@active_grants}</.stat_tile>
                <.stat_tile label="Clients" icon="hero-cpu-chip">{@client_count}</.stat_tile>
                <.stat_tile label="Last 7 days" icon="hero-clock">{@events_7d}</.stat_tile>
              </div>

              <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
                <div class="inline-flex flex-wrap rounded-lg border border-base-300 bg-base-100 p-0.5">
                  <button
                    :for={kind <- ["all", "capsule", "oracle", "rerank", "handshake"]}
                    type="button"
                    phx-click="filter_kind"
                    phx-value-kind={kind}
                    aria-pressed={to_string(kind_selected?(kind, @kind_filter))}
                    class={segment_class(kind_selected?(kind, @kind_filter))}
                  >
                    {kind}
                  </button>
                </div>
                <p :if={@total_count > 0} class="text-sm text-base-content/60">
                  Showing {(@page - 1) * @per_page + 1}-{min(@page * @per_page, @total_count)} of {@total_count}
                </p>
              </div>

              <.panel flush>
                <.empty_state :if={@events == []} icon="hero-shield-check" title="No access events">
                  Every external read of MeFile data will appear here.
                </.empty_state>

                <.data_table :if={@events != []} id="mecp-access-events" rows={@events}>
                  <:col :let={event} label="Occurred" class="whitespace-nowrap">
                    {format_date(event.occurred_at, assigns)}
                  </:col>
                  <:col :let={event} label="Kind">
                    <.status_badge tone={kind_tone(event.kind)}>{event.kind}</.status_badge>
                  </:col>
                  <:col :let={event} label="Client">
                    <span class="font-medium">{event.mecp_grant.mecp_client.name}</span>
                  </:col>
                  <:col :let={event} label="User">{owner_label(event)}</:col>
                  <:col :let={event} label="MeFile served" class="text-center">
                    <.link
                      navigate={~p"/admin/mefile_inspector/#{served_me_file_id(event)}"}
                      class="link link-hover"
                    >
                      {served_me_file_id(event)}
                    </.link>
                  </:col>
                  <:col :let={event} label="Grant" class="text-center">
                    <span class="text-base-content/60">#{event.mecp_grant_id}</span>
                  </:col>
                  <:col :let={event} label="Tier" class="text-center">
                    <.chip>{event.mecp_grant.tier}</.chip>
                  </:col>
                  <:col :let={event} label="Request digest">
                    <span class="font-mono text-xs" title={event.request_digest}>
                      {truncate_digest(event.request_digest)}
                    </span>
                  </:col>
                  <:col :let={event} label="Response shape">
                    <span class="font-mono text-xs text-base-content/70">
                      {Jason.encode!(event.response_shape)}
                    </span>
                  </:col>
                </.data_table>

                <:footer :if={@total_pages > 1}>
                  <div class="join">
                    <button
                      type="button"
                      phx-click="paginate"
                      phx-value-page={@page - 1}
                      class="join-item btn btn-sm"
                      disabled={@page == 1}
                      aria-label="Previous page"
                    >
                      <.icon name="hero-chevron-left" class="size-4" />
                    </button>
                    <span class="join-item btn btn-sm btn-disabled">
                      {@page} / {@total_pages}
                    </span>
                    <button
                      type="button"
                      phx-click="paginate"
                      phx-value-page={@page + 1}
                      class="join-item btn btn-sm"
                      disabled={@page == @total_pages}
                      aria-label="Next page"
                    >
                      <.icon name="hero-chevron-right" class="size-4" />
                    </button>
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

  defp kind_selected?("all", kind_filter), do: is_nil(kind_filter)
  defp kind_selected?(kind, kind_filter), do: kind == kind_filter

  defp segment_class(true),
    do: "btn btn-sm border-0 bg-primary/10 text-primary shadow-none hover:bg-primary/15"

  defp segment_class(false), do: "btn btn-sm btn-ghost border-0 text-base-content/70"
end
