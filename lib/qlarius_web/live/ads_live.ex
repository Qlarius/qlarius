defmodule QlariusWeb.AdsLive do
  use QlariusWeb, :live_view

  alias Qlarius.Offers

  import QlariusWeb.OfferHTML

  @impl true
  def mount(_params, _session, socket) do
    offers =
      socket.assigns.current_user.id
      |> Offers.list_user_offers()
      |> Enum.map(fn offer ->
        # {offer, phase}
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

    # TODO on click phase 1, create the AdEvent etc.
    # TODO on click phase 2, create another AdEvent and redirect page

    socket
    |> update(:offers, fn offers ->
      Enum.map(offers, fn {offer, phase} ->
        if offer.id == offer_id && phase < 3 do
          handle_phase(offer, phase)
          {offer, phase + 1}
        else
          {offer, phase}
        end
      end)
    end)
    |> noreply()
  end

  defp handle_phase(_offer, 0), do: :noop

  defp handle_phase(_offer, 1) do
    # TODO create AdEvent etc
  end

  defp handle_phase(_offer, 2) do
    # TODO create AdEvent etc
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8 max-w-3xl">
      <h1 class="text-3xl font-bold mb-8 text-center">Ads</h1>

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
    """
  end
end
