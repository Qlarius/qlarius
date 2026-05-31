defmodule QlariusWeb.Widgets.Arcade.ArcadeLive do
  use QlariusWeb, :live_view

  alias Qlarius.Accounts.Scope
  alias Qlarius.ContentSharing
  alias Qlarius.Tiqit.Arcade.Arcade
  alias Qlarius.Tiqit.Arcade.ContentGroup
  alias Qlarius.Tiqit.Arcade.ContentPiece
  alias Qlarius.Tiqit.Arcade.TiqitClass
  alias Qlarius.Wallets
  alias QlariusWeb.WalletBalanceSync

  alias QlariusWeb.Layouts

  import QlariusWeb.Money
  import QlariusWeb.PWAHelpers
  import QlariusWeb.TiqitClassHTML
  import QlariusWeb.Widgets.Arcade.Components

  import QlariusWeb.Components.TiqitPlayer,
    only: [player_modal_frame: 1, player_side_panel_frame: 1]

  alias QlariusWeb.Components.TiqitPlayer
  # Shared helpers for the "View anywhere, Act only when authed"
  # pattern — `authed?/1`, `format_usd_or_dashes/1`,
  # `wallet_strip_or_connect/1`, `connect_wallet_modal/1`, etc.
  import QlariusWeb.Widgets.UnauthCTA

  import QlariusWeb.Creators.ContentGroupHTML, only: [piece_list_description: 1]

  on_mount {QlariusWeb.DetectMobile, :detect_mobile}

  # Ensure `current_scope` is assigned whether this LV is reached
  # via the router (where the `live_session` hook already ran) or
  # via `Phoenix.LiveView.live_render/3` from another LV (where
  # `live_session` hooks do NOT apply). `mount_current_scope` uses
  # `assign_new`, so running it twice when routed is a no-op.
  on_mount {QlariusWeb.UserAuth, :mount_current_scope}

  # Standalone-widget context needs `@user_ip` so the nested AuthSheet
  # can rate-limit `send_code` per-IP. Nested embeds on Qlink pages
  # don't host their own AuthSheet (they forward open requests to the
  # parent), but the hook is harmless there.
  on_mount {QlariusWeb.GetUserIP, :assign_ip}

  # Must stay in sync with `.tiqit-content-modal-*` animation duration in `app.css`.
  @tiqit_content_modal_close_ms 300

  # This LiveView serves three contexts via @base_path / @inline?:
  #
  #   1. Standalone widget — mounted at `/widgets/arqade/group/:group_id`
  #      via the widgets scope. `@base_path = "/widgets"`. Usually
  #      embedded through an iframe on third-party (or anon) surfaces.
  #
  #   2. Main app — mounted at `/arqade/group/:group_id` in the
  #      authed scope. `@base_path = ""`.
  #
  #   3. Nested inline — rendered via `Phoenix.LiveView.live_render/3`
  #      from inside another LV (e.g. a Qlink page). There is no URL
  #      for this LV; `params` is the atom `:not_mounted_at_router`
  #      and the parent hands us `group_id` through the `session:`
  #      option, along with `inline? = true` (which switches
  #      piece-selection from URL-driven `patch=` to in-process
  #      `phx-click` events so the parent LV's URL isn't mutated by
  #      the inline widget).
  #
  # All internal links continue to use `@base_path` to stay within
  # the correct context.
  def mount(:not_mounted_at_router, session, socket) do
    group_id =
      session["group_id"] ||
        raise ArgumentError,
              "ArcadeLive rendered via live_render/3 requires a `group_id` in session. " <>
                "Got session: #{inspect(Map.keys(session))}"

    mount(%{"group_id" => group_id}, session, socket)
  end

  def mount(%{"group_id" => group_id} = params, session, socket) do
    if connected?(socket) and socket.assigns[:mounted] do
      scope = socket.assigns.current_scope
      group = socket.assigns.group
      pieces = socket.assigns.pieces || []

      refreshed =
        if scope && scope.true_user, do: Scope.for_user(scope.true_user), else: scope

      {:ok,
       socket
       |> assign(
         Map.merge(scope_assigns(refreshed, group, pieces), %{
           current_scope: refreshed,
           arqade_expand_parent?: is_pid(socket.parent_pid)
         })
       )
       |> ensure_share_gift_assigns()
       |> WalletBalanceSync.notify_inline_parent()}
    else
      scope = socket.assigns.current_scope

      # Load data once
      group = Arcade.get_content_group!(group_id)

      pieces =
        group.content_pieces
        |> Enum.filter(&Enum.any?(&1.tiqit_classes))
        |> ContentGroup.ordered_content_pieces()

      # Runtime label for the clock row: real `length` (seconds) when set,
      # otherwise a stable seeded placeholder prefixed with ~.
      pieces = Enum.map(pieces, &put_piece_display_duration/1)

      show_title = Map.get(params, "show_title", "true") != "false"

      # `inline?` is set by the parent LV when this module is
      # rendered via `live_render/3` (see
      # `QlariusWeb.QlinkPage.Show.render_inline_arqade/2`). The
      # parent passes `%{"inline?" => true, "base_path" => "",
      # "force_theme" => ..., "show_title" => ...,
      # "auth_sheet_host_enabled?" => boolean}` through the
      # `session:` option, which arrives here as string keys.
      inline? = session["inline?"] == true or session["inline?"] == "true"

      # Parent LV's per-host AuthSheet decision, threaded through so
      # our CTA gating matches. `nil` when mounted standalone (no
      # parent), in which case `auth_sheet_enabled?/1` falls back to
      # the `:on_widget_standalone` flag.
      auth_sheet_host_enabled? =
        case session["auth_sheet_host_enabled?"] do
          true -> true
          "true" -> true
          false -> false
          "false" -> false
          _ -> nil
        end

      # Default "light" (session from parent, else param, else light) so /widgets/... iframes
      # match main-app palette without `?force_theme=light` — see ArcadeSingle/InstaTip/content_controller.
      force_theme = session["force_theme"] || Map.get(params, "force_theme", "light")

      show_title =
        if Map.has_key?(session, "show_title"),
          do: session["show_title"] != false and session["show_title"] != "false",
          else: show_title

      # `base_path` resolution order:
      #   1. Already assigned by a router `on_mount` hook
      #      (`QlariusWeb.Layouts.:set_base_path`) for standalone
      #      /widgets/... or /arqade/... mounts.
      #   2. `session["base_path"]` passed from a parent LV via
      #      `live_render/3`'s `:session` option (inline mounts).
      #   3. Default to "" (main-app style).
      base_path = socket.assigns[:base_path] || session["base_path"] || ""

      full_viewport_embed? = session["embed_host"] == "tiqit_arqade"
      embed_card? = inline? and not full_viewport_embed?
      in_app_group? = (base_path == "" and not inline?) or full_viewport_embed?
      # Qlink card embed + public Tiqit Arqade: wallet strip + Tiqit logo below Buy.
      show_qlink_footer? = embed_card? or full_viewport_embed?

      {:ok,
       socket
       |> init_pwa_assigns(session)
       |> assign(
         mounted: true,
         inline?: inline?,
         embed_card?: embed_card?,
         in_app_group?: in_app_group?,
         full_viewport_embed?: full_viewport_embed?,
         show_qlink_footer?: show_qlink_footer?,
         base_path: base_path,
         title: "Arqade",
         current_path: "/arqade/group/#{group_id}",
         group: group,
         pieces: pieces,
         selected_tiqit_class: nil,
         show_connect_modal: false,
         show_share_gift_modal: false,
         share_gift_modal_token: 0,
         share_gift_mode: "share",
         share_gift_share_target: "content_piece",
         share_gift_result: nil,
         purchase_intent: nil,
         show_auth_sheet: false,
         auth_referral_context: Qlarius.Referrals.Context.none(),
         auth_sheet_host_enabled?: auth_sheet_host_enabled?,
         force_theme: force_theme,
         show_title: show_title,
         show_tiqit_content_modal: false,
         tiqit_content_modal_leaving?: false,
         tiqit_content_modal_close_timer_ref: nil,
         embed_phx_id: session["embed_phx_id"],
         parent_phx_id: session["parent_phx_id"],
         arqade_expand_parent?: is_pid(socket.parent_pid),
         fixed_viewport: in_app_group?,
         episode_search: "",
         show_owned_only?: false,
         gift_piece_id: parse_int(session["gift_piece_id"]),
         play_frame: nil,
         slide_over_active: false,
         slide_over_title: "Now playing"
       )
       |> assign(scope_assigns(scope, group, pieces))
       |> maybe_init_selected_piece(inline?, session, params)
       |> WalletBalanceSync.notify_inline_parent()}
    end
  end

  # Seeds `selected_piece` + `tiqit` from the `content_id` present
  # in either `params` (standalone HTTP mount) or `session` (inline
  # nested mount). Unified across both contexts because nested
  # LiveViews can't define `handle_params/3` (Phoenix LV constraint
  # — it's only allowed on root LVs). Consequently piece selection
  # clicks must always go through `select-content` rather than a
  # URL patch, and the only URL-driven input is the initial
  # `?content_id=N` deep-link consumed here at mount.
  defp maybe_init_selected_piece(socket, _inline?, session, params) do
    content_id =
      (is_map(params) && params["content_id"]) ||
        session["content_id"]

    select_content_by_id(socket, content_id)
  end

  # Shared piece-selection logic. Resolves `content_id` (string or
  # int, or nil → defaults to first) against the loaded pieces,
  # then assigns the standard `selected_piece` / `default_tiqit_class`
  # / `tiqit` trio. Used by both the inline init path and by the
  # `handle_event("select-content", ...)` handler that replaces the
  # standalone `patch=` → handle_params navigation when embedded.
  defp select_content_by_id(socket, content_id) do
    pieces = socket.assigns.pieces

    selected_piece =
      case content_id do
        id when is_integer(id) ->
          Enum.find(pieces, &(&1.id == id)) || List.first(pieces)

        id when is_binary(id) ->
          case Integer.parse(id) do
            {i, _} -> Enum.find(pieces, &(&1.id == i)) || List.first(pieces)
            :error -> List.first(pieces)
          end

        _ ->
          List.first(pieces)
      end

    default_tiqit_class =
      if selected_piece, do: ContentPiece.default_tiqit_class(selected_piece), else: nil

    tiqit =
      if selected_piece,
        do: Arcade.get_valid_tiqit(socket.assigns.current_scope, selected_piece),
        else: nil

    socket
    |> assign(:selected_piece, selected_piece)
    |> assign(:default_tiqit_class, default_tiqit_class)
    |> assign(:tiqit, tiqit)
    |> reset_tiqit_content_modal()
  end

  # Computes all scope-dependent assigns (balance, offered, tiqit-up
  # credits, nudge) in one pure function. Returns a map suitable for
  # `assign/2`. Handles nil scope (anonymous viewer) by returning zero
  # credits and nil money fields, so templates can render via
  # `format_usd_or_dashes/1` without guarding.
  #
  # Extracted this way so that (a) the same helper serves the LV's
  # mount and `handle_info(:update_balance | {:me_file_offers_updated, _}, ...)` refresh paths, and
  # (b) when ArcadeLive is later extracted to a LiveComponent this
  # function can be called from the LC's `update/2` callback unchanged.
  defp scope_assigns(scope, group, pieces) do
    {group_credit, group_count} =
      if scope,
        do: Arcade.calculate_tiqit_up_credit_with_count(scope, group),
        else: {Decimal.new(0), 0}

    {catalog_credit, catalog_count} =
      if scope,
        do: Arcade.calculate_tiqit_up_credit_with_count(scope, group.catalog),
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

    daily_gift_available? =
      if scope && scope.user,
        do: Wallets.daily_gift_available?(scope.user),
        else: false

    %{
      balance: scope && scope.wallet_balance,
      offered_amount: scope && scope.offered_amount,
      tiqit_up_group_credit: group_credit,
      tiqit_up_group_count: group_count,
      tiqit_up_catalog_credit: catalog_credit,
      tiqit_up_catalog_count: catalog_count,
      tiqit_up_nudge: nudge?,
      daily_gift_available?: daily_gift_available?,
      valid_tiqit_piece_ids: Arcade.valid_piece_ids_for_group(scope, group, pieces)
    }
  end

  # NOTE: intentionally NO `handle_params/3`. Nested LiveViews
  # (see `Phoenix.LiveView.live_render/3`) are forbidden from
  # defining it — it is root-only. Piece selection is driven via
  # the `select-content` event in both standalone and inline modes;
  # URL-based deep linking is resolved once at mount via the
  # `content_id` query param (see `maybe_init_selected_piece/4`).

  # Piece-selection event for both standalone and inline mounts.
  # `content-id` arrives as a string from `phx-value-content-id` —
  # `select_content_by_id/2` parses it.
  def handle_event("select-content", %{"content-id" => content_id}, socket) do
    {:noreply, select_content_by_id(socket, content_id)}
  end

  # Episode list search (phase 1, in-memory). Filters @pieces by title
  # + description against `@episode_search`; debounced from the input
  # to limit chatter. Does NOT change `@selected_piece` — clicking a
  # result still triggers `select-content`.
  def handle_event("search-episodes", %{"q" => q}, socket) when is_binary(q) do
    {:noreply, assign(socket, :episode_search, q)}
  end

  def handle_event("clear-episode-search", _params, socket) do
    {:noreply, assign(socket, :episode_search, "")}
  end

  # Toggle "Show only purchased" — restrict the list to pieces in
  # `@valid_tiqit_piece_ids` (currently-valid tiqits at piece, group,
  # or catalog scope). Combines with `@episode_search`; selected piece
  # is unaffected.
  def handle_event("toggle-owned-only", _params, socket) do
    {:noreply, update(socket, :show_owned_only?, &(!&1))}
  end

  def handle_event("pwa_detected", params, socket) do
    handle_pwa_detection(socket, params)
  end

  def handle_event("referral_code_from_storage", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("close-confirm-purchase-modal", _params, socket) do
    reopen_gift? =
      socket.assigns[:purchase_intent] == :gift and is_nil(socket.assigns[:share_gift_result])

    socket =
      socket
      |> assign(
        selected_tiqit_class: nil,
        purchase_intent: nil,
        options_modal: false
      )

    socket =
      if reopen_gift?,
        do: assign(socket, show_share_gift_modal: true, share_gift_mode: "gift"),
        else: socket

    noreply(socket)
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

  # AuthSheet open/close. Gated behind `auth_sheet_enabled?/1` — when
  # the flag is off, arcade CTAs fall back to the legacy
  # `interact_login_url` redirect and these events never fire.
  #
  # When this LV is nested inside a hosting LV (e.g. a Qlink page),
  # we forward to the parent so there's only ever one AuthSheet on
  # the page — the parent's. `socket.parent_pid` is automatically
  # populated by `live_render/3` (nil for standalone mounts).
  #
  # Also closes the intermediate `show_connect_modal` to avoid
  # stacking two modals when the user clicks "Connect your wallet"
  # from inside the interstitial.
  def handle_event("open_auth_sheet", _params, socket) do
    case socket.parent_pid do
      nil ->
        socket
        |> assign(:show_auth_sheet, true)
        |> assign(:show_connect_modal, false)
        |> noreply()

      parent_pid ->
        send(parent_pid, {:open_auth_sheet, :tiqit})

        socket
        |> assign(:show_connect_modal, false)
        |> noreply()
    end
  end

  def handle_event("accept-gift", _params, socket) do
    if parent_pid = socket.parent_pid do
      send(parent_pid, :reopen_invitation_overlay)
    end

    noreply(socket)
  end

  def handle_event("toggle-arqade-fullpane", _params, socket) do
    if socket.assigns[:inline?] && socket.assigns[:embed_phx_id] do
      case socket.parent_pid do
        nil ->
          noreply(socket)

        parent_pid ->
          send(parent_pid, {:arqade_fullpane_toggle, socket.assigns.embed_phx_id})
          noreply(socket)
      end
    else
      noreply(socket)
    end
  end

  def handle_event("open-sponster-drawer", _params, socket) do
    case socket.parent_pid do
      nil ->
        socket
        |> push_event("send-post-message", %{type: "open_sponster_drawer"})
        |> noreply()

      parent_pid ->
        send(parent_pid, :open_sponster_drawer_from_embed)
        noreply(socket)
    end
  end

  def handle_event("close_auth_sheet", _params, socket) do
    socket |> assign(:show_auth_sheet, false) |> noreply()
  end

  # Browse-options entry for anonymous viewers. Mirrors the "All Tiqit
  # Options" link that authed users reach from inside the confirm
  # purchase modal — but reachable directly, since anon viewers can't
  # open the confirm modal (there's no Buy action for them).
  def handle_event("browse-tiqit-options", _params, socket) do
    piece = socket.assigns.selected_piece

    if Arcade.has_valid_tiqit?(socket.assigns.current_scope, piece) do
      {:noreply, socket}
    else
      socket
      |> assign(
        selected_tiqit_class: ContentPiece.default_tiqit_class(piece),
        options_modal: true
      )
      |> noreply()
    end
  end

  # --- Share / Gift ------------------------------------------------------

  def handle_event("open-share-gift-modal", _params, socket) do
    socket
    |> ensure_share_gift_assigns()
    |> assign(
      show_share_gift_modal: true,
      share_gift_modal_token: next_share_gift_modal_token(),
      share_gift_mode: "share",
      share_gift_share_target: "content_piece",
      share_gift_result: nil
    )
    |> noreply()
  end

  def handle_event("close-share-gift-modal", _params, socket) do
    socket
    |> assign(
      show_share_gift_modal: false,
      share_gift_result: nil,
      purchase_intent: nil,
      selected_tiqit_class: nil,
      options_modal: false
    )
    |> noreply()
  end

  def handle_event("share-gift-set-mode", %{"mode" => mode}, socket)
      when mode in ["share", "gift"] do
    socket
    |> assign(share_gift_mode: mode, share_gift_result: nil)
    |> noreply()
  end

  def handle_event("share-gift-set-target", %{"target" => target}, socket)
      when target in ["content_piece", "content_group"] do
    socket |> assign(share_gift_share_target: target) |> noreply()
  end

  def handle_event("create-share", _params, socket) do
    with {:cont, socket} <- maybe_intercept_for_unauth(socket) do
      target = socket.assigns.share_gift_share_target
      piece = socket.assigns.selected_piece
      group = socket.assigns.group

      attrs =
        case target do
          "content_group" ->
            %{share_target_type: "content_group", content_group_id: group.id}

          _ ->
            %{
              share_target_type: "content_piece",
              content_group_id: group.id,
              content_piece_id: piece && piece.id
            }
        end

      {:ok, result} = ContentSharing.create_share(socket.assigns.current_scope, attrs)

      socket
      |> assign(:share_gift_result, build_share_result(result, target, piece, group))
      |> noreply()
    end
  end

  def handle_event("select-tiqit-class", %{"tiqit-class-id" => tc_id}, socket) do
    with {:cont, socket} <- maybe_intercept_for_unauth(socket) do
      tc =
        %TiqitClass{} =
        Arcade.get_tiqit_class_for_piece!(
          tc_id,
          socket.assigns.selected_piece,
          socket.assigns.group
        )

      gift_flow? =
        socket.assigns.show_share_gift_modal && socket.assigns.share_gift_mode == "gift"

      {credit, count, adjusted_price} =
        if gift_flow? do
          {Decimal.new(0), 0, tc.price}
        else
          {credit, count} = tiqit_class_credit(tc, socket.assigns)
          {credit, count, Decimal.max(Decimal.new(0), Decimal.sub(tc.price, credit))}
        end

      balance = socket.assigns[:balance] || Decimal.new(0)

      if gift_flow? && Decimal.compare(balance, tc.price) == :lt do
        socket
        |> put_flash(:error, "Not enough wallet balance to gift this Tiqit.")
        |> noreply()
      else
        socket
        |> assign(
          show_share_gift_modal: if(gift_flow?, do: false, else: socket.assigns.show_share_gift_modal),
          purchase_intent: if(gift_flow?, do: :gift, else: nil),
          selected_tiqit_class: tc,
          selected_tiqit_class_adjusted_price: adjusted_price,
          selected_tiqit_class_credit: credit,
          selected_tiqit_class_active_count: count,
          options_modal: false
        )
        |> noreply()
      end
    end
  end

  def handle_event("show-options", _params, socket) do
    socket |> assign(:options_modal, true) |> noreply()
  end

  def handle_event("copy_success", _params, socket), do: noreply(socket)

  def handle_event("confirm-gift-purchase", _params, socket) do
    with {:cont, socket} <- maybe_intercept_for_unauth(socket) do
      tc = socket.assigns.selected_tiqit_class
      piece = socket.assigns.selected_piece
      group = socket.assigns.group

      if tc && socket.assigns[:purchase_intent] == :gift do
        attrs = ContentSharing.gift_attrs_for_class(tc, piece, group)

        case ContentSharing.create_gift(socket.assigns.current_scope, attrs) do
          {:ok, result} ->
            # Defer opening the copy-invitation modal until after the confirm
            # click finishes — otherwise phx-click-away on the newly mounted
            # modal treats that same click as an outside dismiss.
            Process.send_after(self(), :open_share_gift_result_modal, 0)

            socket
            |> refresh_balance_after_gift()
            |> assign(
              selected_tiqit_class: nil,
              purchase_intent: nil,
              show_share_gift_modal: false,
              share_gift_mode: "gift",
              share_gift_result: build_gift_result(result, tc, piece, group)
            )
            |> noreply()

          {:error, :insufficient_funds} ->
            socket
            |> put_flash(:error, "Not enough wallet balance to gift this Tiqit.")
            |> noreply()
        end
      else
        noreply(socket)
      end
    end
  end

  def handle_event("daily-gift", _params, socket) do
    with {:cont, socket} <- maybe_intercept_for_unauth(socket) do
      user = socket.assigns.current_scope.user

      case Wallets.claim_daily_gift(user) do
        {:ok, :credited} ->
          WalletBalanceSync.broadcast_balance_change(user)

          socket
          |> assign(:daily_gift_available?, false)
          |> noreply()

        {:error, :cooldown} ->
          socket
          |> put_flash(
            :error,
            "You already claimed your daily gift. Try again 24 hours after your last claim."
          )
          |> assign(:daily_gift_available?, false)
          |> noreply()

        {:error, _} ->
          socket
          |> put_flash(:error, "Could not apply daily gift. Please try again.")
          |> noreply()
      end
    end
  end

  # Unified play entry. Operates on `@selected_piece` (the list-click
  # already set it via `select-content`) and picks a frame:
  #
  #   * `:page`       — `push_navigate/2` to `/content/:id`
  #     (`ContentLive` in-app, `ContentController` under `/widgets`).
  #   * `:modal`      — opens the inline fullscreen overlay; this is
  #     the historical Qlink-embed behavior. Reuses the existing
  #     `:show_tiqit_content_modal` machinery so the close-animation
  #     timer keeps working unchanged.
  #   * `:side_panel` — slides the in-app mobile shell's right panel
  #     in over the episode list; `Layouts.mobile` renders the
  #     `:slide_over_content` slot the template passes in.
  #
  # See `TiqitPlayer.play_frame_for/1` for the per-context decision.
  def handle_event("play-piece", _params, socket) do
    socket |> open_player_for_selected_piece() |> noreply()
  end

  # Legacy modal-open entry — kept so any cached `phx-click="open-tiqit-content"`
  # on the wire (e.g. from a half-reloaded Qlink page) still works.
  # New clicks go through `play-piece`.
  def handle_event("open-tiqit-content", _params, socket) do
    socket
    |> cancel_tiqit_content_modal_close_timer()
    |> assign(:play_frame, :modal)
    |> assign(:show_tiqit_content_modal, true)
    |> noreply()
  end

  def handle_event("close-tiqit-content", _params, socket) do
    {:noreply, begin_tiqit_content_modal_close(socket)}
  end

  # Mobile-shell right slide-over close. The slide-over's Back button
  # in `Layouts.mobile` pushes this event; we flip the panel off and
  # clear `:play_frame` so the dispatcher stays consistent.
  def handle_event("close_slide_over", _params, socket) do
    socket
    |> assign(slide_over_active: false, play_frame: nil)
    |> noreply()
  end

  def handle_event("purchase-tiqit", %{"tiqit-class-id" => tiqit_class_id}, socket) do
    with {:cont, socket} <- maybe_intercept_for_unauth(socket) do
      tiqit_class =
        Arcade.get_tiqit_class_for_piece!(
          tiqit_class_id,
          socket.assigns.selected_piece,
          socket.assigns.group
        )

      opts =
        if tiqit_class.content_piece_id do
          []
        else
          [tiqit_up_credit: socket.assigns.selected_tiqit_class_credit]
        end

      :ok = Arcade.purchase_tiqit(socket.assigns.current_scope, tiqit_class, opts)

      socket
      |> socket_after_tiqit_purchase()
      |> open_player_for_selected_piece()
      |> noreply()
    end
  end

  # Gate for wallet-required handlers. Returns:
  #   - `{:cont, socket}` when the viewer is authed — callers unwrap
  #     via `with {:cont, socket} <- maybe_intercept_for_unauth(socket)`
  #     to proceed.
  #   - `{:noreply, socket}` (matching the LV event return contract)
  #     when unauthed — assigns `show_connect_modal: true` and the
  #     `with` short-circuits, so the caller's real work is skipped
  #     and the modal opens instead.
  defp maybe_intercept_for_unauth(socket) do
    if authed?(socket.assigns.current_scope) do
      {:cont, socket}
    else
      {:noreply, socket |> assign(:show_connect_modal, true)}
    end
  end

  def handle_info(:open_share_gift_result_modal, socket) do
    if socket.assigns[:share_gift_result] do
      {:noreply,
       assign(socket,
         show_share_gift_modal: true,
         share_gift_modal_token: next_share_gift_modal_token()
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_info(:tiqit_content_modal_close_done, socket) do
    if socket.assigns[:tiqit_content_modal_leaving?] == true do
      {:noreply,
       socket
       |> assign(:show_tiqit_content_modal, false)
       |> assign(:tiqit_content_modal_leaving?, false)
       |> assign(:tiqit_content_modal_close_timer_ref, nil)
       |> assign(:play_frame, nil)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:me_file_offers_updated, _me_file_id}, socket) do
    if socket.assigns[:mounted] do
      {:noreply, refresh_scope_after_wallet_or_offer_event(socket)}
    else
      {:noreply, socket}
    end
  end

  # Sent by the host LV after a gift PIN claim succeeds. Refresh the scope so
  # the newly-redeemed tiqit lands in `valid_tiqit_piece_ids` (flipping the
  # piece to Active/Play) and clear the gift highlight so the "Gifted" /
  # "Gifted to you" badges and "Accept Gift" CTA disappear.
  def handle_info(:gift_claimed, socket) do
    if socket.assigns[:mounted] do
      {:noreply,
       socket
       |> assign(:gift_piece_id, nil)
       |> refresh_scope_after_wallet_or_offer_event()}
    else
      {:noreply, socket}
    end
  end

  defp open_player_for_selected_piece(socket) do
    case socket.assigns.selected_piece do
      nil ->
        socket

      piece ->
        case TiqitPlayer.play_frame_for(socket.assigns) do
          :page ->
            push_navigate(socket, to: "#{socket.assigns.base_path}/content/#{piece.id}")

          :modal ->
            socket
            |> cancel_tiqit_content_modal_close_timer()
            |> assign(
              play_frame: :modal,
              show_tiqit_content_modal: true,
              slide_over_active: false
            )

          :side_panel ->
            assign(socket,
              play_frame: :side_panel,
              slide_over_active: true,
              slide_over_title: nil,
              show_tiqit_content_modal: false
            )
        end
    end
  end

  defp socket_after_tiqit_purchase(socket) do
    scope = socket.assigns.current_scope
    user = scope.user
    piece = socket.assigns.selected_piece
    group = socket.assigns.group
    pieces = socket.assigns.pieces

    tiqit = Arcade.get_valid_tiqit(scope, piece)
    balance = Wallets.get_user_current_balance(user)
    updated_scope = %{scope | wallet_balance: balance}

    WalletBalanceSync.broadcast_balance_change(user, balance)

    assign(socket,
      tiqit: tiqit,
      selected_tiqit_class: nil,
      options_modal: false,
      balance: balance,
      current_scope: updated_scope,
      valid_tiqit_piece_ids: Arcade.valid_piece_ids_for_group(updated_scope, group, pieces)
    )
    |> WalletBalanceSync.notify_parent_wallet_update(balance)
  end

  defp refresh_scope_after_wallet_or_offer_event(socket) do
    scope = socket.assigns[:current_scope]
    group = socket.assigns[:group]
    pieces = socket.assigns[:pieces] || []

    cond do
      scope && scope.true_user && group ->
        refreshed = Scope.for_user(scope.true_user)

        assign(
          socket,
          Map.merge(scope_assigns(refreshed, group, pieces), %{current_scope: refreshed})
        )

      true ->
        socket
    end
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

        piece_count = Arcade.active_piece_count_for_catalog(catalog)

        piece_type = catalog.piece_type |> to_string()
        piece_label = if piece_count == 1, do: piece_type, else: pluralize(piece_type)

        detail =
          if piece_count > 0,
            do: "#{group_count} #{group_label}, #{piece_count} #{piece_label}",
            else: "#{group_count} #{group_label}"

        %{
          scope: :catalog,
          label: "entire #{catalog.type}",
          detail: detail
        }
    end
  end

  defp pluralize(word) do
    word = to_string(word)
    if word == "series", do: "series", else: word <> "s"
  end

  defp group_piece_count_label(%ContentGroup{} = group) do
    piece_count = length(group.content_pieces)
    piece_type = group.catalog.piece_type |> to_string()
    piece_label = if piece_count == 1, do: piece_type, else: pluralize(piece_type)
    "#{piece_count} #{piece_label}"
  end

  defp reset_tiqit_content_modal(socket) do
    socket
    |> cancel_tiqit_content_modal_close_timer()
    |> assign(:show_tiqit_content_modal, false)
  end

  defp cancel_tiqit_content_modal_close_timer(socket) do
    case socket.assigns[:tiqit_content_modal_close_timer_ref] do
      ref when is_reference(ref) -> Process.cancel_timer(ref)
      _ -> :ok
    end

    assign(socket,
      tiqit_content_modal_close_timer_ref: nil,
      tiqit_content_modal_leaving?: false
    )
  end

  defp begin_tiqit_content_modal_close(socket) do
    cond do
      socket.assigns[:show_tiqit_content_modal] != true ->
        socket

      socket.assigns[:tiqit_content_modal_leaving?] == true ->
        socket

      true ->
        ref =
          Process.send_after(
            self(),
            :tiqit_content_modal_close_done,
            @tiqit_content_modal_close_ms
          )

        socket
        |> assign(:tiqit_content_modal_leaving?, true)
        |> assign(:tiqit_content_modal_close_timer_ref, ref)
    end
  end

  defp purchase_image_url(scope, piece, group) do
    case scope do
      :piece -> content_image_url(piece, group)
      :group -> group_image_url(group)
      :catalog -> catalog_image_url(group.catalog)
    end
  end


  @doc """
  Episode list filter (in-memory). Applies an optional case-insensitive
  substring match on `title` or `description`, then optionally
  restricts to pieces in `owned_ids` (the user's currently-valid
  tiqits — see `Arcade.valid_piece_ids_for_group/3`).

  Phase 1 only — runs over the already-loaded `@pieces`. When phase 2
  pagination lands this is replaced by a DB-driven `search_pieces/3`.
  """
  def filter_pieces(pieces, query, owned_only?, owned_ids)
      when is_list(pieces) and is_binary(query) do
    pieces
    |> filter_by_query(query)
    |> filter_by_owned(owned_only?, owned_ids)
  end

  def filter_pieces(pieces, _query, _owned_only?, _owned_ids) when is_list(pieces),
    do: pieces

  defp filter_by_query(pieces, query) do
    case String.trim(query) do
      "" ->
        pieces

      q ->
        needle = String.downcase(q)

        Enum.filter(pieces, fn piece ->
          piece_field_contains?(piece.title, needle) or
            piece_field_contains?(piece.description, needle)
        end)
    end
  end

  defp filter_by_owned(pieces, false, _owned_ids), do: pieces

  defp filter_by_owned(pieces, true, %MapSet{} = owned_ids),
    do: Enum.filter(pieces, &MapSet.member?(owned_ids, &1.id))

  defp filter_by_owned(pieces, true, _owned_ids), do: pieces

  defp piece_field_contains?(nil, _needle), do: false

  defp piece_field_contains?(value, needle) when is_binary(value),
    do: String.contains?(String.downcase(value), needle)

  defp put_piece_display_duration(%ContentPiece{} = piece) do
    duration =
      case piece.length do
        n when is_number(n) and n > 0 ->
          format_duration(n) |> to_string()

        _ ->
          "~" <> generated_placeholder_duration(piece.id)
      end

    Map.put(piece, :duration, duration)
  end

  @doc false
  def piece_published_date_label(%ContentPiece{} = piece) do
    case piece_display_date(piece) do
      %Date{} = date -> Calendar.strftime(date, "%b %d, %Y")
      _ -> nil
    end
  end

  defp piece_display_date(%ContentPiece{date_published: %Date{} = date}), do: date

  defp piece_display_date(%ContentPiece{inserted_at: %DateTime{} = dt}),
    do: DateTime.to_date(dt)

  defp piece_display_date(%ContentPiece{inserted_at: %NaiveDateTime{} = ndt}),
    do: NaiveDateTime.to_date(ndt)

  defp piece_display_date(_), do: nil

  defp generated_placeholder_duration(piece_id) do
    :rand.seed(:exsplus, {piece_id, piece_id, piece_id})
    mins = :rand.uniform(14) + 18
    secs = :rand.uniform(59) + 1
    :io_lib.format("~B:~2..0B", [mins, secs]) |> IO.iodata_to_binary()
  end

  @doc false
  def gift_piece_highlight?(piece_id, gift_piece_id, valid_tiqit_piece_ids) do
    not is_nil(gift_piece_id) and piece_id == gift_piece_id and
      not MapSet.member?(valid_tiqit_piece_ids, piece_id)
  end

  defp parse_int(id) when is_integer(id), do: id

  defp parse_int(id) when is_binary(id) do
    case Integer.parse(id) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp parse_int(_), do: nil

  defp ensure_share_gift_assigns(socket) do
    assign(socket, %{
      purchase_intent: socket.assigns[:purchase_intent],
      show_share_gift_modal: socket.assigns[:show_share_gift_modal] || false,
      share_gift_modal_token: socket.assigns[:share_gift_modal_token] || 0,
      share_gift_mode: socket.assigns[:share_gift_mode] || "share",
      share_gift_share_target: socket.assigns[:share_gift_share_target] || "content_piece",
      share_gift_result: socket.assigns[:share_gift_result]
    })
  end

  defp next_share_gift_modal_token do
    System.unique_integer([:positive, :monotonic])
  end

  defp refresh_balance_after_gift(socket) do
    scope = socket.assigns.current_scope
    user = scope.user
    balance = Wallets.get_user_current_balance(user)
    updated_scope = %{scope | wallet_balance: balance}

    WalletBalanceSync.broadcast_balance_change(user, balance)

    socket
    |> assign(balance: balance, current_scope: updated_scope)
    |> WalletBalanceSync.notify_parent_wallet_update(balance)
  end

  defp build_share_result(%{claim_path: claim_path}, target, piece, group) do
    title = share_content_title(target, piece, group)
    url = Qlarius.Qlink.Urls.public_app_url(claim_path)

    %{
      type: "share",
      url: url,
      pin: nil,
      message: "I thought you might like this on Tiqit:\n#{title}\n\nOpen it here: #{url}"
    }
  end

  defp build_gift_result(%{invitation: invitation, raw_pin: pin, claim_path: claim_path}, %TiqitClass{} = tc, piece, group) do
    title = if tc.content_piece_id && piece, do: piece.title, else: group.title
    url = Qlarius.Qlink.Urls.public_app_url(claim_path)

    message =
      ContentSharing.build_gift_invitation_message(title, url, pin, invitation.gift_expires_at)

    %{type: "gift", url: url, pin: pin, message: message}
  end

  defp share_content_title("content_group", _piece, group), do: group.title
  defp share_content_title(_target, piece, group), do: (piece && piece.title) || group.title

  # Returns {credit, active_tiqit_count} for a tiqit class based on its scope.
  # piece-level tiqits never apply credit; group-level uses group credit;
  # catalog-level uses the broader catalog credit.
  defp tiqit_class_credit(%TiqitClass{content_piece_id: piece_id}, _assigns)
       when not is_nil(piece_id),
       do: {Decimal.new(0), 0}

  defp tiqit_class_credit(%TiqitClass{content_group_id: group_id}, assigns)
       when not is_nil(group_id),
       do: {assigns.tiqit_up_group_credit, assigns.tiqit_up_group_count}

  defp tiqit_class_credit(%TiqitClass{}, assigns),
    do: {assigns.tiqit_up_catalog_credit, assigns.tiqit_up_catalog_count}

  # Whether the in-place AuthSheet should be rendered on this mount.
  # Two contexts this LV serves:
  #   - `inline?: true`  → nested inside a Qlink page. Reuses the
  #     parent's per-host AuthSheet decision, threaded in via
  #     `session["auth_sheet_host_enabled?"]` at mount and stashed
  #     as `@auth_sheet_host_enabled?`. This keeps the arcade CTA's
  #     `phx-click="open_auth_sheet"` in lockstep with whether the
  #     parent will actually render the sheet — on qlinkin.bio the
  #     parent uses `:on_qlinkin_bio`; on qlink.qadabra.app it uses
  #     `:on_qlink_page`.
  #   - `inline?: false` → standalone widget (iframe or direct
  #     /widgets/…). Uses `:auth_sheet[:on_widget_standalone]`.
  # When false, CTAs fall back to the legacy `interact_login_url`
  # redirect and the AuthSheet LC is not mounted.
  def auth_sheet_enabled?(assigns) do
    anonymous? =
      is_nil(assigns[:current_scope]) or is_nil(assigns[:current_scope].true_user)

    flag_on? =
      cond do
        assigns[:inline?] and is_boolean(assigns[:auth_sheet_host_enabled?]) ->
          assigns.auth_sheet_host_enabled?

        true ->
          flag_key = if assigns[:inline?], do: :on_qlink_page, else: :on_widget_standalone

          Application.get_env(:qlarius, :auth_sheet, [])
          |> Keyword.get(flag_key, false)
      end

    flag_on? and anonymous?
  end
end
