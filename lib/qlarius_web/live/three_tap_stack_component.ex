defmodule QlariusWeb.ThreeTapStackComponent do
  @moduledoc """
  LiveComponent for displaying a stack of 3-tap ad offers.

  Accepts `force_light` assign and passes through to child offer components.
  See docs/embedded_theming.md for force_light/pub_theme strategy.
  """
  use Phoenix.LiveComponent

  import QlariusWeb.OfferHTML

  alias Qlarius.Sponster.Ads.ThreeTap
  alias Qlarius.YouData.StrongStart
  alias QlariusWeb.WalletBalanceSync
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
            tip_only={Map.get(assigns, :tip_only, false)}
            force_light={Map.get(assigns, :force_light, false)}
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
    refresh_gen = Map.get(assigns, :offers_refresh_gen, 0)
    prev_refresh_gen = Map.get(socket.assigns, :offers_refresh_gen, 0)
    force_reset? = refresh_gen != prev_refresh_gen

    old_offers = Map.get(socket.assigns, :active_offers, [])
    old_ids = Enum.map(old_offers, fn {offer, _phase} -> offer.id end)
    new_ids = Enum.map(new_offers, fn {offer, _phase} -> offer.id end)

    active_offers =
      cond do
        force_reset? ->
          # Explicit Refresh: always restart at the banner (never mid-funnel).
          Enum.map(new_offers, fn {offer, _} -> {offer, 0} end)

        old_ids == new_ids ->
          # Keep in-session phase progress across unrelated parent re-renders.
          phases = Map.new(old_offers, fn {offer, phase} -> {offer.id, phase} end)

          Enum.map(new_offers, fn {offer, _} ->
            {offer, Map.get(phases, offer.id, 0)}
          end)

        true ->
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

    # Tiqit pages pass tip_only: true — no AutoSplit on ad collections (InstaTip remains).
    split_amount =
      if Map.get(socket.assigns, :tip_only, false),
        do: 0,
        else:
          (socket.assigns.current_scope.user.me_file &&
             socket.assigns.current_scope.user.me_file.split_amount) || 0

    handle_phase(socket, offer, phase, recipient, split_amount)
  end

  defp handle_phase(socket, offer, 0, _recipient, _split_amount) do
    increment_phase(socket, offer.id)
  end

  defp handle_phase(socket, offer, 1, recipient, split_amount) do
    result =
      ThreeTap.create_banner_ad_event(
        offer,
        recipient,
        split_amount,
        socket.assigns.user_ip,
        socket.assigns.host_uri.host
      )

    me_file = socket.assigns.current_scope.user.me_file
    StrongStart.mark_step_complete(me_file, "first_ad_interacted")

    # Banner collect runs in a LiveComponent on the parent LV; push an immediate
    # refresh so the announcer footer updates even if me_file PubSub was missed.
    socket = WalletBalanceSync.sync_host_after_ad_collection(socket)

    case result do
      {:ok, _} -> increment_phase(socket, offer.id)
      {:error, _} -> increment_phase(socket, offer.id)
    end
  end

  defp handle_phase(socket, offer, 2, _recipient, _split_amount) do
    # Phase 2 click only increments the phase to show "Attention Paid" UI
    # The actual payment and ad event creation happens in the jump page controller
    # when the advertiser's page successfully loads
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
