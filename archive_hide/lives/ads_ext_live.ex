defmodule QlariusWeb.AdsExtLive do
  use QlariusWeb, :live_view

  alias Qlarius.Accounts.Users
  alias Qlarius.Sponster.Offers
  alias Qlarius.Repo
  alias Qlarius.Sponster.Offer
  alias Qlarius.YouData
  alias Qlarius.Wallets

  import QlariusWeb.OfferHTML
  import Ecto.Query, except: [update: 2, update: 3]
  import QlariusWeb.Layouts

  on_mount {QlariusWeb.GetUserIP, :assign_ip}

  @debug Mix.env() != :prod

  @impl true
  def mount(params, session, socket) do
    offers =
      socket.assigns.current_scope.user.id
      |> Offers.list_user_offers()
      |> Enum.map(fn offer ->
        # {offer, phase}. Phase is an integer between 0 and 3
        {offer, 0}
      end)

    socket =
      socket
      |> assign(:active_offers, offers)
      |> assign(:loading, true)
      |> assign(:debug, @debug)
      |> assign(:page_title, "Sponster")

    if connected?(socket) do
      send(self(), :load_offers)
      {:ok, socket}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, uri, socket) do
    split_code = Map.get(params, "split_code")
    recipient = Users.get_recipient_by_split_code(split_code)

    socket
    |> assign(:split_code, split_code)
    |> assign(:recipient, recipient)
    |> assign(:host_uri, URI.parse(uri))
    |> noreply()
  end

  @impl true
  def handle_info(:load_offers, socket) do
    me_file = socket.assigns.current_scope.user.me_file

    query =
      from(o in Offer,
        where: o.me_file_id == ^me_file.id and o.is_current == true,
        order_by: [desc: o.amount],
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
    new_balance = Wallets.get_user_current_balance(socket.assigns.current_scope.user)
    current_scope = Map.put(socket.assigns.current_scope, :wallet_balance, new_balance)
    {:noreply, assign(socket, :current_scope, current_scope)}
  end

  @impl true
  def handle_event("set_split", %{"split" => split}, socket) do
    split_amount = String.to_integer(split)
    me_file = socket.assigns.current_scope.user.me_file

    case YouData.update_me_file_split_amount(me_file, split_amount) do
      {:ok, updated_me_file} ->
        {:noreply,
         socket |> assign(me_file: updated_me_file) |> assign(split_amount: split_amount)}

      {:error, _changeset} ->
        {:noreply, socket}
    end
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
          me_file={@current_scope.user.me_file}
          user_ip={@user_ip}
          current_scope={@current_scope}
          host_uri={@host_uri}
          recipient={@recipient}
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
