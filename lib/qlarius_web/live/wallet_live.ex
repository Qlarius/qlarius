defmodule QlariusWeb.WalletLive do
  use QlariusWeb, :live_view

  import QlariusWeb.WalletHTML

  alias Qlarius.Accounts.Users
  alias Qlarius.Accounts.Scope
  alias Qlarius.Wallets.Wallets
  alias Qlarius.Accounts.User
  alias Qlarius.Wallets.LedgerHeader
  alias Qlarius.Repo

  @impl true
  def mount(_params, _session, socket) do
    socket = assign(socket, :current_path, "/wallet")
    # Load initial data during first mount
    true_user = Users.get_user(508)
    user = User.active_proxy_user_or_self(true_user)
    current_scope = Scope.for_user(user)
    me_file = Users.get_user_me_file(user.id)

    # me_file = Repo.get_by(MeFile, user_id: user.id)
    ledger_header = Repo.get_by(LedgerHeader, me_file_id: me_file.id)

    # ledger_header = Wallets.get_user_ledger_header(user.id)

    page = 1
    per_page = 20
    paginated_entries = Wallets.list_ledger_entries(ledger_header.id, page, per_page)

    socket
    |> assign(:true_user, true_user)
    |> assign(:current_scope, current_scope)
    |> assign(:me_file, me_file)
    |> assign(:loading, true)
    |> assign(:ledger_header, ledger_header)
    |> assign(:sidebar_entry, nil)
    |> assign(:page, page)
    |> assign(:paginated_entries, paginated_entries)
    |> ok()
  end

  @impl true
  def handle_params(params, _url, socket) do
    page =
      case params["page"] do
        "oldest" ->
          if socket.assigns[:paginated_entries] do
            socket.assigns.paginated_entries.total_pages
          else
            1
          end

        "1" ->
          1

        nil ->
          1

        page_str ->
          String.to_integer(page_str)
      end

    if socket.assigns[:ledger_header] do
      paginated_entries = Wallets.list_ledger_entries(socket.assigns.ledger_header.id, page, 20)

      {:noreply,
       socket
       |> assign(:page, page)
       |> assign(:paginated_entries, paginated_entries)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close-ledger-entry-sidebar", _params, socket) do
    {:noreply, assign(socket, :sidebar_entry, nil)}
  end

  @impl true
  def handle_event("open-ledger-entry-sidebar", %{"entry_id" => entry_id}, socket) do
    entry = Wallets.get_ledger_entry!(entry_id, socket.assigns.current_scope.user)

    socket
    |> assign(:sidebar_entry, entry)
    |> noreply()
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    {:noreply, push_patch(socket, to: ~p"/wallet?page=#{page}")}
  end

  @impl true
  def handle_event("toggle_sidebar", %{"state" => state}, socket) do
    js =
      if state == "on" do
        %JS{}
        |> JS.add_class("translate-x-0", to: "#sponster-sidebar")
        |> JS.remove_class("-translate-x-full", to: "#sponster-sidebar")
        |> JS.remove_class("opacity-0 pointer-events-none", to: "#sponster-sidebar-bg")
      else
        %JS{}
        |> JS.remove_class("translate-x-0", to: "#sponster-sidebar")
        |> JS.add_class("-translate-x-full", to: "#sponster-sidebar")
        |> JS.add_class("opacity-0 pointer-events-none", to: "#sponster-sidebar-bg")
      end

    {:noreply, push_event(socket, "js", js)}
  end

  @impl true
  def handle_event("toggle_sidebar", _params, socket) do
    # Handle click-away event
    js =
      %JS{}
      |> JS.remove_class("translate-x-0", to: "#sponster-sidebar")
      |> JS.add_class("-translate-x-full", to: "#sponster-sidebar")
      |> JS.add_class("opacity-0 pointer-events-none", to: "#sponster-sidebar-bg")

    {:noreply, push_event(socket, "js", js)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.sponster {assigns}>
      <h1 class="text-3xl font-bold mb-4">Wallet</h1>

      <%= if assigns[:error] do %>
        <div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
          {@error}
        </div>
      <% else %>
        <div class="mb-6">
          <div class="text-lg">Current Balance:</div>
          <div class="text-2xl text-sponster font-bold">
            {format_currency(@ledger_header.balance)}
          </div>
        </div>

        <div class="flex justify-center mb-6 space-x-2">
          <%= if @page > 1 do %>
            <button
              phx-click="paginate"
              phx-value-page="1"
              class="px-4 py-2 bg-gray-200 rounded-md hover:bg-gray-300 cursor-pointer"
            >
              Newest
            </button>

            <button
              phx-click="paginate"
              phx-value-page={@page - 1}
              class="px-4 py-2 bg-gray-200 rounded-md hover:bg-gray-300 cursor-pointer"
            >
              &lt;
            </button>
          <% end %>

          <div class="flex items-center px-4 py-2 bg-sponster text-white rounded-md">
            {@page}
          </div>

          <%= if @page < @paginated_entries.total_pages do %>
            <button
              phx-click="paginate"
              phx-value-page={@page + 1}
              class="px-4 py-2 bg-gray-200 rounded-md hover:bg-gray-300 cursor-pointer"
            >
              &gt;
            </button>
          <% else %>
            <div class="px-2 py-2 flex items-center text-gray-400">
              <.icon name="hero-chevron-right" class="h-6 w-6" />
            </div>
          <% end %>

          <button
            phx-click="paginate"
            phx-value-page="oldest"
            class="px-4 py-2 bg-gray-200 rounded-md hover:bg-gray-300 cursor-pointer"
          >
            Oldest
          </button>
        </div>

        <h2 class="text-xl font-semibold mb-4">Transactions</h2>

        <div class="divide-y divide-gray-200">
          <div
            :for={entry <- @paginated_entries.entries}
            class="py-4 flex justify-between items-center cursor-pointer"
            phx-click="open-ledger-entry-sidebar"
            phx-value-entry_id={entry.id}
          >
            <div>
              <div class="text-small">{entry.description}</div>
              <div class="text-gray-500 text-xs">{format_date(entry.created_at)}</div>
            </div>
            <div class="flex items-center">
              <div class="text-right mr-4">
                <div class="text-sm font-bold">{format_currency(entry.amt)}</div>
                <div class="text-gray-500 text-xs">
                  {format_currency(entry.running_balance)}
                </div>
              </div>
              <div class="text-gray-400">
                <.icon name="hero-chevron-right" class="h-6 w-6" />
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <.ledger_entry_detail_sidebar :if={@sidebar_entry} entry={@sidebar_entry} />
    </Layouts.sponster>
    """
  end

  # Helper functions
  defp format_currency(amount) do
    "$#{:erlang.float_to_binary(Decimal.to_float(amount), decimals: 2)}"
  end

  defp format_date(datetime) do
    "#{datetime.year}-#{pad_zero(datetime.month)}-#{pad_zero(datetime.day)}"
  end

  defp pad_zero(number) when number < 10, do: "0#{number}"
  defp pad_zero(number), do: "#{number}"

  # Calculate the balance at a specific entry point
  # This is a simplified approach - in a real app, you might want to store running balances
  defp calculate_balance_at_entry(ledger_header, current_entry, entries) do
    # Find entries that came after the current entry (newer entries)
    newer_entries =
      entries
      |> Enum.filter(fn entry ->
        NaiveDateTime.compare(entry.created_at, current_entry.created_at) == :gt
      end)

    # Subtract the sum of newer entries from the current balance
    newer_entries_sum =
      newer_entries
      |> Enum.reduce(Decimal.new(0), fn entry, acc ->
        Decimal.add(acc, entry.amt)
      end)

    Decimal.sub(ledger_header.balance, newer_entries_sum)
  end
end
