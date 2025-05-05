defmodule QlariusWeb.ThreeTapStackComponent do
  use Phoenix.LiveComponent

  import QlariusWeb.OfferHTML

  alias Qlarius.Ads.ThreeTap
  alias Qlarius.Legacy.Offer
  alias Qlarius.LegacyRepo
  alias Qlarius.Wallets
  alias Phoenix.Component
  import Ecto.Query, except: [update: 2, update: 3]

  def render(assigns) do
    ~H"""
    <div class="w-fit mx-auto">
      <%= if Enum.any?(@active_offers) do %>
        <div class="space-y-4">
          <.clickable_offer :for={{offer, phase} <- @active_offers}
            offer={offer}
            phase={phase}
            target={@myself}
          />
        </div>
      <% else %>
        <div class="text-center py-8">
          <p class="text-gray-500">You don't have any ads yet.</p>
        </div>
      <% end %>
    </div>
    """
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  def handle_event("click-offer", %{"offer-id" => offer_id}, socket) do
    offer_id = String.to_integer(offer_id)
    {offer, phase} = Enum.find(socket.assigns.active_offers, &(elem(&1, 0).id == offer_id))
    socket = handle_phase(socket, offer, phase)
    {:noreply, socket}
  end

  defp handle_phase(socket, offer, 0) do
    increment_phase(socket, offer.id)
  end

  defp handle_phase(socket, offer, 1) do
    # Create ad event and update ledger using legacy schemas
    ledger_header = socket.assigns.me_file.ledger_header
    ThreeTap.create_banner_ad_event(offer.id, socket.assigns.user_ip, socket.assigns.host_uri.host)
    socket = assign(socket, :current_scope, Map.put(socket.assigns.current_scope, :wallet_balance, Wallets.get_me_file_ledger_header_balance(socket.assigns.me_file)))
    socket |> increment_phase(offer.id)
  end

  defp handle_phase(socket, offer, 2) do
    # Create ad event and update ledger using legacy schemas
    ledger_header = socket.assigns.me_file.ledger_header
    ThreeTap.create_jump_ad_event(offer.id, socket.assigns.user_ip, socket.assigns.host_uri.host)
    socket = assign(socket, :current_scope, Map.put(socket.assigns.current_scope, :wallet_balance, Wallets.get_me_file_ledger_header_balance(socket.assigns.me_file)))
    socket |> increment_phase(offer.id)
  end

  defp handle_phase(socket, _offer, _), do: socket

  defp increment_phase(socket, offer_id) do
    active_offers = Enum.map(socket.assigns.active_offers, fn {offer, phase} ->
      if offer.id == offer_id do
        {offer, phase + 1}
      else
        {offer, phase}
      end
    end)
    assign(socket, :active_offers, active_offers)
  end

  defp update_ads_count(socket) do
    ads_count =
      from(o in Offer,
        where: o.me_file_id == ^socket.assigns.me_file.id and o.is_current == true
      )
      |> LegacyRepo.aggregate(:count)

    current_scope = Map.put(socket.assigns.current_scope, :ads_count, ads_count)
    assign(socket, :current_scope, current_scope)
  end
end
