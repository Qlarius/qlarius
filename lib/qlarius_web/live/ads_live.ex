defmodule QlariusWeb.AdsLive do
  use QlariusWeb, :sponster_live_view

  alias Qlarius.Offer
  alias Qlarius.Offers
  alias Qlarius.Wallets

  import QlariusWeb.OfferHTML

  on_mount {QlariusWeb.GetUserIP, :assign_ip}

  @impl true
  def mount(_params, _session, socket) do
    offers =
      socket.assigns.current_user.id
      |> Offers.list_user_offers()
      |> Enum.map(fn offer ->
        # {offer, phase}. Phase is an integer between 0 and 3
        {offer, 0}
      end)

    socket
    |> assign(:page_title, "Ads")
    |> assign(:offers, offers)
    |> ok()
  end

  @impl true
  def handle_event("click-offer", %{"offer-id" => offer_id}, socket) do
    offer_id = String.to_integer(offer_id)

    {offer = %Offer{}, phase} =
      Enum.find(socket.assigns.offers, &(elem(&1, 0).id == offer_id))

    socket
    |> handle_phase(offer, phase)
    |> noreply()
  end

  defp handle_phase(socket, offer, 0) do
    increment_phase(socket, offer.id)
  end

  defp handle_phase(socket, offer, 1) do
    :ok =
      Wallets.create_ad_event_and_update_ledger(
        offer,
        socket.assigns.current_user,
        socket.assigns.user_ip
      )

    balance = Wallets.get_user_current_balance(socket.assigns.current_user)

    socket
    |> increment_phase(offer.id)
    |> assign(:wallet_balance, balance)
  end

  defp handle_phase(socket, offer, 2) do
    :ok =
      Wallets.create_ad_jump_event_and_update_ledger(
        offer,
        socket.assigns.current_user,
        socket.assigns.user_ip
      )

    balance = Wallets.get_user_current_balance(socket.assigns.current_user)

    socket
    |> increment_phase(offer.id)
    |> update_ads_count()
    |> assign(:wallet_balance, balance)
  end

  defp handle_phase(socket, _offer, _), do: socket

  defp increment_phase(socket, offer_id) do
    update(socket, :offers, fn offers ->
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
    assign(
      socket,
      :ads_count,
      Offers.count_user_offers(socket.assigns.current_user.id)
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8 max-w-3xl">
      <h1 class="text-3xl font-bold mb-8 text-center">Ads</h1>

      <div class="w-fit mx-auto">
        <%= if Enum.any?(@offers) do %>
          <div class="space-y-4">
            <.clickable_offer :for={{offer, phase} <- @offers} offer={offer} phase={phase} />
          </div>
        <% else %>
          <div class="text-center py-8">
            <p class="text-gray-500">You don't have any ads yet.</p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
