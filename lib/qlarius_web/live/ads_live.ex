defmodule QlariusWeb.AdsLive do
  use QlariusWeb, :live_view

  alias Qlarius.Offers

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    offers = if user, do: Offers.list_user_offers(user.id), else: []

    {:ok,
     socket
     |> assign(:page_title, "Ads")
     |> assign(:offers, offers)
     |> assign(:expanded_offer_id, nil)}
  end

  @impl true
  def handle_event("toggle-offer", %{"id" => offer_id}, socket) do
    offer_id = String.to_integer(offer_id)

    expanded_offer_id =
      if socket.assigns.expanded_offer_id == offer_id do
        nil
      else
        offer_id
      end

    {:noreply, assign(socket, :expanded_offer_id, expanded_offer_id)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8 max-w-3xl">
      <h1 class="text-3xl font-bold mb-8 text-center">Ads</h1>

      <div class="space-y-4">
        <%= for offer <- @offers do %>
          <div class="bg-white rounded-lg shadow-md overflow-hidden ad-card w-full">
            <%= if @expanded_offer_id == offer.id do %>
              <div class="p-4">
                <div class="flex justify-between items-center mb-4">
                  <h2 class="text-xl font-semibold">[Ad category]</h2>
                  <button
                    phx-click="toggle-offer"
                    phx-value-id={offer.id}
                    class="text-gray-500 hover:text-gray-700"
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="h-6 w-6"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M6 18L18 6M6 6l12 12"
                      />
                    </svg>
                  </button>
                </div>

                <div class="mb-4">
                  <img
                    src={"/images/banner_#{rem(offer.id, 4)}.png"}
                    alt="Ad image"
                    class="w-full h-auto rounded"
                  />
                </div>

                <div class="ad-detail-row">
                  <span>CLICK FOR</span>
                  <span>${offer.phase_1_amount}</span>
                </div>

                <div class="ad-detail-row">
                  <span>CLICK/JUMP FOR</span>
                  <span>${offer.phase_2_amount}</span>
                </div>
              </div>
            <% else %>
              <div class="p-4 cursor-pointer" phx-click="toggle-offer" phx-value-id={offer.id}>
                <div class="flex justify-between items-center">
                  <h2 class="text-xl font-semibold">[Ad category]</h2>
                  <span class="text-2xl ad-amount">${offer.amount}</span>
                </div>

                <div class="mt-4 text-center">
                  <p class="text-gray-500">Click to view offer details</p>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>

      <%= if @offers == [] do %>
        <div class="text-center py-8">
          <p class="text-gray-500">You don't have any ads yet.</p>
        </div>
      <% end %>
    </div>
    """
  end
end
