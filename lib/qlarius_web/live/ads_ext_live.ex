defmodule QlariusWeb.AdsExtLive do
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
  import QlariusWeb.Layouts

  on_mount {QlariusWeb.GetUserIP, :assign_ip}

  @debug false

  @impl true
  def mount(params, session, socket) do
    # Load initial data during first mount
    user = Legacy.get_user(508)
    current_scope = Scope.for_user(user)
    me_file = Legacy.get_user_me_file(current_scope.user.id)

    host_uri =
      case Phoenix.LiveView.get_connect_info(socket, :uri) do
        nil -> URI.parse("http://localhost")
        uri -> uri
      end

    split_code = Map.get(params, "split_code")

    socket =
      socket
      |> assign(:user, user)
      |> assign(:current_scope, current_scope)
      |> assign(:me_file, me_file)
      |> assign(:active_offers, [])
      |> assign(:loading, true)
      |> assign(:debug, @debug)
      |> assign(:host_uri, host_uri)
      |> assign(:split_code, split_code)
      |> assign_new(:recipient_name, fn -> nil end)
      |> assign_new(:recipient_image, fn -> nil end)
      |> assign_new(:recipient_message, fn -> nil end)

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
  def handle_info({:refresh_wallet_balance, me_file_id}, socket) do
    new_balance = Wallets.get_me_file_ledger_header_balance(socket.assigns.me_file)
    current_scope = Map.put(socket.assigns.current_scope, :wallet_balance, new_balance)
    {:noreply, assign(socket, :current_scope, current_scope)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.tipjar_container {assigns}>

      <div class="container mx-auto px-0 py-8 max-w-3xl my-[60px]">
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
      <pre :if={@debug} class="mt-8 p-4 bg-gray-100 rounded overflow-auto text-sm">
        <%= inspect(assigns, pretty: true) %>
      </pre>
    </Layouts.tipjar_container>
    """
  end

  @impl true
  def terminate(_reason, _socket) do
    :ok
  end
end
