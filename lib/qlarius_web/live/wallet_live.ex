defmodule QlariusWeb.WalletLive do
  use QlariusWeb, :live_view

  import QlariusWeb.WalletHTML
  import QlariusWeb.Components.LedgerEntriesList
  import QlariusWeb.PWAHelpers
  alias QlariusWeb.Layouts

  on_mount {QlariusWeb.DetectMobile, :detect_mobile}

  alias Qlarius.Wallets
  alias Qlarius.Wallets.LedgerHeader
  alias Qlarius.Repo
  alias Qlarius.Sponster.Campaigns.Targets
  @impl true
  def mount(_params, session, socket) do
    current_scope = socket.assigns.current_scope
    user = current_scope.user
    me_file = user.me_file

    ledger_header = Repo.get_by(LedgerHeader, me_file_id: me_file.id)

    page = 1
    per_page = 20
    paginated_entries = Wallets.list_ledger_entries(ledger_header.id, page, per_page)

    socket =
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Qlarius.PubSub, "wallet:#{user.id}")
        socket
      else
        socket
      end

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
    |> assign(:undo_context, nil)
    |> init_pwa_assigns(session)
    |> ok()
  end

  @impl true
  def handle_event("pwa_detected", params, socket) do
    handle_pwa_detection(socket, params)
  end

  def handle_event("referral_code_from_storage", _params, socket) do
    {:noreply, socket}
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

  def handle_event("fleet_tiqit", %{"id" => id}, socket) do
    tiqit = Qlarius.Repo.get!(Qlarius.Tiqit.Arcade.Tiqit, id)

    case Qlarius.Tiqit.Arcade.Arcade.fleet_tiqit!(tiqit) do
      {:ok, _} -> {:noreply, reload_ledger(socket)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Could not fleet tiqit")}
    end
  end

  def handle_event("preserve_tiqit", %{"id" => id}, socket) do
    tiqit = Qlarius.Repo.get!(Qlarius.Tiqit.Arcade.Tiqit, id)

    case Qlarius.Tiqit.Arcade.Arcade.preserve_tiqit(tiqit, true) do
      {:ok, _} -> {:noreply, reload_entry_details(socket)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Could not mark tiqit")}
    end
  end

  def handle_event("unpreserve_tiqit", %{"id" => id}, socket) do
    tiqit = Qlarius.Repo.get!(Qlarius.Tiqit.Arcade.Tiqit, id)

    case Qlarius.Tiqit.Arcade.Arcade.preserve_tiqit(tiqit, false) do
      {:ok, _} -> {:noreply, reload_entry_details(socket)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Could not unmark tiqit")}
    end
  end

  def handle_event("clear_undo_context", _params, socket) do
    {:noreply, assign(socket, :undo_context, nil)}
  end

  def handle_event("prepare_undo", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    tiqit = Qlarius.Repo.get!(Qlarius.Tiqit.Arcade.Tiqit, id)
    undo_context = Qlarius.Tiqit.Arcade.Arcade.get_undo_context(scope, tiqit)

    {:noreply, assign(socket, :undo_context, undo_context)}
  end

  def handle_event("undo_tiqit", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    tiqit = Qlarius.Repo.get!(Qlarius.Tiqit.Arcade.Tiqit, id)

    case Qlarius.Tiqit.Arcade.Arcade.undo_tiqit!(scope, tiqit) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:undo_context, nil)
         |> put_flash(:info, "Tiqit refunded successfully")
         |> reload_ledger()}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:undo_context, nil)
         |> put_flash(:error, "Could not refund: #{reason}")}
    end
  end

  defp reload_entry_details(socket) do
    case socket.assigns do
      %{selected_entry: %{} = entry} ->
        entry = Wallets.get_ledger_entry!(entry.id, socket.assigns.me_file)
        entry_details = get_entry_details(entry)

        socket
        |> assign(:selected_entry, entry)
        |> assign(:entry_details, entry_details)

      _ ->
        socket
    end
  end

  # Assign-only refresh (no push_patch / navigate) so the mobile shell scroll
  # container keeps its scroll position across ledger PubSub updates.
  defp reload_ledger(socket) do
    %{me_file: me_file, page: page} = socket.assigns
    per_page = 20

    ledger_header = Repo.get_by!(LedgerHeader, me_file_id: me_file.id)
    paginated_entries = Wallets.list_ledger_entries(ledger_header.id, page, per_page)

    current_scope =
      Map.put(socket.assigns.current_scope, :wallet_balance, ledger_header.balance)

    socket
    |> assign(:ledger_header, ledger_header)
    |> assign(:paginated_entries, paginated_entries)
    |> assign(:current_scope, current_scope)
    |> reload_entry_details()
  end

  @impl true
  def handle_info(:ledger_updated, socket) do
    {:noreply, reload_ledger(socket)}
  end

  def handle_info(:update_balance, socket) do
    {:noreply, reload_ledger(socket)}
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
            <div class="flex flex-col items-center justify-center min-h-[50vh] gap-4">
              <p class="text-xl text-base-content/70">No ledger activity to display.</p>
              <p class="text-base text-base-content/60">
                Check out your first ads and seed this wallet.
              </p>
              <.link navigate="/ads" class="btn btn-primary btn-lg rounded-full px-6 py-5 shadow-lg">
                View Ads
              </.link>
            </div>
          <% else %>
            <.ledger_entries_pagination
              paginated_entries={@paginated_entries}
              page={@page}
            />
            <.surface_panel padding={false}>
              <.ledger_entries_list
                paginated_entries={@paginated_entries}
                page={@page}
                current_scope={@current_scope}
                show_pagination={false}
                list_class="list !mx-0 !rounded-none !shadow-none !bg-base-100 dark:!bg-black divide-y divide-base-300/60 dark:divide-base-content/10"
              />
            </.surface_panel>
          <% end %>
        <% end %>

        <.ledger_entry_detail_sidebar :if={@sidebar_entry} entry={@sidebar_entry} />
      </Layouts.mobile>

      <QlariusWeb.TiqitComponents.fleet_confirm_modal id="sidebar-fleet-confirm-modal" />
      <QlariusWeb.TiqitComponents.preserve_confirm_modal id="sidebar-preserve-confirm-modal" />
      <QlariusWeb.TiqitComponents.unpreserve_confirm_modal id="sidebar-unpreserve-confirm-modal" />
      <QlariusWeb.TiqitComponents.undo_confirm_modal
        id="sidebar-undo-confirm-modal"
        undo_context={@undo_context}
      />
      <div
        :if={@undo_context}
        id="sidebar-undo-modal-trigger"
        phx-mounted={show_modal("sidebar-undo-confirm-modal")}
      />
    </div>
    """
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

      # Tiqit-related entry (purchase, undo, etc.)
      entry.tiqit_id != nil or String.contains?(entry.description, "Tiqit") ->
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
        :campaign,
        campaign: [:marketer],
        media_piece: [:media_piece_type, :ad_category]
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
      reason =
        cond do
          entry.meta_1 in ["Tiqit Refund", "Tiqit Undo"] -> :undone
          entry.description == "*REFUNDED*" -> :undone
          String.contains?(to_string(entry.description), "undo") -> :undone
          true -> :fleeted
        end

      %{
        type: :tiqit_purchase,
        tiqit: nil,
        creator: nil,
        content_group: nil,
        content_piece: nil,
        description: entry.description,
        amount: entry.amt,
        purchase_time: entry.created_at,
        disconnect_reason: reason
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
  def icon_for_meta_1("Tiqit Refund"), do: "hero-arrow-uturn-left"
  def icon_for_meta_1("Tiqit Undo"), do: "hero-arrow-uturn-left"
  def icon_for_meta_1("Referral Bonus"), do: "hero-user-group"
  def icon_for_meta_1("Text/Jump"), do: "hero-arrow-right-start-on-rectangle"
  def icon_for_meta_1("Banner Tap"), do: "hero-photo"
  def icon_for_meta_1("Video Ad"), do: "hero-film"
  def icon_for_meta_1("Video Viewing"), do: "hero-film"
  def icon_for_meta_1(_), do: "hero-cube"
end
