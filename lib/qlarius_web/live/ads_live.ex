defmodule QlariusWeb.AdsLive do
  use QlariusWeb, :live_view

  alias Qlarius.Legacy
  alias Qlarius.Legacy.{MeFile, Offer, User, LedgerHeader, AdEvent, LedgerEntry}
  alias Qlarius.LegacyRepo
  alias Qlarius.Accounts.Scope
  alias Phoenix.Component

  import QlariusWeb.OfferHTML
  import Ecto.Query, except: [update: 2, update: 3]

  on_mount {QlariusWeb.GetUserIP, :assign_ip}

  @debug true

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      # For WebSocket mount, we need to fetch the user and scope again
      user = Legacy.get_user(508)
      current_scope = Scope.for_user(user)

      # Get the user's me_file to count their offers
      me_file = Legacy.get_user_me_file(user.id)
      ads_count =
        from(o in Offer,
          where: o.me_file_id == ^me_file.id and o.is_current == true
        )
        |> LegacyRepo.aggregate(:count)

      current_scope =
        current_scope
        |> Map.put(:ads_count, ads_count)

      query =
        from(o in Offer,
          join: m in MeFile,
          on: m.user_id == ^current_scope.user.id,
          where: o.me_file_id == m.id and o.is_current == true,
          order_by: [desc: o.offer_amt],
          preload: [media_piece: :ad_category]
        )

      active_offers =
        query
        |> LegacyRepo.all()
        |> Enum.map(fn offer -> {offer, 0} end)

      {:ok,
       socket
       |> assign(:current_scope, current_scope)
       |> assign(:active_offers, active_offers)
       |> assign(:debug, @debug)}
    else
      # Create a default scope with mock data for the initial render
      default_scope = %{
        ads_count: 0,
        wallet_balance: Decimal.new(0),
        home_zip: "NO ZIP",
        user: %{
          email: "Loading...",
          id: nil
        }
      }

      {:ok,
       socket
       |> assign(:current_scope, default_scope)
       |> assign(:active_offers, [])
       |> assign(:debug, @debug)}
    end
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
    me_file = Legacy.get_user_me_file(socket.assigns.current_scope.user.id)
    ledger_header = me_file.ledger_header

    # Create ad event
    ad_event = %AdEvent{
      offer_id: offer.id,
      offer_amount: offer.offer_amt,
      is_throttled: offer.is_throttled,
      is_offer_complete: false,
      ip_address: socket.assigns.user_ip
    }
    |> LegacyRepo.insert!()

    # Update ledger header balance
    new_balance = Decimal.add(ledger_header.balance || Decimal.new(0), Decimal.new("0.05"))

    ledger_header
    |> Ecto.Changeset.change(balance: new_balance)
    |> LegacyRepo.update!()

    # Create ledger entry
    %LedgerEntry{
      ledger_header_id: ledger_header.id,
      amount: Decimal.new("0.05"),
      running_balance: new_balance,
      description: "Ad view payment",
      ad_event_id: ad_event.id
    }
    |> LegacyRepo.insert!()

    # Update the scope with the new balance
    current_scope = Map.put(socket.assigns.current_scope, :wallet_balance, new_balance)

    socket
    |> increment_phase(offer.id)
    |> assign(:current_scope, current_scope)
  end

  defp handle_phase(socket, offer, 2) do
    # Create ad event and update ledger using legacy schemas
    me_file = Legacy.get_user_me_file(socket.assigns.current_scope.user.id)
    ledger_header = me_file.ledger_header

    # Create ad event
    ad_event = %AdEvent{
      offer_id: offer.id,
      offer_amount: offer.offer_amt,
      is_throttled: offer.is_throttled,
      is_offer_complete: true,
      ip_address: socket.assigns.user_ip,
      url: offer.media_piece.jump_url
    }
    |> LegacyRepo.insert!()

    # Calculate jump payment (full offer amount minus initial view payment)
    jump_amount = Decimal.sub(offer.offer_amt, Decimal.new("0.05"))
    new_balance = Decimal.add(ledger_header.balance || Decimal.new(0), jump_amount)

    ledger_header
    |> Ecto.Changeset.change(balance: new_balance)
    |> LegacyRepo.update!()

    # Create ledger entry
    %LedgerEntry{
      ledger_header_id: ledger_header.id,
      amount: jump_amount,
      running_balance: new_balance,
      description: "Ad jump payment",
      ad_event_id: ad_event.id
    }
    |> LegacyRepo.insert!()

    # Update the scope with the new balance
    current_scope = Map.put(socket.assigns.current_scope, :wallet_balance, new_balance)

    socket
    |> increment_phase(offer.id)
    |> update_ads_count()
    |> assign(:current_scope, current_scope)
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
    me_file = Legacy.get_user_me_file(socket.assigns.current_scope.user.id)
    ads_count =
      from(o in Offer,
        where: o.me_file_id == ^me_file.id and o.is_current == true
      )
      |> LegacyRepo.aggregate(:count)

    current_scope = Map.put(socket.assigns.current_scope, :ads_count, ads_count)
    assign(socket, :current_scope, current_scope)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.sponster {assigns}>
      <div class="container mx-auto px-4 py-8 max-w-3xl">
        <h1 class="text-3xl font-bold mb-8 text-center">Ads</h1>

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
