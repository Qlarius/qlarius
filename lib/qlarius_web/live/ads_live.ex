defmodule QlariusWeb.AdsLive do
  use QlariusWeb, :live_view

  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.Sponster.Offer
  alias Qlarius.Accounts.Users
  alias Qlarius.Accounts.User
  alias Qlarius.Wallets.{LedgerHeader, LedgerEntry}
  alias Qlarius.Sponster.AdEvent
  alias Qlarius.Repo
  alias Qlarius.Accounts.Scope
  alias Qlarius.Sponster.Ads.{ThreeTap, MediaPiece, AdCategory}
  alias Phoenix.Component
  alias Qlarius.Wallets.Wallets
  import QlariusWeb.OfferHTML
  import Ecto.Query, except: [update: 2, update: 3]

  on_mount {QlariusWeb.GetUserIP, :assign_ip}

  @debug false

  @impl true
  def mount(_params, session, socket) do
    # Load initial data during first mount
    user = Users.get_user(508)
    current_scope = Scope.for_user(user)
    me_file = Users.get_user_me_file(current_scope.user.id)

    host_uri =
      case Phoenix.LiveView.get_connect_info(socket, :uri) do
        nil -> URI.parse("http://localhost")
        uri -> uri
      end

    socket =
      socket
      |> assign(:user, user)
      |> assign(:current_scope, current_scope)
      |> assign(:me_file, me_file)
      |> assign(:active_offers, [])
      |> assign(:loading, true)
      |> assign(:debug, @debug)
      |> assign(:host_uri, host_uri)

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
      |> Repo.all()
      |> Enum.map(fn offer -> {offer, 0} end)

    {:noreply,
     socket
     |> assign(:active_offers, active_offers)
     |> assign(:loading, false)}
  end

  @impl true
  def handle_info({:refresh_wallet_balance, me_file_id}, socket) do
    new_balance = Wallets.get_me_file_ledger_header_balance(socket.assigns.me_file)
    current_scope = Map.put(socket.assigns.current_scope, :wallet_balance, new_balance)
    {:noreply, assign(socket, :current_scope, current_scope)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.sponster {assigns}>
      <h1 class="text-3xl font-bold mb-4">Ads</h1>
      <div class="container mx-auto px-4 py-8 max-w-3xl">
        <%!-- <div class="w-fit mx-auto">
          <%= if Enum.any?(@active_offers) do %>
            <div class="space-y-4">
              <.clickable_offer :for={{offer, phase} <- @active_offers} offer={offer} phase={phase} />
            </div>
          <% else %>
            <div class="text-center py-8">
              <p class="text-gray-500">You don't have any ads yet.</p>
            </div>
          <% end %>
        </div> --%>

        <.live_component
          module={QlariusWeb.ThreeTapStackComponent}
          id="three-tap-stack"
          active_offers={@active_offers}
          me_file={@me_file}
          user_ip={@user_ip}
          current_scope={@current_scope}
          host_uri={@host_uri}
        />
      </div>

    <!-- Debug section -->
      <pre :if={@debug} class="mt-8 p-4 bg-gray-100 rounded overflow-auto text-sm">
        <%= inspect(assigns, pretty: true) %>
      </pre>
    </Layouts.sponster>
    """
  end

  @impl true
  def terminate(reason, socket) do
    :ok
  end
end
