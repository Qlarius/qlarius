defmodule QlariusWeb.WalletLive do
  use QlariusWeb, :live_view

  import QlariusWeb.WalletHTML

  alias Qlarius.Wallets

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    ledger_header = Wallets.get_user_ledger_header(user.id)

    page = 1
    per_page = 20
    paginated_entries = Wallets.list_ledger_entries(ledger_header.id, page, per_page)

    socket
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
  def render(assigns) do
    ~H"""
    <Layouts.mobile {assigns}>
      <h1 class="text-3xl font-bold mb-4">Wallet</h1>

      <div class="mb-6">
        <div class="text-lg">Current Balance:</div>
        <div class="text-2xl text-green-500 font-bold">
          {format_currency(@ledger_header.balance)}
        </div>
      </div>

      <div class="flex justify-center mb-6 space-x-2">
        <%= if @page > 1 do %>
          <button
            phx-click="paginate"
            phx-value-page="1"
            class="px-4 py-2 bg-gray-200 rounded-md hover:bg-gray-300"
          >
            Newest
          </button>

          <button
            phx-click="paginate"
            phx-value-page={@page - 1}
            class="px-4 py-2 bg-gray-200 rounded-md hover:bg-gray-300"
          >
            <.icon name="hero-chevron-left" class="h-4 w-4" />
          </button>
        <% end %>

        <div class="flex items-center px-4 py-2 bg-green-500 text-white rounded-md">
          {@page}
        </div>

        <%= if @page < @paginated_entries.total_pages do %>
          <button
            phx-click="paginate"
            phx-value-page={@page + 1}
            class="px-4 py-2 bg-gray-200 rounded-md hover:bg-gray-300"
          >
            <.icon name="hero-chevron-right" class="h-4 w-4" />
          </button>
        <% else %>
          <div class="px-2 py-2 flex items-center text-gray-400">
            <.icon name="hero-chevron-right" class="h-4 w-4" />
          </div>
        <% end %>

        <button
          phx-click="paginate"
          phx-value-page="oldest"
          class="px-4 py-2 bg-gray-200 rounded-md hover:bg-gray-300"
        >
          Oldest
        </button>
      </div>

      <h2 class="text-xl font-semibold mb-4">Ledger History</h2>

      <div class="divide-y divide-gray-200">
        <div
          :for={entry <- @paginated_entries.entries}
          class="py-4 flex justify-between items-center cursor-pointer"
          phx-click="open-ledger-entry-sidebar"
          phx-value-entry_id={entry.id}
        >
          <div>
            <div class="font-medium">{entry.description}</div>
            <div class="text-content-base/50">{format_date(entry.inserted_at)}</div>
          </div>
          <div class="flex items-center">
            <div class="text-right mr-4">
              <div>{format_currency(entry.amount)}</div>
              <div class="text-gray-500">
                {format_currency(entry.running_balance)}
              </div>
            </div>
            <div class="text-gray-400">
              <.icon name="hero-chevron-right" class="h-6 w-6" />
            </div>
          </div>
        </div>
      </div>

      <.ledger_entry_detail_sidebar :if={@sidebar_entry} entry={@sidebar_entry} />
    </Layouts.mobile>
    """
  end

  # Helper functions
  defp format_currency(amount) do
    "$#{:erlang.float_to_binary(Decimal.to_float(amount), decimals: 2)}"
  end

  defp format_date(datetime) do
    "#{datetime.year}-#{pad_zero(datetime.month)}-#{pad_zero(datetime.day)} #{datetime.hour}:#{datetime.minute} sdfds"
  end

  defp pad_zero(number) when number < 10, do: "0#{number}"
  defp pad_zero(number), do: "#{number}"
end
