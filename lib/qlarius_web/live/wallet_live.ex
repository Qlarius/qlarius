defmodule QlariusWeb.WalletLive do
  use QlariusWeb, :live_view

  import QlariusWeb.WalletHTML
  import QlariusWeb.PWAHelpers
  alias QlariusWeb.Layouts

  alias Qlarius.Wallets
  alias Qlarius.Wallets.LedgerHeader
  alias Qlarius.Repo
  alias Qlarius.DateTime, as: QlariusDateTime
  alias Qlarius.Sponster.Campaigns.Targets

  @impl true
  def mount(_params, _session, socket) do
    current_scope = socket.assigns.current_scope
    user = current_scope.user
    me_file = user.me_file

    ledger_header = Repo.get_by(LedgerHeader, me_file_id: me_file.id)

    page = 1
    per_page = 20
    paginated_entries = Wallets.list_ledger_entries(ledger_header.id, page, per_page)

    socket
    |> assign(:current_path, "/wallet")
    |> assign(:title, "Wallet")
    |> assign(:me_file, me_file)
    |> assign(:loading, true)
    |> assign(:ledger_header, ledger_header)
    |> assign(:sidebar_entry, nil)
    |> assign(:selected_entry, nil)
    |> assign(:entry_details, nil)
    |> assign(:page, page)
    |> assign(:paginated_entries, paginated_entries)
    |> assign(:is_pwa, false)
    |> assign(:device_type, :desktop)
    |> ok()
  end

  @impl true
  def handle_event("pwa_detected", params, socket) do
    handle_pwa_detection(socket, params)
  end

  def handle_event("close-ledger-entry-sidebar", _params, socket) do
    {:noreply, assign(socket, :sidebar_entry, nil)}
  end

  def handle_event("select_ledger_entry", %{"entry_id" => entry_id}, socket) do
    entry_id = String.to_integer(entry_id)

    # Get the detailed entry with associations
    entry = Wallets.get_ledger_entry!(entry_id, socket.assigns.me_file)

    # Load transaction details based on entry type
    entry_details = get_entry_details(entry)

    socket =
      socket
      |> assign(:selected_entry, entry)
      |> assign(:entry_details, entry_details)

    {:noreply, socket}
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    {:noreply, push_patch(socket, to: ~p"/wallet?page=#{page}")}
  end

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
  def render(assigns) do
    ~H"""
    <div id="wallet-pwa-detect" phx-hook="HiPagePWADetect">
      <Layouts.mobile {assigns}>
        <%= if assigns[:error] do %>
          <div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
            {@error}
          </div>
        <% else %>
          <%= if Enum.empty?(@paginated_entries.entries) do %>
            <div class="flex items-center justify-center min-h-[50vh]">
              <p class="text-xl text-base-content/70">No ledger activity to display.</p>
            </div>
          <% else %>
            <div class="flex justify-center mt-10 mb-6 space-x-2">
              <div class="join">
                <button
                  phx-click="paginate"
                  phx-value-page="1"
                  class={"join-item btn btn-md #{if @page < 2, do: "btn-disabled"}"}
                >
                  Newest
                </button>
                <button
                  phx-click="paginate"
                  phx-value-page={if @page > 1, do: @page - 1, else: 1}
                  class={"join-item btn btn-md #{if @page < 2, do: "btn-disabled"}"}
                >
                  <.icon name="hero-chevron-left" class="h-4 w-4" />
                </button>
                <div class="join-item btn btn-md btn-neutral">
                  Page {@page}
                </div>
                <button
                  phx-click="paginate"
                  phx-value-page={@page + 1}
                  class={"join-item btn btn-md #{if @page == @paginated_entries.total_pages, do: "btn-disabled"}"}
                >
                  <.icon name="hero-chevron-right" class="h-4 w-4" />
                </button>
                <button
                  phx-click="paginate"
                  phx-value-page="oldest"
                  class={"join-item btn btn-md #{if @page == @paginated_entries.total_pages, do: "btn-disabled"}"}
                >
                  Oldest
                </button>
              </div>
            </div>

            <ul class="-mx-4 sm:mx-0 list bg-base-200 dark:!bg-base-200 sm:rounded-box shadow-md overflow-hidden">
              <li
                :for={entry <- @paginated_entries.entries}
                class="list-row cursor-pointer transition-all duration-200 !rounded-none hover:bg-base-300 dark:hover:!bg-base-100"
                phx-click={
                  %JS{}
                  |> JS.push("select_ledger_entry", loading: "#right-sidebar-container")
                  |> JS.add_class("translate-x-0", to: "#right-sidebar")
                  |> JS.remove_class("translate-x-full", to: "#right-sidebar")
                  |> JS.remove_class("opacity-0 pointer-events-none", to: "#right-sidebar-bg")
                  |> JS.add_class("sidebar-scroll-lock", to: "body")
                  |> JS.add_class("sidebar-scroll-lock", to: "html")
                }
                phx-value-entry_id={entry.id}
              >
                <div class="flex flex-col items-start justify-start mr-1">
                  <span class={[
                    "inline-flex items-center justify-center rounded-full w-8 h-8",
                    if(Decimal.compare(entry.amt, 0) == :gt,
                      do: "!bg-sponster-200 dark:!bg-sponster-800",
                      else: "!bg-tiqit-200 dark:!bg-tiqit-800"
                    )
                  ]}>
                    <.icon name={icon_for_meta_1(entry.meta_1)} class="h-4 w-4 text-base-content" />
                  </span>
                </div>
                <div class="list-col-grow">
                  <div class="text-lg leading-snug">{entry.description}</div>
                  <div class="text-base-content/50 text-sm">{entry.meta_1}</div>
                  <div class="text-base-content/50 text-sm">{format_date(entry.created_at, assigns)}</div>
                </div>
                <div class="flex items-start">
                  <div class="text-right mr-2">
                    <div class="flex items-center gap-1">
                      <span
                        :if={Decimal.compare(entry.amt, 0) != 0}
                        class={[
                          "badge badge-md p-1 mr-1",
                          if(Decimal.compare(entry.amt, 0) == :gt,
                            do: "!bg-sponster-200 dark:!bg-sponster-800",
                            else: "!bg-tiqit-200 dark:!bg-tiqit-800"
                          )
                        ]}
                      >
                        <.icon
                          name={
                            if(Decimal.compare(entry.amt, 0) == :gt,
                              do: "hero-plus",
                              else: "hero-minus"
                            )
                          }
                          class="h-3 w-3 text-base-content"
                        />
                      </span>
                      <span class={[
                        "text-lg font-bold",
                        if(Decimal.compare(entry.amt, 0) == :gt,
                          do: "text-sponster-500 dark:text-sponster-300",
                          else: "text-tiqit-500"
                        )
                      ]}>
                        {format_currency(Decimal.abs(entry.amt))}
                      </span>
                    </div>
                    <div class="text-base-content/50 text-sm">
                      {format_currency(entry.running_balance)}
                    </div>
                  </div>
                  <div class="text-base-content/50">
                    <.icon name="hero-chevron-right" class="h-6 w-6" />
                  </div>
                </div>
              </li>
            </ul>
          <% end %>
        <% end %>

        <.ledger_entry_detail_sidebar :if={@sidebar_entry} entry={@sidebar_entry} />
      </Layouts.mobile>
    </div>
    """
  end

  # Helper functions
  defp format_currency(amount) do
    "$#{:erlang.float_to_binary(Decimal.to_float(amount), decimals: 2)}"
  end

  defp format_date(datetime, assigns) do
    QlariusDateTime.format_for_user(datetime, assigns.current_scope.user, :short)
  end

  # Commented out unused function - not called anywhere in the codebase
  # Calculate the balance at a specific entry point
  # This is a simplified approach - in a real app, you might want to store running balances
  # defp calculate_balance_at_entry(ledger_header, current_entry, entries) do
  #   # Find entries that came after the current entry (newer entries)
  #   newer_entries =
  #     entries
  #     |> Enum.filter(fn entry ->
  #       NaiveDateTime.compare(entry.created_at, current_entry.created_at) == :gt
  #     end)

  #   # Subtract the sum of newer entries from the current balance
  #   newer_entries_sum =
  #     newer_entries
  #     |> Enum.reduce(Decimal.new(0), fn entry, acc ->
  #       Decimal.add(acc, entry.amt)
  #     end)

  #   Decimal.sub(ledger_header.balance, newer_entries_sum)
  # end

  defp get_entry_details(entry) do
    cond do
      # Ad event entry
      entry.ad_event_id != nil ->
        get_ad_event_details(entry.ad_event)

      # Tiqit purchase (identified by description)
      String.contains?(entry.description, "Tiqit purchase") ->
        get_tiqit_purchase_details(entry)

      # Other transaction types
      true ->
        %{type: :other, description: entry.description}
    end
  end

  defp get_ad_event_details(ad_event) do
    ad_event =
      ad_event
      |> Repo.preload([
        :media_piece,
        :campaign,
        campaign: [:marketer]
      ])

    matching_tags =
      case ad_event.matching_tags_snapshot do
        nil -> []
        snapshot -> Targets.snapshot_to_tuples(snapshot)
      end

    %{
      type: :ad_event,
      ad_event: ad_event,
      media_piece: ad_event.media_piece,
      matching_tags: matching_tags,
      campaign_title: ad_event.campaign && ad_event.campaign.title,
      marketer_name: get_marketer_name(ad_event.campaign)
    }
  end

  defp get_tiqit_purchase_details(entry) do
    if entry.tiqit_id do
      case Wallets.get_tiqit_purchase_details(entry.tiqit_id) do
        %{
          tiqit: tiqit,
          creator: creator,
          content_group: content_group,
          content_piece: content_piece
        } ->
          %{
            type: :tiqit_purchase,
            tiqit: tiqit,
            creator: creator,
            content_group: content_group,
            content_piece: content_piece,
            purchase_time: entry.created_at,
            amount: entry.amt
          }

        nil ->
          # Fallback if tiqit not found
          %{
            type: :tiqit_purchase,
            tiqit: nil,
            creator: nil,
            content_group: nil,
            content_piece: nil,
            description: entry.description,
            amount: entry.amt,
            purchase_time: entry.created_at
          }
      end
    else
      # Fallback for entries without tiqit association
      %{
        type: :tiqit_purchase,
        tiqit: nil,
        creator: nil,
        content_group: nil,
        content_piece: nil,
        description: entry.description,
        amount: entry.amt,
        purchase_time: entry.created_at
      }
    end
  end

  defp get_marketer_name(campaign) when campaign != nil do
    campaign = Repo.preload(campaign, :marketer)
    campaign.marketer.business_name
  end

  defp get_marketer_name(_), do: "Unknown"

  def icon_for_meta_1("Tip/Donation"), do: "hero-gift"
  def icon_for_meta_1("Tiqit Purchase"), do: "hero-ticket"
  def icon_for_meta_1("Referral Bonus"), do: "hero-user-group"
  def icon_for_meta_1("Text/Jump"), do: "hero-arrow-right-start-on-rectangle"
  def icon_for_meta_1("Banner Tap"), do: "hero-photo"
  def icon_for_meta_1("Video Viewing"), do: "hero-play-circle"
  def icon_for_meta_1(_), do: "hero-cube"
end
