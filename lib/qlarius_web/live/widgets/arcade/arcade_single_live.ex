defmodule QlariusWeb.Widgets.Arcade.ArcadeSingleLive do
  use QlariusWeb, :live_view

  alias Qlarius.Tiqit.Arcade.Arcade
  alias Qlarius.Tiqit.Arcade.ContentPiece
  alias Qlarius.Tiqit.Arcade.TiqitClass
  alias Qlarius.Wallets

  import QlariusWeb.Money
  import QlariusWeb.TiqitClassHTML
  import QlariusWeb.Components.CustomComponentsMobile
  import QlariusWeb.Widgets.Arcade.Components

  def mount(%{"piece_id" => piece_id} = params, _session, socket) do
    if connected?(socket) and socket.assigns[:mounted] do
      scope = socket.assigns.current_scope

      {:ok,
       socket
       |> assign(
         balance: scope && scope.wallet_balance,
         offered_amount: scope && scope.offered_amount
       )}
    else
      scope = socket.assigns.current_scope

      piece =
        Arcade.get_content_piece!(piece_id)
        |> Qlarius.Repo.preload(
          content_group: [:tiqit_classes, catalog: [:tiqit_classes, :creator]]
        )

      group = piece.content_group
      catalog = group.catalog

      tiqit = Arcade.get_valid_tiqit(scope, piece)
      has_tiqit? = Arcade.has_valid_tiqit?(scope, piece)

      default_tiqit_class = ContentPiece.default_tiqit_class(piece)

      Phoenix.PubSub.subscribe(Qlarius.PubSub, "wallet:#{scope.user.id}")

      force_theme = Map.get(params, "force_theme", "light")

      socket =
        socket
        |> assign(
          mounted: true,
          balance: scope && scope.wallet_balance,
          offered_amount: scope && scope.offered_amount,
          piece: piece,
          group: group,
          catalog: catalog,
          tiqit: tiqit,
          has_tiqit?: has_tiqit?,
          default_tiqit_class: default_tiqit_class,
          selected_tiqit_class: nil,
          show_topup_modal: false,
          options_modal: false,
          force_theme: force_theme
        )

      socket =
        if has_tiqit? do
          send_post_message(socket, "tiqit_already_active", tiqit)
        else
          socket
        end

      {:ok, socket}
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

  def handle_event("select-tiqit-class", %{"tiqit-class-id" => tc_id}, socket) do
    tc =
      %TiqitClass{} =
      Arcade.get_tiqit_class_for_piece!(
        tc_id,
        socket.assigns.piece,
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

    socket |> noreply()
  end

  def handle_event("purchase-tiqit", %{"tiqit-class-id" => tiqit_class_id}, socket) do
    tiqit_class =
      Arcade.get_tiqit_class_for_piece!(
        tiqit_class_id,
        socket.assigns.piece,
        socket.assigns.group
      )

    :ok = Arcade.purchase_tiqit(socket.assigns.current_scope, tiqit_class)

    user = socket.assigns.current_scope.user

    Phoenix.PubSub.broadcast(Qlarius.PubSub, "wallet:#{user.id}", :update_balance)

    tiqit = Arcade.get_valid_tiqit(socket.assigns.current_scope, socket.assigns.piece)

    socket
    |> assign(
      has_tiqit?: true,
      tiqit: tiqit,
      selected_tiqit_class: nil
    )
    |> send_post_message("tiqit_purchased", tiqit)
    |> noreply()
  end

  def handle_info(:update_balance, socket) do
    if socket.assigns[:mounted] do
      user = socket.assigns.current_scope.user
      scope = socket.assigns.current_scope

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

  defp send_post_message(socket, event_type, tiqit) do
    push_event(socket, "send-post-message", %{
      type: event_type,
      piece_id: socket.assigns.piece.id,
      expires_at: tiqit.expires_at |> DateTime.to_iso8601()
    })
  end

  defp class_type(tiqit_class, catalog) do
    cond do
      tiqit_class.content_piece_id -> catalog.piece_type
      tiqit_class.content_group_id -> catalog.group_type
      tiqit_class.catalog_id -> catalog.type
    end
  end
end
