defmodule QlariusWeb.Widgets.ArcadeLive do
  use QlariusWeb, :live_view

  alias Qlarius.Tiqit.Arcade
  alias Qlarius.Tiqit.Arcade.ContentPiece
  alias Qlarius.Tiqit.Arcade.TiqitClass
  alias Qlarius.Wallets.Wallets

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

  defp format_usd(decimal) do
    "$#{Decimal.round(decimal, 2)}"
  end

  attr :balance, Decimal

  def wallet_buttons(assigns) do
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

  defp tiqit_class_duration(%TiqitClass{} = tt) do
    # Returns duration as:
    # - "X weeks" if evenly divisible by 7 days (168 hours)
    # - "X days" if evenly divisible by 24 hours (exception: "24 hours" not "1 day")
    # - "X hours" otherwise
    # Examples: "2 weeks", "3 days", "26 hours"
    if tt.duration_hours do
      duration =
        cond do
          rem(tt.duration_hours, 24 * 7) == 0 ->
            "#{div(tt.duration_hours, 24 * 7)} week#{if div(tt.duration_hours, 24 * 7) > 1, do: "s"}"

          rem(tt.duration_hours, 24) == 0 and tt.duration_hours != 24 ->
            "#{div(tt.duration_hours, 24)} day#{if div(tt.duration_hours, 24) > 1, do: "s"}"

          true ->
            "#{tt.duration_hours} hour#{if tt.duration_hours > 1, do: "s"}"
        end

      "You are purchasing access for #{duration}"
    else
      "You are purchasing lifetime access"
    end
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

  def handle_event("select-tiqit-class", %{"tiqit-class-id" => tt_id}, socket) do
    id = String.to_integer(tt_id)
    tt = %TiqitClass{} = Enum.find(socket.assigns.selected_piece.tiqit_classes, &(&1.id == id))
    socket |> assign(selected_tiqit_class: tt, options_modal: false) |> noreply()
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
    tiqit_class_id = String.to_integer(tiqit_class_id)

    tiqit_class =
      Enum.find(socket.assigns.selected_piece.tiqit_classes, &(&1.id == tiqit_class_id))

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
end
