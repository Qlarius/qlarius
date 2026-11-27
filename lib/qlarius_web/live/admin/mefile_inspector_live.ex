defmodule QlariusWeb.Admin.MeFileInspectorLive do
  use QlariusWeb, :live_view
  import Ecto.Query
  import QlariusWeb.Components.MarketerUI

  alias QlariusWeb.Components.AdminSidebar
  alias QlariusWeb.Components.AdminTopbar
  alias Qlarius.Repo
  alias Qlarius.Accounts.User
  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.YouData.MeFiles.MeFileTag
  alias Qlarius.YouData.Traits.Trait
  alias Qlarius.Wallets.LedgerHeader
  alias Qlarius.Sponster.Offer
  alias Qlarius.DateTime, as: QlariusDateTime

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

  defmacrop trait_count_fragment(trait) do
    quote do
      fragment(
        "CASE WHEN COUNT(DISTINCT ?) > 0 THEN COUNT(DISTINCT ?) + 1 ELSE 0 END",
        unquote(trait).parent_trait_id,
        unquote(trait).parent_trait_id
      )
    end
  end

  # Tag totals and offer totals are separate statements. Joining the raw
  # tables together multiplies every tag by every current offer before the
  # GROUP BY, and that one statement held a pool checkout past 15 seconds.
  defp assign_mefiles(socket) do
    query = socket.assigns[:search_query] || ""
    page = socket.assigns[:page] || 1
    sort_by = socket.assigns[:sort_by] || :inserted_at
    sort_dir = socket.assigns[:sort_dir] || :desc
    per_page = 50
    offset = (page - 1) * per_page

    total_count =
      from(mf in MeFile,
        join: u in User,
        on: u.id == mf.user_id,
        where: ilike(u.alias, ^"%#{query}%"),
        select: count(mf.id, :distinct)
      )
      |> Repo.one()

    rows =
      page_query(query, sort_by, sort_dir, offset, per_page)
      |> Repo.all()

    ids = rows |> Enum.map(& &1.me_file_id) |> Enum.uniq()
    tag_counts = tag_counts_for(ids)
    offer_counts = offer_counts_for(ids)

    mefiles =
      Enum.map(rows, fn row ->
        row
        |> Map.put(:tag_count, Map.get(tag_counts, row.me_file_id, 0))
        |> Map.put(:offer_count, Map.get(offer_counts, row.me_file_id, 0))
      end)

    socket
    |> assign(:mefiles, mefiles)
    |> assign(:total_count, total_count)
    |> assign(:total_pages, ceil(total_count / per_page))
  end

  defp page_query(search, sort_by, sort_dir, offset, per_page) do
    base =
      from(mf in MeFile,
        join: u in User,
        on: u.id == mf.user_id,
        join: lh in LedgerHeader,
        on: lh.me_file_id == mf.id,
        where: ilike(u.alias, ^"%#{search}%"),
        offset: ^offset,
        limit: ^per_page,
        select: %{
          me_file_id: mf.id,
          alias: u.alias,
          wallet_balance: lh.balance,
          inserted_at: u.inserted_at
        }
      )

    case {sort_by, sort_dir} do
      {:alias, :asc} ->
        from([_mf, u, _lh] in base, order_by: [asc: u.alias])

      {:alias, :desc} ->
        from([_mf, u, _lh] in base, order_by: [desc: u.alias])

      {:wallet_balance, :asc} ->
        from([_mf, _u, lh] in base, order_by: [asc: lh.balance])

      {:wallet_balance, :desc} ->
        from([_mf, _u, lh] in base, order_by: [desc: lh.balance])

      {:inserted_at, :asc} ->
        from([_mf, u, _lh] in base, order_by: [asc: u.inserted_at])

      {:tag_count, :asc} ->
        from([mf, _u, _lh] in base,
          left_join: tc in subquery(tag_count_query()),
          on: tc.me_file_id == mf.id,
          order_by: [asc: coalesce(tc.tag_count, 0)]
        )

      {:tag_count, :desc} ->
        from([mf, _u, _lh] in base,
          left_join: tc in subquery(tag_count_query()),
          on: tc.me_file_id == mf.id,
          order_by: [desc: coalesce(tc.tag_count, 0)]
        )

      {:offer_count, :asc} ->
        from([mf, _u, _lh] in base,
          left_join: oc in subquery(offer_count_query()),
          on: oc.me_file_id == mf.id,
          order_by: [asc: coalesce(oc.offer_count, 0)]
        )

      {:offer_count, :desc} ->
        from([mf, _u, _lh] in base,
          left_join: oc in subquery(offer_count_query()),
          on: oc.me_file_id == mf.id,
          order_by: [desc: coalesce(oc.offer_count, 0)]
        )

      _ ->
        from([_mf, u, _lh] in base, order_by: [desc: u.inserted_at])
    end
  end

  defp tag_count_query do
    from(mft in MeFileTag,
      join: t in Trait,
      on: t.id == mft.trait_id,
      group_by: mft.me_file_id,
      select: %{me_file_id: mft.me_file_id, tag_count: trait_count_fragment(t)}
    )
  end

  defp offer_count_query do
    from(o in Offer,
      where: o.is_current == true,
      group_by: o.me_file_id,
      select: %{me_file_id: o.me_file_id, offer_count: count(o.id)}
    )
  end

  defp tag_counts_for([]), do: %{}

  defp tag_counts_for(me_file_ids) do
    from(mft in MeFileTag,
      join: t in Trait,
      on: t.id == mft.trait_id,
      where: mft.me_file_id in ^me_file_ids,
      group_by: mft.me_file_id,
      select: {mft.me_file_id, trait_count_fragment(t)}
    )
    |> Repo.all()
    |> Map.new()
  end

  defp offer_counts_for([]), do: %{}

  defp offer_counts_for(me_file_ids) do
    from(o in Offer,
      where: o.me_file_id in ^me_file_ids and o.is_current == true,
      group_by: o.me_file_id,
      select: {o.me_file_id, count(o.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  defp assign_metrics(socket) do
    total_users =
      from(u in User, where: u.role == "user", select: count(u.id))
      |> Repo.one()

    # The rich count and the average come back as one row. Loading every
    # MeFile's tag count into the app kept the checkout open for the transfer.
    %{rich: users_with_rich_mefiles, avg: avg_tags} =
      from(s in subquery(tag_count_query()),
        select: %{
          rich: filter(count(s.me_file_id), s.tag_count > 4),
          avg: avg(s.tag_count)
        }
      )
      |> Repo.one()

    avg_tags_per_user =
      case avg_tags do
        nil -> 0.0
        %Decimal{} = value -> value |> Decimal.to_float() |> Float.round(1)
        value when is_float(value) -> Float.round(value, 1)
        value when is_integer(value) -> value / 1
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

  defp format_date(datetime, assigns) do
    user = assigns.current_scope.user
    formatted = QlariusDateTime.format_for_user(datetime, user, :date_only)
    utc = QlariusDateTime.format_utc(datetime)

    "#{formatted} (#{utc})"
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
        <AdminSidebar.sidebar current_user={@current_scope.user} current_path={@current_path} />

        <div class="flex min-w-0 grow flex-col">
          <AdminTopbar.topbar current_user={@current_scope.user} />

          <div class="overflow-auto">
            <.page>
              <.page_header
                title="MeFile Inspector"
                count={@total_users}
                subtitle="Consumer MeFiles with their tags, offers and wallet balances."
              />

              <div class="mb-8 grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-6">
                <.stat_tile label="Total users" icon="hero-user-group" hint="All registered users">
                  {@total_users}
                </.stat_tile>
                <.stat_tile label="Rich MeFiles" icon="hero-star" hint="More than 4 tags">
                  {@users_with_rich_mefiles}
                </.stat_tile>
                <.stat_tile label="Avg tags per user" icon="hero-tag" hint="Per user average">
                  {@avg_tags_per_user}
                </.stat_tile>
                <.stat_tile label="Active offers" icon="hero-megaphone" hint="Users with offers">
                  {@users_with_active_offers}
                </.stat_tile>
                <.stat_tile
                  label="Avg balance"
                  icon="hero-currency-dollar"
                  hint={"#{@users_with_positive_balance} above $0, #{@users_with_zero_balance} at $0"}
                >
                  {QlariusWeb.Money.format_usd(@avg_wallet_balance)}
                </.stat_tile>
                <.stat_tile label="Recent" icon="hero-user-plus" hint="Last 7 days">
                  {@recent_registrations}
                </.stat_tile>
              </div>

              <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
                <.search_field
                  value={@search_query}
                  placeholder="Search by alias"
                  name="search"
                />
                <p class="text-sm text-base-content/60">
                  {@total_count} {if @total_count == 1, do: "MeFile", else: "MeFiles"}
                </p>
              </div>

              <.panel flush>
                <.empty_state
                  :if={@mefiles == []}
                  icon="hero-magnifying-glass"
                  title="No MeFiles found"
                >
                  <span :if={@search_query != ""}>Try a different search term</span>
                  <:action :if={@search_query != ""}>
                    <button type="button" phx-click="clear_search" class="btn btn-sm btn-ghost">
                      Clear search
                    </button>
                  </:action>
                </.empty_state>

                <div :if={@mefiles != []} class="overflow-x-auto">
                  <table class="w-full text-left text-sm">
                    <thead class="border-b border-base-300 bg-base-200/40 text-xs text-base-content/60">
                      <tr>
                        <.sort_header
                          column={:alias}
                          label="Alias"
                          sort_by={@sort_by}
                          sort_dir={@sort_dir}
                        />
                        <.sort_header
                          column={:wallet_balance}
                          label="Wallet balance"
                          sort_by={@sort_by}
                          sort_dir={@sort_dir}
                          align="right"
                        />
                        <.sort_header
                          column={:tag_count}
                          label="Tags"
                          sort_by={@sort_by}
                          sort_dir={@sort_dir}
                          align="center"
                        />
                        <.sort_header
                          column={:offer_count}
                          label="Active offers"
                          sort_by={@sort_by}
                          sort_dir={@sort_dir}
                          align="center"
                        />
                        <.sort_header
                          column={:inserted_at}
                          label="Created"
                          sort_by={@sort_by}
                          sort_dir={@sort_dir}
                          class="max-md:hidden"
                        />
                        <th class="px-6 py-3"><span class="sr-only">Actions</span></th>
                      </tr>
                    </thead>
                    <tbody class="divide-y divide-base-300">
                      <tr :for={mf <- @mefiles} class="transition-colors hover:bg-base-200/40">
                        <td class="px-6 py-3 align-middle">
                          <.link
                            navigate={~p"/admin/mefile_inspector/#{mf.me_file_id}"}
                            class="font-semibold hover:underline"
                          >
                            {mf.alias}
                          </.link>
                          <p class="text-xs text-base-content/50">#{mf.me_file_id}</p>
                        </td>
                        <td class="px-6 py-3 text-right align-middle">
                          {QlariusWeb.Money.format_usd(mf.wallet_balance)}
                        </td>
                        <td class="px-6 py-3 text-center align-middle">
                          <.chip>{mf.tag_count}</.chip>
                        </td>
                        <td class="px-6 py-3 text-center align-middle">
                          <.chip>{mf.offer_count}</.chip>
                        </td>
                        <td class="px-6 py-3 align-middle text-base-content/60 max-md:hidden">
                          {format_date(mf.inserted_at, assigns)}
                        </td>
                        <td class="w-0 px-6 py-3 align-middle">
                          <div class="flex items-center justify-end gap-1">
                            <.icon_button
                              icon="hero-eye"
                              label="View"
                              navigate={~p"/admin/mefile_inspector/#{mf.me_file_id}"}
                            />
                          </div>
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>

                <:footer :if={@total_pages > 1}>
                  <p class="mr-auto text-sm text-base-content/60">
                    Showing {(@page - 1) * 50 + 1}-{min(@page * 50, @total_count)} of {@total_count}
                  </p>
                  <div class="join">
                    <button
                      type="button"
                      phx-click="paginate"
                      phx-value-page="1"
                      class="join-item btn btn-sm"
                      disabled={@page == 1}
                      aria-label="First page"
                    >
                      <.icon name="hero-chevron-double-left" class="size-4" />
                    </button>
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

                    <%= for page_num <- pagination_range(@page, @total_pages) do %>
                      <%= if page_num == :ellipsis do %>
                        <button type="button" class="join-item btn btn-sm btn-disabled">...</button>
                      <% else %>
                        <button
                          type="button"
                          phx-click="paginate"
                          phx-value-page={page_num}
                          aria-current={page_num == @page && "page"}
                          class={["join-item btn btn-sm", page_num == @page && "btn-primary"]}
                        >
                          {page_num}
                        </button>
                      <% end %>
                    <% end %>

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
                    <button
                      type="button"
                      phx-click="paginate"
                      phx-value-page={@total_pages}
                      class="join-item btn btn-sm"
                      disabled={@page == @total_pages}
                      aria-label="Last page"
                    >
                      <.icon name="hero-chevron-double-right" class="size-4" />
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

  attr :column, :atom, required: true
  attr :label, :string, required: true
  attr :sort_by, :atom, required: true
  attr :sort_dir, :atom, required: true
  attr :align, :string, default: "left", values: ~w(left center right)
  attr :class, :any, default: nil

  defp sort_header(assigns) do
    ~H"""
    <th
      class={["px-6 py-3 font-medium", @class]}
      aria-sort={@sort_by == @column && if(@sort_dir == :asc, do: "ascending", else: "descending")}
    >
      <button
        type="button"
        phx-click="sort"
        phx-value-column={@column}
        class={[
          "flex items-center gap-1 font-medium hover:text-base-content",
          @sort_by == @column && "text-base-content",
          @align == "right" && "ml-auto",
          @align == "center" && "mx-auto"
        ]}
      >
        {@label}
        <.icon
          :if={@sort_by == @column}
          name={if @sort_dir == :asc, do: "hero-arrow-up", else: "hero-arrow-down"}
          class="size-3.5"
        />
      </button>
    </th>
    """
  end
end
