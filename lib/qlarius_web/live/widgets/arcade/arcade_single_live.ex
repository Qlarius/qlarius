defmodule QlariusWeb.Widgets.Arcade.ArcadeSingleLive do
  use QlariusWeb, :live_view

  alias Qlarius.Tiqit.Arcade.Arcade
  alias Qlarius.Tiqit.Arcade.ContentPiece
  alias Qlarius.Tiqit.Arcade.TiqitClass
  alias Qlarius.Wallets

  alias QlariusWeb.Layouts

  import QlariusWeb.Money
  import QlariusWeb.PWAHelpers
  import QlariusWeb.TiqitClassHTML
  import QlariusWeb.Widgets.Arcade.Components

  on_mount {QlariusWeb.DetectMobile, :detect_mobile}

  # This LiveView serves two contexts via @base_path:
  # - Embedded widgets: mounted at /widgets/arqade/:piece_id → @base_path = "/widgets"
  # - Main app: mounted at /arqade/:piece_id → @base_path = ""
  # All internal links use @base_path to stay within the correct context.
  def mount(%{"piece_id" => piece_id} = params, session, socket) do
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

      {tiqit_up_group_credit, tiqit_up_group_count} =
        if scope, do: Arcade.calculate_tiqit_up_credit_with_count(scope, group), else: {Decimal.new(0), 0}

      {tiqit_up_catalog_credit, tiqit_up_catalog_count} =
        if scope, do: Arcade.calculate_tiqit_up_credit_with_count(scope, catalog), else: {Decimal.new(0), 0}

      tiqit_up_nudge =
        if scope do
          case Arcade.check_tiqit_up_nudge(scope, group) do
            {:nudge, _credit, _cheapest} -> true
            _ -> false
          end
        else
          false
        end

      socket =
        socket
        |> init_pwa_assigns(session)
        |> assign(
          mounted: true,
          base_path: "",
          title: "Arqade",
          current_path: "/arqade/#{piece_id}",
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
          force_theme: force_theme,
          tiqit_up_group_credit: tiqit_up_group_credit,
          tiqit_up_group_count: tiqit_up_group_count,
          tiqit_up_catalog_credit: tiqit_up_catalog_credit,
          tiqit_up_catalog_count: tiqit_up_catalog_count,
          tiqit_up_nudge: tiqit_up_nudge
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

  def handle_params(_params, uri, socket) do
    base_path = if String.contains?(uri, "/widgets/"), do: "/widgets", else: ""
    {:noreply, assign(socket, :base_path, base_path)}
  end

  def handle_event("pwa_detected", params, socket) do
    handle_pwa_detection(socket, params)
  end

  def handle_event("referral_code_from_storage", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("close-confirm-purchase-modal", _params, socket) do
    socket |> assign(selected_tiqit_class: nil) |> noreply()
  end

  def handle_event("close-topup-modal", _params, socket) do
    socket |> assign(:show_topup_modal, false) |> noreply()
  end

  def handle_event("dismiss-tiqit-up-nudge", _params, socket) do
    socket |> assign(:tiqit_up_nudge, false) |> noreply()
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

    {credit, count} = tiqit_class_credit(tc, socket.assigns)
    adjusted_price = Decimal.max(Decimal.new(0), Decimal.sub(tc.price, credit))

    socket
    |> assign(
      selected_tiqit_class: tc,
      selected_tiqit_class_adjusted_price: adjusted_price,
      selected_tiqit_class_credit: credit,
      selected_tiqit_class_active_count: count,
      options_modal: false
    )
    |> noreply()
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

    opts =
      if tiqit_class.content_piece_id do
        []
      else
        [tiqit_up_credit: socket.assigns.selected_tiqit_class_credit]
      end

    :ok = Arcade.purchase_tiqit(socket.assigns.current_scope, tiqit_class, opts)

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

      updated_scope = %{scope | wallet_balance: balance}

      {:noreply,
       assign(socket,
         balance: balance,
         current_scope: updated_scope,
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

  defp purchase_description(tiqit_class, group) do
    catalog = group.catalog

    cond do
      tiqit_class.content_piece_id ->
        %{
          scope: :piece,
          label: "single #{catalog.piece_type}",
          detail: nil
        }

      tiqit_class.content_group_id ->
        piece_count = length(group.content_pieces)
        piece_type = catalog.piece_type |> to_string()
        piece_label = if piece_count == 1, do: piece_type, else: pluralize(piece_type)

        %{
          scope: :group,
          label: "entire #{catalog.group_type}",
          detail: "#{piece_count} #{piece_label}"
        }

      true ->
        group_count = length(catalog.content_groups)
        group_type = catalog.group_type |> to_string()
        group_label = if group_count == 1, do: group_type, else: pluralize(group_type)

        piece_count =
          catalog.content_groups
          |> Enum.flat_map(& &1.content_pieces)
          |> length()

        piece_type = catalog.piece_type |> to_string()
        piece_label = if piece_count == 1, do: piece_type, else: pluralize(piece_type)

        %{
          scope: :catalog,
          label: "entire #{catalog.type}",
          detail: "#{group_count} #{group_label}, #{piece_count} #{piece_label}"
        }
    end
  end

  defp pluralize(word) do
    word = to_string(word)
    if word == "series", do: "series", else: word <> "s"
  end

  defp purchase_image_url(scope, piece, group) do
    case scope do
      :piece -> content_image_url(piece, group)
      :group -> group_image_url(group)
      :catalog -> catalog_image_url(group.catalog)
    end
  end

  # Returns {credit, active_tiqit_count} for a tiqit class based on its scope.
  # piece-level tiqits never apply credit; group-level uses group credit;
  # catalog-level uses the broader catalog credit.
  defp tiqit_class_credit(%TiqitClass{content_piece_id: piece_id}, _assigns) when not is_nil(piece_id),
    do: {Decimal.new(0), 0}

  defp tiqit_class_credit(%TiqitClass{content_group_id: group_id}, assigns) when not is_nil(group_id),
    do: {assigns.tiqit_up_group_credit, assigns.tiqit_up_group_count}

  defp tiqit_class_credit(%TiqitClass{}, assigns),
    do: {assigns.tiqit_up_catalog_credit, assigns.tiqit_up_catalog_count}
end
