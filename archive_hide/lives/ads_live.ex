defmodule QlariusWeb.AdsLive do
  use QlariusWeb, :live_view

  alias Qlarius.Accounts
  alias Qlarius.Accounts.Scope
  alias Qlarius.Sponster.Offer
  alias Qlarius.Offers
  alias Qlarius.Wallets

  on_mount {QlariusWeb.GetUserIP, :assign_ip}

  @impl true
  def mount(_params, _session, socket) do
    offers =
      socket.assigns.current_scope.user.id
      |> Offers.list_user_offers()
      |> Enum.map(fn offer ->
        # {offer, phase}. Phase is an integer between 0 and 3
        {offer, 0}
      end)

    socket
    |> assign(:page_title, "Ads")
    |> assign(:offers, offers)
    |> assign(:debug, true)
    |> ok()
  end

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, :host_uri, URI.parse(uri))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.sponster {assigns}>
      <div class="container mx-auto px-4 py-8 max-w-3xl">
        <h1 class="text-3xl font-bold mb-8 text-center">Ads</h1>

        <div class="w-fit mx-auto">
          <.live_component
            module={QlariusWeb.ThreeTapStackComponent}
            id="three-tap-stack"
            active_offers={@offers}
            me_file={@current_scope.user.me_file}
            user_ip={@user_ip}
            current_scope={@current_scope}
            host_uri={@host_uri}
          />
        </div>
      </div>
    </Layouts.sponster>
    """
  end
end
