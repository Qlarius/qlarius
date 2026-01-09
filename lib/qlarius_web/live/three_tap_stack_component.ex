defmodule QlariusWeb.ThreeTapStackComponent do
  use Phoenix.LiveComponent

  import QlariusWeb.OfferHTML

  alias Qlarius.Sponster.Ads.ThreeTap
  alias Qlarius.YouData.StrongStart
  # Commented out unused alias - Component not directly referenced
  # alias Phoenix.Component
  # Commented out unused import - only used in commented update_ads_count function
  # import Ecto.Query, except: [update: 2, update: 3]

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
            current_scope={@current_scope}
            recipient={Map.get(assigns, :recipient)}
          />
        </div>
      <% else %>
        <.offer_skeleton :for={_ <- 1..6} />
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

  # params map not fully used - only extracting offer-id for now
  @impl true
  def handle_event("click-offer", %{"offer-id" => offer_id} = _params, socket) do
    offer_id = String.to_integer(offer_id)

    # Get recipient from socket.assigns if it exists, default to nil
    recipient = Map.get(socket.assigns, :recipient)

    {offer, phase} = Enum.find(socket.assigns.active_offers, fn {o, _p} -> o.id == offer_id end)

    # Get split_amount from current_scope if available, or default to 0
    split_amount =
      (socket.assigns.current_scope.user.me_file &&
         socket.assigns.current_scope.user.me_file.split_amount) || 0

    handle_phase(socket, offer, phase, recipient, split_amount)
  end

  defp handle_phase(socket, offer, 0, _recipient, _split_amount) do
    increment_phase(socket, offer.id)
  end

  defp handle_phase(socket, offer, 1, recipient, split_amount) do
    ThreeTap.create_banner_ad_event(
      offer,
      recipient,
      split_amount,
      socket.assigns.user_ip,
      socket.assigns.host_uri.host
    )

    me_file = socket.assigns.current_scope.user.me_file
    StrongStart.mark_step_complete(me_file, "first_ad_interacted")

    send(self(), {:refresh_wallet_balance, socket.assigns.current_scope.user.me_file.id})
    increment_phase(socket, offer.id)
  end

  defp handle_phase(socket, offer, 2, recipient, split_amount) do
    ThreeTap.create_jump_ad_event(
      offer,
      recipient,
      split_amount,
      socket.assigns.user_ip,
      socket.assigns.host_uri.host
    )

    send(self(), {:refresh_wallet_balance, socket.assigns.current_scope.user.me_file.id})
    increment_phase(socket, offer.id)
  end

  defp handle_phase(socket, _offer, _, _recipient, _split_amount), do: {:noreply, socket}

  defp increment_phase(socket, offer_id) do
    new_offers =
      Enum.map(socket.assigns.active_offers, fn {offer, phase} ->
        if offer.id == offer_id, do: {offer, phase + 1}, else: {offer, phase}
      end)

    {:noreply, assign(socket, :active_offers, new_offers)}
  end

  # Commented out unused function - not called anywhere in the codebase
  # defp update_ads_count(socket) do
  #   ads_count =
  #     from(o in Offer,
  #       where:
  #         o.me_file_id == ^socket.assigns.current_scope.user.me_file.id and o.is_current == true
  #     )
  #     |> Repo.aggregate(:count)

  #   current_scope = Map.put(socket.assigns.current_scope, :ads_count, ads_count)
  #   assign(socket, :current_scope, current_scope)
  # end
end
