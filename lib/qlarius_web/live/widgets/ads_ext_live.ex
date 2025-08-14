defmodule QlariusWeb.Widgets.AdsExtLive do
  use QlariusWeb, :live_view

  alias Qlarius.Accounts.Users
  # Commented out unused alias - Sponster not directly referenced (only string "Sponster" used)
  # alias Qlarius.Sponster
  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.Sponster.Offer
  # Commented out unused alias - User not directly referenced in this file
  # alias Qlarius.Accounts.User
  # Commented out unused aliases - LedgerHeader/LedgerEntry not directly referenced in this file
  # alias Qlarius.Wallets.{LedgerHeader, LedgerEntry}
  # Commented out unused alias - AdEvent not directly referenced in this file
  # alias Qlarius.Sponster.AdEvent
  # Commented out unused alias - Recipient not directly referenced in this file
  # alias Qlarius.Sponster.Recipient
  alias Qlarius.Repo
  # Commented out unused alias - Scope not directly referenced in this file
  # alias Qlarius.Accounts.Scope
  # Commented out unused alias - ThreeTap not directly referenced in this file
  # alias Qlarius.Sponster.Ads.ThreeTap
  # Commented out unused alias - Component not directly referenced in this file
  # alias Phoenix.Component
  alias Qlarius.Wallets.Wallets
  alias Qlarius.Wallets.MeFileBalanceBroadcaster
  # Commented out unused import - OfferHTML functions not used in this LiveView  
  # import QlariusWeb.OfferHTML
  import Ecto.Query, except: [update: 2, update: 3]
  # Commented out unused import - Layouts functions not used in this LiveView
  # import QlariusWeb.Layouts

  on_mount {QlariusWeb.GetUserIP, :assign_ip}

  @impl true
  def mount(params, _session, socket) do
    # Load initial data during first mount
    # User and current_scope extracted for clarity but not directly used in this function
    _user = socket.assigns.current_scope.user
    _current_scope = socket.assigns.current_scope

    host_uri =
      case Phoenix.LiveView.get_connect_info(socket, :uri) do
        nil -> URI.parse("http://localhost")
        uri -> uri
      end

    split_code = Map.get(params, "split_code")
    recipient = Users.get_recipient_by_split_code(split_code)

    socket =
      socket
      |> assign(:active_offers, [])
      |> assign(:loading, true)
      |> assign(:host_uri, host_uri)
      |> assign(:split_code, split_code)
      |> assign(:recipient, recipient)
      |> assign(:page_title, "Sponster")

    if connected?(socket) do
      send(self(), :load_offers)

      MeFileBalanceBroadcaster.subscribe_to_me_file_balance(
        socket.assigns.current_scope.user.me_file.id
      )

      {:ok, socket}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_info(:load_offers, socket) do
    query =
      from(o in Offer,
        where:
          o.me_file_id == ^socket.assigns.current_scope.user.me_file.id and o.is_current == true,
        order_by: [desc: o.offer_amt],
        preload: [media_piece: :ad_category]
      )

    active_offers =
      query
      |> Repo.all()
      |> Enum.map(fn offer -> {offer, 0} end)

    {:noreply,
     socket
     |> assign(:active_offers, active_offers)
     |> assign(:loading, false)}
  end

  # me_file_id from message not used - we get me_file from socket.assigns instead
  @impl true
  def handle_info({:refresh_wallet_balance, _me_file_id}, socket) do
    new_balance =
      Wallets.get_me_file_ledger_header_balance(socket.assigns.current_scope.user.me_file)

    current_scope = Map.put(socket.assigns.current_scope, :wallet_balance, new_balance)
    {:noreply, assign(socket, :current_scope, current_scope)}
  end

  @impl true
  def handle_info({:me_file_balance_updated, new_balance}, socket) do
    current_scope = Map.put(socket.assigns.current_scope, :wallet_balance, new_balance)
    {:noreply, assign(socket, :current_scope, current_scope)}
  end

  @impl true
  def handle_event("set_split", %{"split" => split}, socket) do
    split_amount = String.to_integer(split)
    me_file = socket.assigns.current_scope.user.me_file

    case MeFile.update_me_file_split_amount(me_file, split_amount) do
      {:ok, updated_me_file} ->
        current_scope =
          Map.put(
            socket.assigns.current_scope,
            :user,
            Map.put(socket.assigns.current_scope.user, :me_file, updated_me_file)
          )

        {:noreply, assign(socket, :current_scope, current_scope)}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.tipjar_container {assigns}>
      <div class="container mx-auto px-0 py-8 max-w-3xl my-[60px]">
        <.live_component
          module={QlariusWeb.ThreeTapStackComponent}
          id="three-tap-stack"
          active_offers={@active_offers}
          user_ip={@user_ip}
          current_scope={@current_scope}
          host_uri={@host_uri}
          recipient={@recipient}
        />
      </div>
    </Layouts.tipjar_container>
    <Layouts.debug_assigns {assigns} />
    """
  end

  @impl true
  def terminate(_reason, _socket) do
    :ok
  end
end
