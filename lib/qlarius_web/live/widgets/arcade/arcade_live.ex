defmodule QlariusWeb.Widgets.Arcade.ArcadeLive do
  use QlariusWeb, :live_view

  alias Qlarius.Tiqit.Arcade.Arcade
  alias Qlarius.Tiqit.Arcade.ContentPiece
  alias Qlarius.Tiqit.Arcade.TiqitClass
  alias Qlarius.Wallets

  import QlariusWeb.Money
  import QlariusWeb.TiqitClassHTML
  import QlariusWeb.Components.CustomComponentsMobile
  import QlariusWeb.Widgets.Arcade.Components

  def mount(%{"group_id" => group_id} = params, _session, socket) do
    # Prevent double mounting - only initialize if not already mounted
    if connected?(socket) and socket.assigns[:mounted] do
      # Already mounted, just update balance and return
      scope = socket.assigns.current_scope

      {:ok,
       socket
       |> assign(
         balance: scope && scope.wallet_balance,
         offered_amount: scope && scope.offered_amount
       )}
    else
      # First mount - do full initialization
      scope = socket.assigns.current_scope

      # Load data once
      group = Arcade.get_content_group!(group_id)

      pieces =
        group.content_pieces
        |> Enum.filter(&Enum.any?(&1.tiqit_classes))
        # Sort by ID to ensure consistent order; change to proper display order later
        |> Enum.sort_by(& &1.id)

      # Generate random durations only once per piece (cache them)
      pieces =
        Enum.map(pieces, fn piece ->
          # Use piece ID as seed for consistent but random durations
          :rand.seed(:exsplus, {piece.id, piece.id, piece.id})
          # 19..32 range
          hours = :rand.uniform(14) + 18
          # 1..59 range
          minutes = :rand.uniform(59) + 1
          duration = :io_lib.format("~2..0B min ~2..0B sec", [hours, minutes])
          Map.put(piece, :duration, duration)
        end)

      # Subscribe to wallet updates only once
      Phoenix.PubSub.subscribe(Qlarius.PubSub, "wallet:#{scope.user.id}")

      force_theme = Map.get(params, "force_theme")

      {:ok,
       socket
       |> assign(
         mounted: true,
         balance: scope && scope.wallet_balance,
         offered_amount: scope && scope.offered_amount,
         group: group,
         pieces: pieces,
         selected_tiqit_class: nil,
         force_theme: force_theme
       )}
    end
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

    tiqit =
      if selected_piece do
        Arcade.get_valid_tiqit(socket.assigns.current_scope, selected_piece)
      else
        nil
      end

    force_theme = Map.get(params, "force_theme")

    socket
    |> assign(selected_piece: selected_piece)
    |> assign(default_tiqit_class: default_tiqit_class)
    |> assign(tiqit: tiqit)
    |> assign(force_theme: force_theme)
    |> noreply()
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

    # socket |> assign(:show_topup_modal, false) |> noreply()
    socket |> noreply()
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
    # Only update if mounted to prevent race conditions
    if socket.assigns[:mounted] do
      user = socket.assigns.current_scope.user
      scope = socket.assigns.current_scope

      # Only fetch balance if user exists
      balance = if user, do: Wallets.get_user_current_balance(user), else: socket.assigns.balance

      {:noreply,
       assign(socket,
         balance: balance,
         offered_amount: scope && scope.offered_amount
       )}
    else
      {:noreply, socket}
    end
  end

  defp class_type(tiqit_class, catalog) do
    cond do
      tiqit_class.content_piece_id -> catalog.piece_type
      tiqit_class.content_group_id -> catalog.group_type
      tiqit_class.catalog.id -> catalog.type
    end
  end
end
