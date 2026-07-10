defmodule QlariusWeb.Admin.MeCPAccessLogLive do
  @moduledoc """
  Admin view of the MeCP audit trail: every external read of MeFile data
  through the gateway, newest first. Shapes only, never values.
  """

  use QlariusWeb, :live_view
  import Ecto.Query

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

  defp kind_badge_class("capsule"), do: "badge-primary"
  defp kind_badge_class("oracle"), do: "badge-info"
  defp kind_badge_class("rerank"), do: "badge-warning"
  defp kind_badge_class(_), do: "badge-ghost"

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
        <AdminSidebar.sidebar current_user={@current_scope.user} />

        <div class="flex min-w-0 grow flex-col">
          <AdminTopbar.topbar current_user={@current_scope.user} />

          <div class="overflow-auto">
            <div class="p-6">
              <div class="flex justify-between items-center mb-6">
                <h1 class="text-2xl font-bold">MeCP Access Log</h1>
              </div>

              <div class="stats stats-vertical lg:stats-horizontal shadow-sm bg-base-200 w-full border border-base-300 mb-6">
                <div class="stat">
                  <div class="stat-figure text-primary">
                    <.icon name="hero-document-text" class="w-8 h-8" />
                  </div>
                  <div class="stat-title text-xs opacity-60">Capsule Reads</div>
                  <div class="stat-value text-xl text-primary">
                    {Map.get(@counts_by_kind, "capsule", 0)}
                  </div>
                </div>

                <div class="stat">
                  <div class="stat-figure text-info">
                    <.icon name="hero-question-mark-circle" class="w-8 h-8" />
                  </div>
                  <div class="stat-title text-xs opacity-60">Oracle Answers</div>
                  <div class="stat-value text-xl text-info">
                    {Map.get(@counts_by_kind, "oracle", 0)}
                  </div>
                </div>

                <div class="stat">
                  <div class="stat-figure text-success">
                    <.icon name="hero-key" class="w-8 h-8" />
                  </div>
                  <div class="stat-title text-xs opacity-60">Active Grants</div>
                  <div class="stat-value text-xl text-success">{@active_grants}</div>
                </div>

                <div class="stat">
                  <div class="stat-figure text-warning">
                    <.icon name="hero-cpu-chip" class="w-8 h-8" />
                  </div>
                  <div class="stat-title text-xs opacity-60">Clients</div>
                  <div class="stat-value text-xl text-warning">{@client_count}</div>
                </div>

                <div class="stat">
                  <div class="stat-figure text-secondary">
                    <.icon name="hero-clock" class="w-8 h-8" />
                  </div>
                  <div class="stat-title text-xs opacity-60">Last 7 Days</div>
                  <div class="stat-value text-xl text-secondary">{@events_7d}</div>
                </div>
              </div>

              <div class="card bg-base-100 border border-base-300">
                <div class="card-body">
                  <div class="flex justify-between items-center mb-4">
                    <h2 class="card-title">Access Events</h2>
                    <div class="join">
                      <button
                        :for={kind <- ["all", "capsule", "oracle", "rerank", "handshake"]}
                        phx-click="filter_kind"
                        phx-value-kind={kind}
                        class={"join-item btn btn-sm #{if @kind_filter == kind or (kind == "all" and is_nil(@kind_filter)), do: "btn-active"}"}
                      >
                        {kind}
                      </button>
                    </div>
                  </div>

                  <div class="overflow-x-auto">
                    <table class="table table-zebra">
                      <thead>
                        <tr>
                          <th>Occurred</th>
                          <th>Kind</th>
                          <th>Client</th>
                          <th>User</th>
                          <th class="text-center">MeFile Served</th>
                          <th class="text-center">Grant</th>
                          <th class="text-center">Tier</th>
                          <th>Request Digest</th>
                          <th>Response Shape</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr :for={event <- @events}>
                          <td class="whitespace-nowrap">{format_date(event.occurred_at, assigns)}</td>
                          <td>
                            <span class={"badge #{kind_badge_class(event.kind)}"}>{event.kind}</span>
                          </td>
                          <td class="font-medium">{event.mecp_grant.mecp_client.name}</td>
                          <td class="text-sm">{owner_label(event)}</td>
                          <td class="text-center">
                            <.link
                              navigate={~p"/admin/mefile_inspector/#{served_me_file_id(event)}"}
                              class="link link-hover"
                            >
                              {served_me_file_id(event)}
                            </.link>
                          </td>
                          <td class="text-center">{event.mecp_grant_id}</td>
                          <td class="text-center">
                            <span class="badge badge-ghost">{event.mecp_grant.tier}</span>
                          </td>
                          <td class="font-mono text-xs" title={event.request_digest}>
                            {truncate_digest(event.request_digest)}
                          </td>
                          <td class="font-mono text-xs">
                            {Jason.encode!(event.response_shape)}
                          </td>
                        </tr>
                      </tbody>
                    </table>

                    <div :if={@events == []} class="text-center py-12">
                      <.icon
                        name="hero-shield-check"
                        class="w-16 h-16 mx-auto text-base-content/30 mb-4"
                      />
                      <p class="text-lg font-medium text-base-content/70">No access events</p>
                      <p class="text-sm text-base-content/50 mt-2">
                        Every external read of MeFile data will appear here
                      </p>
                    </div>
                  </div>

                  <div :if={@total_pages > 1} class="flex justify-between items-center mt-4">
                    <div class="text-sm text-base-content/60">
                      Showing {(@page - 1) * @per_page + 1}-{min(@page * @per_page, @total_count)} of {@total_count}
                    </div>

                    <div class="join">
                      <button
                        phx-click="paginate"
                        phx-value-page={@page - 1}
                        class="join-item btn btn-sm"
                        disabled={@page == 1}
                      >
                        ‹
                      </button>
                      <button class="join-item btn btn-sm btn-disabled">
                        {@page} / {@total_pages}
                      </button>
                      <button
                        phx-click="paginate"
                        phx-value-page={@page + 1}
                        class="join-item btn btn-sm"
                        disabled={@page == @total_pages}
                      >
                        ›
                      </button>
                    </div>
                  </div>
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
