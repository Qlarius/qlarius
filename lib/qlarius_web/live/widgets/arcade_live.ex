defmodule QlariusWeb.Widgets.ArcadeLive do
  use QlariusWeb, :live_view

  alias Qlarius.Tiqit.Arcade
  alias Qlarius.Tiqit.Arcade.ContentGroup
  alias Qlarius.Tiqit.Arcade.ContentPiece
  alias Qlarius.Tiqit.Arcade.TiqitClass
  alias Qlarius.Wallets.Wallets

  import QlariusWeb.Money
  import QlariusWeb.TiqitClassHTML

  def mount(%{"group_id" => group_id}, _session, socket) do
    scope = socket.assigns.current_scope

    group = Arcade.get_content_group!(group_id)
    pieces = Enum.filter(group.content_pieces, &Enum.any?(&1.tiqit_classes))

    Phoenix.PubSub.subscribe(Qlarius.PubSub, "wallet:#{scope.user.id}")

    socket
    |> assign(
      balance: scope && scope.wallet_balance,
      group: group,
      pieces: pieces,
      selected_tiqit_class: nil
    )
    |> ok()
  end

  def handle_params(params, _uri, socket) do
    pieces = socket.assigns.pieces

    selected_piece =
      with {:ok, content_id} <- Map.fetch(params, "content_id"),
           content_id = String.to_integer(content_id),
           content = %ContentPiece{} <- Enum.find(pieces, &(&1.id == content_id)) do
        content
      else
        _ ->
          List.first(pieces)
      end

    default_tiqit_class =
      if selected_piece do
        ContentPiece.default_tiqit_class(selected_piece)
      else
        nil
      end

    socket
    |> assign(selected_piece: selected_piece)
    |> assign(default_tiqit_class: default_tiqit_class)
    |> noreply()
  end

  attr :balance, Decimal, required: true
  attr :piece, ContentPiece, required: true
  attr :group, ContentGroup, required: true

  defp tiqit_class_grid(assigns) do
    piece = assigns.piece
    group = assigns.group
    catalog = group.catalog

    durations =
      [piece, group, catalog]
      |> Enum.flat_map(&for tc <- &1.tiqit_classes, do: tc.duration_hours)
      |> Enum.uniq()
      |> Enum.sort()

    assigns =
      assign(assigns,
        catalog: catalog,
        durations: durations,
        group: group,
        piece: piece,
        show_group?: Enum.any?(group.tiqit_classes),
        show_catalog?: Enum.any?(catalog.tiqit_classes)
      )

    ~H"""
    <table class="w-full text-sm text-center border-separate border-spacing-y-4">
      <thead>
        <tr>
          <th></th>
          <th>{@catalog.piece_type |> to_string() |> String.capitalize()}</th>
          <th :if={@show_group?}>{@catalog.group_type |> to_string() |> String.capitalize()}</th>
          <th :if={@show_catalog?}>{@catalog.type |> to_string() |> String.capitalize()}</th>
        </tr>
      </thead>
      <tbody>
        <tr :for={duration <- @durations}>
          <td>{format_tiqit_class_duration(duration)}</td>
          <%= for {col, true} <- [{@piece, true}, {@group, @show_group?}, {@catalog, @show_catalog?}] do %>
            <td>
              <%= if class = Enum.find(col.tiqit_classes, & &1.duration_hours == duration) do %>
                <.tiqit_class_grid_price balance={@balance} tiqit_class={class} />
              <% end %>
            </td>
          <% end %>
        </tr>
      </tbody>
    </table>
    """
  end

  attr :tiqit_class, TiqitClass, required: true
  attr :balance, Decimal, required: true

  defp tiqit_class_grid_price(assigns) do
    ~H"""
    <%= if Decimal.compare(@balance, @tiqit_class.price) != :lt do %>
      <button
        phx-click="select-tiqit-class"
        phx-value-tiqit-class-id={@tiqit_class.id}
        class="bg-gray-300 px-3 py-1 rounded text-sm font-medium hover:bg-gray-400 cursor-pointer"
      >
        {format_usd(@tiqit_class.price)}
      </button>
    <% else %>
      <div class="bg-gray-100 px-3 py-1 rounded text-sm font-medium text-gray-800 line-through">
        {format_usd(@tiqit_class.price)}
      </div>
    <% end %>
    """
  end

  attr :balance, Decimal

  defp wallet_buttons(assigns) do
    ~H"""
    <div class="flex items-center space-x-2 flex-1">
      <span
        class="bg-green-100 text-green-800 border border-green-800 py-1 px-2 rounded flex items-center text-sm hover:bg-green-200 cursor-pointer"
        phx-click="show-topup-modal"
      >
        <.icon name="hero-wallet" class="w-4 h-4 mr-1" /> Balance: {format_usd(@balance)}
      </span>
      <button
        class="cursor-pointer bg-green-100 h-7 w-7 rounded-full hover:bg-green-200 text-green-800 border border-green-800"
        phx-click="show-topup-modal"
      >
        <.icon name="hero-plus" class="w-4 h-4 relative bottom-px" />
      </button>
    </div>
    """
  end

  def handle_event("close-confirm-purchase-modal", _params, socket) do
    socket |> assign(selected_tiqit_class: nil) |> noreply()
  end

  def handle_event("close-topup-modal", _params, socket) do
    socket |> assign(:show_topup_modal, false) |> noreply()
  end

  def handle_event("hide-options", _params, socket) do
    socket |> assign(:options_modal, false) |> noreply()
  end

  def handle_event("select-tiqit-class", %{"tiqit-class-id" => tc_id}, socket) do
    tc =
      %TiqitClass{} =
      Arcade.get_tiqit_class_for_piece!(
        tc_id,
        socket.assigns.selected_piece,
        socket.assigns.group
      )

    socket |> assign(selected_tiqit_class: tc, options_modal: false) |> noreply()
  end

  def handle_event("show-topup-modal", _params, socket) do
    socket |> assign(:show_topup_modal, true) |> noreply()
  end

  def handle_event("show-options", _params, socket) do
    socket |> assign(:options_modal, true) |> noreply()
  end

  def handle_event("topup", _params, socket) do
    user = socket.assigns.current_scope.user

    Wallets.fake_topup(user)

    Phoenix.PubSub.broadcast(Qlarius.PubSub, "wallet:#{user.id}", :update_balance)

    socket |> assign(:show_topup_modal, false) |> noreply()
  end

  def handle_event("purchase-tiqit", %{"tiqit-class-id" => tiqit_class_id}, socket) do
    tiqit_class =
      Arcade.get_tiqit_class_for_piece!(
        tiqit_class_id,
        socket.assigns.selected_piece,
        socket.assigns.group
      )

    :ok = Arcade.purchase_tiqit(socket.assigns.current_scope, tiqit_class)

    user = socket.assigns.current_scope.user

    Phoenix.PubSub.broadcast(Qlarius.PubSub, "wallet:#{user.id}", :update_balance)

    socket
    |> redirect(to: ~p"/widgets/content/#{socket.assigns.selected_piece.id}")
    |> noreply()
  end

  def handle_info(:update_balance, socket) do
    user = socket.assigns.current_scope.user
    balance = Wallets.get_user_current_balance(user)
    {:noreply, assign(socket, balance: balance)}
  end

  defp class_type(tiqit_class, catalog) do
    cond do
      tiqit_class.content_piece_id -> catalog.piece_type
      tiqit_class.content_group_id -> catalog.group_type
      tiqit_class.catalog.id -> catalog.type
    end
  end
end
