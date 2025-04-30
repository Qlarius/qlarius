defmodule QlariusWeb.AdsLive do
  use QlariusWeb, :live_view

  alias Qlarius.Legacy
  alias Qlarius.Legacy.{MeFile, Offer, User, LedgerHeader, AdEvent, LedgerEntry}
  alias Qlarius.LegacyRepo
  alias Qlarius.Accounts.Scope
  alias Qlarius.Ads.ThreeTap
  alias Phoenix.Component
  alias Qlarius.Wallets
  import QlariusWeb.OfferHTML
  import Ecto.Query, except: [update: 2, update: 3]

  on_mount {QlariusWeb.GetUserIP, :assign_ip}

  @debug true

  @impl true
  def mount(_params, session, socket) do
    # Load initial data during first mount
    user = Legacy.get_user(508)
    current_scope = Scope.for_user(user)
    me_file = Legacy.get_user_me_file(current_scope.user.id)

    socket =
      socket
      |> assign(:user, user)
      |> assign(:current_scope, current_scope)
      |> assign(:me_file, me_file)
      |> assign(:active_offers, [])
      |> assign(:loading, true)
      |> assign(:debug, @debug)

    if connected?(socket) do
      send(self(), :load_offers)
      {:ok, socket}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_info(:load_offers, socket) do
    query =
      from(o in Offer,
        where: o.me_file_id == ^socket.assigns.me_file.id and o.is_current == true,
        order_by: [desc: o.offer_amt],
        preload: [media_piece: :ad_category]
      )

    active_offers =
      query
      |> LegacyRepo.all()
      |> Enum.map(fn offer -> {offer, 0} end)

    {:noreply,
     socket
     |> assign(:active_offers, active_offers)
     |> assign(:loading, false)}
  end

  @impl true
  def handle_event("click-offer", %{"offer-id" => offer_id}, socket) do
    offer_id = String.to_integer(offer_id)

    {offer = %Offer{}, phase} =
      Enum.find(socket.assigns.active_offers, &(elem(&1, 0).id == offer_id))

    socket
    |> handle_phase(offer, phase)
    |> noreply()
  end

  defp handle_phase(socket, offer, 0) do
    increment_phase(socket, offer.id)
  end

  defp handle_phase(socket, offer, 1) do
    # Create ad event and update ledger using legacy schemas
    ledger_header = socket.assigns.me_file.ledger_header

    ThreeTap.create_banner_ad_event(offer.id, socket.assigns.user_ip, socket.host_uri.host)
    socket = assign(socket, :current_scope, Map.put(socket.assigns.current_scope, :wallet_balance, Wallets.get_me_file_ledger_header_balance(socket.assigns.me_file)))

    socket
    |> increment_phase(offer.id)
    # |> assign(:current_scope, current_scope)
  end

  defp handle_phase(socket, offer, 2) do
    # Create ad event and update ledger using legacy schemas
    ledger_header = socket.assigns.me_file.ledger_header

    ThreeTap.create_jump_ad_event(offer.id, socket.assigns.user_ip, socket.host_uri.host)
    socket = assign(socket, :current_scope, Map.put(socket.assigns.current_scope, :wallet_balance, Wallets.get_me_file_ledger_header_balance(socket.assigns.me_file)))

    socket
    |> increment_phase(offer.id)
    # |> update_ads_count()
    # |> assign(:current_scope, current_scope)
  end

  defp handle_phase(socket, _offer, _), do: socket

  defp increment_phase(socket, offer_id) do
    Component.update(socket, :active_offers, fn offers ->
      Enum.map(offers, fn {offer, phase} ->
        if offer.id == offer_id do
          {offer, phase + 1}
        else
          {offer, phase}
        end
      end)
    end)
  end

  # Update the badge in the bottom bar
  defp update_ads_count(socket) do
    ads_count =
      from(o in Offer,
        where: o.me_file_id == ^socket.assigns.me_file.id and o.is_current == true
      )
      |> LegacyRepo.aggregate(:count)

    current_scope = Map.put(socket.assigns.current_scope, :ads_count, ads_count)
    assign(socket, :current_scope, current_scope)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.sponster {assigns}>
    <h1 class="text-3xl font-bold mb-4">Ads</h1>
      <div class="container mx-auto px-4 py-8 max-w-3xl">

        <div class="w-fit mx-auto">
          <%= if Enum.any?(@active_offers) do %>
            <div class="space-y-4">
              <.clickable_offer :for={{offer, phase} <- @active_offers} offer={offer} phase={phase} />
            </div>
          <% else %>
            <div class="text-center py-8">
              <p class="text-gray-500">You don't have any ads yet.</p>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Debug section -->
      <pre :if={@debug} class="mt-8 p-4 bg-gray-100 rounded overflow-auto text-sm">
        <%= inspect(assigns, pretty: true) %>
      </pre>
    </Layouts.sponster>
    """
  end
end
