defmodule QlariusWeb.Admin.MeFileInspectorLive do
  use QlariusWeb, :live_view
  import Ecto.Query

  alias QlariusWeb.Components.AdminSidebar
  alias QlariusWeb.Components.AdminTopbar
  alias Qlarius.Repo
  alias Qlarius.Accounts.User
  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.Wallets.LedgerHeader
  alias Qlarius.Sponster.Offer

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "MeFile Inspector")
     |> assign(:search_query, "")
     |> assign(:page, 1)
     |> assign(:sort_by, :inserted_at)
     |> assign(:sort_dir, :desc)
     |> assign_mefiles()
     |> assign_metrics()}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"search" => query}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:page, 1)
     |> assign_mefiles()}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    {:noreply,
     socket
     |> assign(:search_query, "")
     |> assign(:page, 1)
     |> assign_mefiles()}
  end

  @impl true
  def handle_event("sort", %{"column" => column}, socket) do
    column_atom = String.to_existing_atom(column)
    current_sort_by = socket.assigns.sort_by
    current_sort_dir = socket.assigns.sort_dir

    sort_dir =
      if current_sort_by == column_atom do
        if current_sort_dir == :asc, do: :desc, else: :asc
      else
        :desc
      end

    {:noreply,
     socket
     |> assign(:sort_by, column_atom)
     |> assign(:sort_dir, sort_dir)
     |> assign(:page, 1)
     |> assign_mefiles()}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    {:noreply,
     socket
     |> assign(:page, String.to_integer(page))
     |> assign_mefiles()}
  end

  defp assign_mefiles(socket) do
    query = socket.assigns[:search_query] || ""
    page = socket.assigns[:page] || 1
    sort_by = socket.assigns[:sort_by] || :inserted_at
    sort_dir = socket.assigns[:sort_dir] || :desc
    per_page = 50

    offset = (page - 1) * per_page

    base_query =
      from(mf in MeFile,
        join: u in User,
        on: u.id == mf.user_id,
        join: lh in LedgerHeader,
        on: lh.me_file_id == mf.id,
        left_join: o in Offer,
        on: o.me_file_id == mf.id and o.is_current == true,
        left_join: mft in Qlarius.YouData.MeFiles.MeFileTag,
        on: mft.me_file_id == mf.id,
        where: ilike(u.alias, ^"%#{query}%"),
        group_by: [mf.id, u.alias, u.inserted_at, lh.balance]
      )

    total_count =
      from(mf in MeFile,
        join: u in User,
        on: u.id == mf.user_id,
        where: ilike(u.alias, ^"%#{query}%"),
        select: count(mf.id, :distinct)
      )
      |> Repo.one()

    base_query =
      case {sort_by, sort_dir} do
        {:alias, :asc} ->
          from q in base_query, order_by: [asc: q.alias]

        {:alias, :desc} ->
          from q in base_query, order_by: [desc: q.alias]

        {:wallet_balance, :asc} ->
          from [mf, u, lh, o, mft] in base_query, order_by: [asc: lh.balance]

        {:wallet_balance, :desc} ->
          from [mf, u, lh, o, mft] in base_query, order_by: [desc: lh.balance]

        {:tag_count, :asc} ->
          from [mf, u, lh, o, mft] in base_query,
            order_by: [asc: count(mft.id, :distinct)]

        {:tag_count, :desc} ->
          from [mf, u, lh, o, mft] in base_query,
            order_by: [desc: count(mft.id, :distinct)]

        {:offer_count, :asc} ->
          from [mf, u, lh, o, mft] in base_query, order_by: [asc: count(o.id, :distinct)]

        {:offer_count, :desc} ->
          from [mf, u, lh, o, mft] in base_query, order_by: [desc: count(o.id, :distinct)]

        {:inserted_at, :asc} ->
          from [mf, u, lh, o, mft] in base_query, order_by: [asc: u.inserted_at]

        {:inserted_at, :desc} ->
          from [mf, u, lh, o, mft] in base_query, order_by: [desc: u.inserted_at]

        _ ->
          from [mf, u, lh, o, mft] in base_query, order_by: [desc: u.inserted_at]
      end

    mefiles =
      from([mf, u, lh, o, mft] in base_query,
        select: %{
          me_file_id: mf.id,
          alias: u.alias,
          wallet_balance: lh.balance,
          inserted_at: u.inserted_at,
          tag_count: count(mft.id, :distinct),
          offer_count: count(o.id, :distinct)
        },
        offset: ^offset,
        limit: ^per_page
      )
      |> Repo.all()

    total_pages = ceil(total_count / per_page)

    socket
    |> assign(:mefiles, mefiles)
    |> assign(:total_count, total_count)
    |> assign(:total_pages, total_pages)
  end

  defp assign_metrics(socket) do
    total_users =
      from(u in User, where: u.role == "user", select: count(u.id))
      |> Repo.one()

    users_with_rich_mefiles =
      from(mf in MeFile,
        join: mft in Qlarius.YouData.MeFiles.MeFileTag,
        on: mft.me_file_id == mf.id,
        group_by: mf.id,
        having: count(mft.id) > 4,
        select: mf.id
      )
      |> Repo.all()
      |> length()

    avg_tags_per_user =
      from(mf in MeFile,
        join: mft in Qlarius.YouData.MeFiles.MeFileTag,
        on: mft.me_file_id == mf.id,
        select: fragment("CAST(COUNT(*) AS FLOAT) / CAST(COUNT(DISTINCT ?) AS FLOAT)", mf.id)
      )
      |> Repo.one()
      |> case do
        nil -> 0.0
        val -> Float.round(val, 1)
      end

    users_with_active_offers =
      from(o in Offer,
        where: o.is_current == true,
        select: count(o.me_file_id, :distinct)
      )
      |> Repo.one()

    avg_wallet_balance =
      from(lh in LedgerHeader,
        where: not is_nil(lh.me_file_id),
        select: avg(lh.balance)
      )
      |> Repo.one()
      |> case do
        nil -> Decimal.new("0.00")
        val -> Decimal.round(val, 2)
      end

    users_with_zero_balance =
      from(lh in LedgerHeader,
        where: not is_nil(lh.me_file_id) and lh.balance == 0,
        select: count(lh.id)
      )
      |> Repo.one()

    users_with_positive_balance =
      from(lh in LedgerHeader,
        where: not is_nil(lh.me_file_id) and lh.balance > 0,
        select: count(lh.id)
      )
      |> Repo.one()

    recent_registrations =
      from(u in User,
        where: u.role == "user" and u.inserted_at > ago(7, "day"),
        select: count(u.id)
      )
      |> Repo.one()

    socket
    |> assign(:total_users, total_users)
    |> assign(:users_with_rich_mefiles, users_with_rich_mefiles)
    |> assign(:avg_tags_per_user, avg_tags_per_user)
    |> assign(:users_with_active_offers, users_with_active_offers)
    |> assign(:avg_wallet_balance, avg_wallet_balance)
    |> assign(:users_with_zero_balance, users_with_zero_balance)
    |> assign(:users_with_positive_balance, users_with_positive_balance)
    |> assign(:recent_registrations, recent_registrations)
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %-d, %Y")
  end

  defp pagination_range(current_page, total_pages) do
    cond do
      total_pages <= 7 ->
        Enum.to_list(1..total_pages)

      current_page <= 4 ->
        Enum.to_list(1..5) ++ [:ellipsis, total_pages]

      current_page >= total_pages - 3 ->
        [1, :ellipsis] ++ Enum.to_list((total_pages - 4)..total_pages)

      true ->
        [1, :ellipsis] ++
          Enum.to_list((current_page - 1)..(current_page + 1)) ++ [:ellipsis, total_pages]
    end
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
              <div class="flex justify-between items-center mb-6">
                <h1 class="text-2xl font-bold">MeFile Inspector</h1>
              </div>

              <div class="stats stats-vertical lg:stats-horizontal shadow-sm bg-base-200 w-full border border-base-300 mb-6">
                <div class="stat">
                  <div class="stat-figure text-primary">
                    <.icon name="hero-user-group" class="w-8 h-8" />
                  </div>
                  <div class="stat-title text-xs opacity-60">Total Users</div>
                  <div class="stat-value text-xl text-primary">{@total_users}</div>
                  <div class="stat-desc">All registered users</div>
                </div>

                <div class="stat">
                  <div class="stat-figure text-success">
                    <.icon name="hero-star" class="w-8 h-8" />
                  </div>
                  <div class="stat-title text-xs opacity-60">Rich MeFiles</div>
                  <div class="stat-value text-xl text-success">{@users_with_rich_mefiles}</div>
                  <div class="stat-desc">&gt;4 tags</div>
                </div>

                <div class="stat">
                  <div class="stat-figure text-info">
                    <.icon name="hero-tag" class="w-8 h-8" />
                  </div>
                  <div class="stat-title text-xs opacity-60">Avg Tags/User</div>
                  <div class="stat-value text-xl text-info">{@avg_tags_per_user}</div>
                  <div class="stat-desc">Per user average</div>
                </div>

                <div class="stat">
                  <div class="stat-figure text-warning">
                    <.icon name="hero-megaphone" class="w-8 h-8" />
                  </div>
                  <div class="stat-title text-xs opacity-60">Active Offers</div>
                  <div class="stat-value text-xl text-warning">{@users_with_active_offers}</div>
                  <div class="stat-desc">Users with offers</div>
                </div>

                <div class="stat">
                  <div class="stat-figure text-success">
                    <.icon name="hero-currency-dollar" class="w-8 h-8" />
                  </div>
                  <div class="stat-title text-xs opacity-60">Avg Balance</div>
                  <div class="stat-value text-xl text-success">
                    {QlariusWeb.Money.format_usd(@avg_wallet_balance)}
                  </div>
                  <div class="stat-desc">
                    ${@users_with_positive_balance} &gt; $0 | ${@users_with_zero_balance} = $0
                  </div>
                </div>

                <div class="stat">
                  <div class="stat-figure text-secondary">
                    <.icon name="hero-user-plus" class="w-8 h-8" />
                  </div>
                  <div class="stat-title text-xs opacity-60">Recent</div>
                  <div class="stat-value text-xl text-secondary">{@recent_registrations}</div>
                  <div class="stat-desc">Last 7 days</div>
                </div>
              </div>

              <div class="card bg-base-100 border border-base-300">
                <div class="card-body">
                  <div class="flex justify-between items-center mb-4">
                    <h2 class="card-title">Top 25 MeFiles by Wallet Balance</h2>
                    <.form for={%{}} phx-submit="search" class="flex gap-2">
                      <input
                        type="text"
                        name="search"
                        value={@search_query}
                        placeholder="Search by alias..."
                        class="input input-bordered input-sm"
                      />
                      <button type="submit" class="btn btn-sm btn-primary">
                        <.icon name="hero-magnifying-glass" class="w-4 h-4" />
                      </button>
                      <button
                        :if={@search_query != ""}
                        type="button"
                        phx-click="clear_search"
                        class="btn btn-sm btn-ghost"
                      >
                        Clear
                      </button>
                    </.form>
                  </div>

                  <div class="overflow-x-auto">
                    <table class="table table-zebra">
                      <thead>
                        <tr>
                          <th>
                            <button
                              phx-click="sort"
                              phx-value-column="alias"
                              class="flex items-center gap-1 hover:text-primary"
                            >
                              Alias
                              <%= if @sort_by == :alias do %>
                                <.icon
                                  name={
                                    if @sort_dir == :asc,
                                      do: "hero-arrow-up",
                                      else: "hero-arrow-down"
                                  }
                                  class="w-4 h-4"
                                />
                              <% end %>
                            </button>
                          </th>
                          <th class="text-right">
                            <button
                              phx-click="sort"
                              phx-value-column="wallet_balance"
                              class="flex items-center gap-1 hover:text-primary ml-auto"
                            >
                              Wallet Balance
                              <%= if @sort_by == :wallet_balance do %>
                                <.icon
                                  name={
                                    if @sort_dir == :asc,
                                      do: "hero-arrow-up",
                                      else: "hero-arrow-down"
                                  }
                                  class="w-4 h-4"
                                />
                              <% end %>
                            </button>
                          </th>
                          <th class="text-center">
                            <button
                              phx-click="sort"
                              phx-value-column="tag_count"
                              class="flex items-center gap-1 hover:text-primary mx-auto"
                            >
                              Tags
                              <%= if @sort_by == :tag_count do %>
                                <.icon
                                  name={
                                    if @sort_dir == :asc,
                                      do: "hero-arrow-up",
                                      else: "hero-arrow-down"
                                  }
                                  class="w-4 h-4"
                                />
                              <% end %>
                            </button>
                          </th>
                          <th class="text-center">
                            <button
                              phx-click="sort"
                              phx-value-column="offer_count"
                              class="flex items-center gap-1 hover:text-primary mx-auto"
                            >
                              Active Offers
                              <%= if @sort_by == :offer_count do %>
                                <.icon
                                  name={
                                    if @sort_dir == :asc,
                                      do: "hero-arrow-up",
                                      else: "hero-arrow-down"
                                  }
                                  class="w-4 h-4"
                                />
                              <% end %>
                            </button>
                          </th>
                          <th class="text-center">
                            <button
                              phx-click="sort"
                              phx-value-column="inserted_at"
                              class="flex items-center gap-1 hover:text-primary mx-auto"
                            >
                              Created
                              <%= if @sort_by == :inserted_at do %>
                                <.icon
                                  name={
                                    if @sort_dir == :asc,
                                      do: "hero-arrow-up",
                                      else: "hero-arrow-down"
                                  }
                                  class="w-4 h-4"
                                />
                              <% end %>
                            </button>
                          </th>
                          <th></th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr :for={mf <- @mefiles}>
                          <td class="font-medium">{mf.alias}</td>
                          <td class="text-right font-mono">
                            {QlariusWeb.Money.format_usd(mf.wallet_balance)}
                          </td>
                          <td class="text-center">
                            <span class="badge badge-ghost">{mf.tag_count}</span>
                          </td>
                          <td class="text-center">
                            <span class="badge badge-warning">{mf.offer_count}</span>
                          </td>
                          <td class="text-center">
                            {format_date(mf.inserted_at)}
                          </td>
                          <td class="text-right">
                            <.link
                              navigate={~p"/admin/mefile_inspector/#{mf.me_file_id}"}
                              class="btn btn-sm btn-ghost"
                            >
                              View <.icon name="hero-arrow-right" class="w-4 h-4" />
                            </.link>
                          </td>
                        </tr>
                      </tbody>
                    </table>

                    <div :if={@mefiles == []} class="text-center py-12">
                      <.icon
                        name="hero-magnifying-glass"
                        class="w-16 h-16 mx-auto text-base-content/30 mb-4"
                      />
                      <p class="text-lg font-medium text-base-content/70">No MeFiles found</p>
                      <p :if={@search_query != ""} class="text-sm text-base-content/50 mt-2">
                        Try a different search term
                      </p>
                    </div>
                  </div>

                  <div :if={@total_pages > 1} class="flex justify-between items-center mt-4">
                    <div class="text-sm text-base-content/60">
                      Showing {(@page - 1) * 50 + 1}-{min(@page * 50, @total_count)} of {@total_count}
                    </div>

                    <div class="join">
                      <button
                        phx-click="paginate"
                        phx-value-page="1"
                        class="join-item btn btn-sm"
                        disabled={@page == 1}
                      >
                        «
                      </button>
                      <button
                        phx-click="paginate"
                        phx-value-page={@page - 1}
                        class="join-item btn btn-sm"
                        disabled={@page == 1}
                      >
                        ‹
                      </button>

                      <%= for page_num <- pagination_range(@page, @total_pages) do %>
                        <%= if page_num == :ellipsis do %>
                          <button class="join-item btn btn-sm btn-disabled">...</button>
                        <% else %>
                          <button
                            phx-click="paginate"
                            phx-value-page={page_num}
                            class={"join-item btn btn-sm #{if page_num == @page, do: "btn-active"}"}
                          >
                            {page_num}
                          </button>
                        <% end %>
                      <% end %>

                      <button
                        phx-click="paginate"
                        phx-value-page={@page + 1}
                        class="join-item btn btn-sm"
                        disabled={@page == @total_pages}
                      >
                        ›
                      </button>
                      <button
                        phx-click="paginate"
                        phx-value-page={@total_pages}
                        class="join-item btn btn-sm"
                        disabled={@page == @total_pages}
                      >
                        »
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
