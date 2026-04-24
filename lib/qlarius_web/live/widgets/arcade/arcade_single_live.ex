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
  # Shared helpers for the "View anywhere, Act only when authed"
  # pattern — `authed?/1`, `format_usd_or_dashes/1`,
  # `wallet_strip_or_connect/1`, `connect_wallet_modal/1`, etc.
  import QlariusWeb.Widgets.UnauthCTA

  on_mount {QlariusWeb.DetectMobile, :detect_mobile}
  # Nested `live_render/3` mounts don't go through the router, so
  # `mount_current_scope` isn't in the `:widgets` live_session's
  # on_mount list for them. Re-running it here guarantees
  # `@current_scope` is set in both contexts. `assign_new` inside
  # makes this idempotent for router-driven mounts.
  on_mount {QlariusWeb.UserAuth, :mount_current_scope}

  # This LiveView serves three contexts via @base_path / @inline?:
  # - Embedded standalone widgets: mounted at /widgets/arqade/:piece_id
  #   → @base_path = "/widgets", @inline? = false. Used when creators
  #   iframe the widget on third-party sites.
  # - Main app: mounted at /arqade/:piece_id → @base_path = "",
  #   @inline? = false. The normal in-app single-piece detail page.
  # - Nested inline: rendered via `live_render/3` from a Qlink page's
  #   `render_embed` → @base_path = "", @inline? = true. Same widget
  #   contents, but no breadcrumbs or layout chrome — the parent
  #   Qlink page already provides that.
  # All internal links use @base_path to stay within the correct context.

  # Nested/inline mount: `live_render/3` passes `:not_mounted_at_router`
  # as `params` and hands us the widget config via `session`.
  def mount(:not_mounted_at_router, session, socket) do
    piece_id = Map.fetch!(session, "piece_id")
    mount_impl(piece_id, %{}, session, socket)
  end

  def mount(%{"piece_id" => piece_id} = params, session, socket) do
    mount_impl(piece_id, params, session, socket)
  end

  defp mount_impl(piece_id, params, session, socket) do
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

      if connected?(socket) && scope && scope.user do
        Phoenix.PubSub.subscribe(Qlarius.PubSub, "wallet:#{scope.user.id}")
      end

      inline? = session["inline?"] == true
      force_theme = session["force_theme"] || Map.get(params, "force_theme", "light")

      # `base_path` resolution order mirrors `ArcadeLive`:
      #   1. Already assigned by a router `on_mount` hook
      #      (`QlariusWeb.Layouts.:set_base_path`) for
      #      /widgets/... mounts.
      #   2. `session["base_path"]` passed from a parent LV via
      #      `live_render/3`'s `:session` option (inline mounts).
      #   3. Default to "" (main-app style).
      base_path = socket.assigns[:base_path] || session["base_path"] || ""

      socket =
        socket
        |> init_pwa_assigns(session)
        |> assign(
          mounted: true,
          base_path: base_path,
          inline?: inline?,
          title: "Arqade",
          current_path: "/arqade/#{piece_id}",
          piece: piece,
          group: group,
          catalog: catalog,
          tiqit: tiqit,
          has_tiqit?: has_tiqit?,
          default_tiqit_class: default_tiqit_class,
          selected_tiqit_class: nil,
          options_modal: false,
          show_connect_modal: false,
          force_theme: force_theme
        )
        |> assign(scope_assigns(scope, group, catalog))

      socket =
        if has_tiqit? do
          send_post_message(socket, "tiqit_already_active", tiqit)
        else
          socket
        end

      {:ok, socket}
    end
  end

  # Computes all scope-dependent assigns (balance, offered, tiqit-up
  # credits, nudge) in one pure function. Returns a map suitable for
  # `assign/2`. Handles nil scope (anonymous viewer) by returning zero
  # credits and nil money fields, so templates can render via
  # `format_usd_or_dashes/1` without guarding.
  #
  # Mirrors `ArcadeLive.scope_assigns/2` so both LVs are consistent
  # and ready to be extracted to a shared LiveComponent later.
  defp scope_assigns(scope, group, catalog) do
    {group_credit, group_count} =
      if scope,
        do: Arcade.calculate_tiqit_up_credit_with_count(scope, group),
        else: {Decimal.new(0), 0}

    {catalog_credit, catalog_count} =
      if scope,
        do: Arcade.calculate_tiqit_up_credit_with_count(scope, catalog),
        else: {Decimal.new(0), 0}

    nudge? =
      if scope do
        case Arcade.check_tiqit_up_nudge(scope, group) do
          {:nudge, _credit, _cheapest} -> true
          _ -> false
        end
      else
        false
      end

    %{
      balance: scope && scope.wallet_balance,
      offered_amount: scope && scope.offered_amount,
      tiqit_up_group_credit: group_credit,
      tiqit_up_group_count: group_count,
      tiqit_up_catalog_credit: catalog_credit,
      tiqit_up_catalog_count: catalog_count,
      tiqit_up_nudge: nudge?
    }
  end

  # `handle_params/3` used to derive `base_path` here, but it's
  # forbidden on child LiveViews (Phoenix raises when nested LVs
  # define it). `base_path` is now seeded at mount time — either
  # by the `:widgets` live_session's `:set_base_path` on_mount
  # hook (standalone) or by the parent LV's `:session` map
  # (inline).

  def handle_event("pwa_detected", params, socket) do
    handle_pwa_detection(socket, params)
  end

  def handle_event("referral_code_from_storage", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("close-confirm-purchase-modal", _params, socket) do
    socket |> assign(selected_tiqit_class: nil) |> noreply()
  end

  def handle_event("dismiss-tiqit-up-nudge", _params, socket) do
    socket |> assign(:tiqit_up_nudge, false) |> noreply()
  end

  def handle_event("hide-options", _params, socket) do
    socket |> assign(:options_modal, false) |> noreply()
  end

  def handle_event("close-connect-modal", _params, socket) do
    socket |> assign(:show_connect_modal, false) |> noreply()
  end

  # Browse-options entry for anonymous viewers. Mirrors
  # `ArcadeLive.handle_event("browse-tiqit-options", ...)`. Opens the
  # confirm modal in "options" mode (the tiqit class grid) directly,
  # bypassing the Buy button, so anon viewers can freely explore
  # prices. Clicking any chip re-enters `select-tiqit-class`, which
  # is gated by `maybe_intercept_for_unauth/1`.
  def handle_event("browse-tiqit-options", _params, socket) do
    socket
    |> assign(
      selected_tiqit_class: ContentPiece.default_tiqit_class(socket.assigns.piece),
      options_modal: true
    )
    |> noreply()
  end

  # Any action that requires a wallet (select-tiqit-class,
  # purchase-tiqit, topup) is intercepted for anonymous viewers via
  # `maybe_intercept_for_unauth/1` at the top of each handler. If
  # unauthed, the handler returns early with `show_connect_modal: true`
  # and the real work never runs.
  def handle_event("select-tiqit-class", %{"tiqit-class-id" => tc_id}, socket) do
    with {:cont, socket} <- maybe_intercept_for_unauth(socket) do
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
  end

  def handle_event("show-options", _params, socket) do
    socket |> assign(:options_modal, true) |> noreply()
  end

  def handle_event("topup", _params, socket) do
    with {:cont, socket} <- maybe_intercept_for_unauth(socket) do
      user = socket.assigns.current_scope.user

      Wallets.fake_topup(user)

      Phoenix.PubSub.broadcast(Qlarius.PubSub, "wallet:#{user.id}", :update_balance)

      socket |> noreply()
    end
  end

  def handle_event("purchase-tiqit", %{"tiqit-class-id" => tiqit_class_id}, socket) do
    with {:cont, socket} <- maybe_intercept_for_unauth(socket) do
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
  end

  # Gate for wallet-required handlers. Returns `{:cont, socket}` when
  # the viewer is authed — callers unwrap via
  # `with {:cont, socket} <- maybe_intercept_for_unauth(socket)` to
  # proceed. Returns `{:noreply, socket}` when unauthed, assigning
  # `show_connect_modal: true` so the `with` short-circuits and the
  # Connect-wallet modal opens instead of performing the action.
  defp maybe_intercept_for_unauth(socket) do
    if authed?(socket.assigns.current_scope) do
      {:cont, socket}
    else
      {:noreply, socket |> assign(:show_connect_modal, true)}
    end
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
