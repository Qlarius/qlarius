defmodule QlariusWeb.Admin.MeFileInspectorLive do
  use QlariusWeb, :live_view
  import Ecto.Query

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
     |> assign_mefiles()}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    {:noreply,
     socket
     |> assign(:search_query, "")
     |> assign_mefiles()}
  end

  defp assign_mefiles(socket) do
    query = socket.assigns[:search_query] || ""

    mefiles =
      from(mf in MeFile,
        join: u in User,
        on: u.id == mf.user_id,
        join: lh in LedgerHeader,
        on: lh.me_file_id == mf.id,
        left_join: o in Offer,
        on: o.me_file_id == mf.id and o.is_current == true,
        where: ilike(u.alias, ^"%#{query}%"),
        group_by: [mf.id, u.alias, lh.balance],
        select: %{
          me_file_id: mf.id,
          alias: u.alias,
          wallet_balance: lh.balance,
          tag_count: fragment("COUNT(DISTINCT ?)", mf.id),
          offer_count: count(o.id, :distinct)
        },
        order_by: [desc: lh.balance],
        limit: 25
      )
      |> Repo.all()

    mefiles_with_tags =
      Enum.map(mefiles, fn mf ->
        tag_count =
          from(mft in Qlarius.YouData.MeFiles.MeFileTag,
            where: mft.me_file_id == ^mf.me_file_id,
            select: count(mft.id)
          )
          |> Repo.one()

        Map.put(mf, :tag_count, tag_count)
      end)

    assign(socket, :mefiles, mefiles_with_tags)
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

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin {assigns}>
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
                    <th>Alias</th>
                    <th class="text-right">Wallet Balance</th>
                    <th class="text-center">Tags</th>
                    <th class="text-center">Active Offers</th>
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
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end
end
