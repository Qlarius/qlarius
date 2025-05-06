defmodule QlariusWeb.ThreeTapStackComponent do
  use Phoenix.LiveComponent

  import QlariusWeb.OfferHTML

  alias Qlarius.Ads.ThreeTap
  alias Qlarius.Legacy.Offer
  alias Qlarius.LegacyRepo
  alias Qlarius.Wallets
  alias Phoenix.Component
  import Ecto.Query, except: [update: 2, update: 3]
  import Logger

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-fit mx-auto">
      <%= if Enum.any?(@active_offers) do %>
        <div class="space-y-4">
          <.clickable_offer
            :for={{offer, phase} <- @active_offers}
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

  @impl true
  def update(%{active_offers: new_offers} = assigns, socket) do
    old_offers = Map.get(socket.assigns, :active_offers, [])
    old_ids = Enum.map(old_offers, fn {offer, _phase} -> offer.id end)
    new_ids = Enum.map(new_offers, fn {offer, _phase} -> offer.id end)

    active_offers =
      if old_ids == new_ids do
        # Keep local phase state
        old_offers
      else
        # New offers, reset phases
        Enum.map(new_offers, fn {offer, _} -> {offer, 0} end)
      end

    {:ok, assign(socket, assigns) |> assign(:active_offers, active_offers)}
  end

  @impl true
  def handle_event("click-offer", %{"offer-id" => offer_id}, socket) do
    offer_id = String.to_integer(offer_id)
    {offer, phase} = Enum.find(socket.assigns.active_offers, fn {o, _p} -> o.id == offer_id end)
    handle_phase(socket, offer, phase)
  end

  defp handle_phase(socket, offer, 0) do
    increment_phase(socket, offer.id)
  end

  defp handle_phase(socket, offer, 1) do
    ThreeTap.create_banner_ad_event(
      offer.id,
      socket.assigns.user_ip,
      socket.assigns.host_uri.host
    )

    send(self(), {:refresh_wallet_balance, socket.assigns.me_file.id})

    Logger.info(
      "ThreeTapStackComponent: Sent :refresh_wallet_balance after phase 1 for offer #{offer.id}"
    )

    increment_phase(socket, offer.id)
  end

  defp handle_phase(socket, offer, 2) do
    ThreeTap.create_jump_ad_event(offer.id, socket.assigns.user_ip, socket.assigns.host_uri.host)
    send(self(), {:refresh_wallet_balance, socket.assigns.me_file.id})

    Logger.info(
      "ThreeTapStackComponent: Sent :refresh_wallet_balance after phase 2 for offer #{offer.id}"
    )

    increment_phase(socket, offer.id)
  end

  defp handle_phase(socket, _offer, _), do: {:noreply, socket}

  defp increment_phase(socket, offer_id) do
    new_offers =
      Enum.map(socket.assigns.active_offers, fn {offer, phase} ->
        if offer.id == offer_id, do: {offer, phase + 1}, else: {offer, phase}
      end)

    {:noreply, assign(socket, :active_offers, new_offers)}
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
