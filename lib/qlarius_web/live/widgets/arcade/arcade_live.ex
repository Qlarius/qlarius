defmodule QlariusWeb.Widgets.Arcade.ArcadeLive do
  use QlariusWeb, :live_view

  alias Qlarius.Tiqit.Arcade.Arcade
  alias Qlarius.Tiqit.Arcade.ContentGroup
  alias Qlarius.Tiqit.Arcade.ContentPiece
  alias Qlarius.Tiqit.Arcade.TiqitClass
  alias Qlarius.Wallets

  alias QlariusWeb.Layouts

  import QlariusWeb.Money
  import QlariusWeb.PWAHelpers
  import QlariusWeb.TiqitClassHTML
  import QlariusWeb.Widgets.Arcade.Components
  import QlariusWeb.Components.TiqitUnlockedContent, only: [tiqit_unlocked_content_player: 1]
  # Shared helpers for the "View anywhere, Act only when authed"
  # pattern — `authed?/1`, `format_usd_or_dashes/1`,
  # `wallet_strip_or_connect/1`, `connect_wallet_modal/1`, etc.
  import QlariusWeb.Widgets.UnauthCTA

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

      {:ok,
       socket
       |> assign(
         balance: scope && scope.wallet_balance,
         offered_amount: scope && scope.offered_amount,
         arqade_expand_parent?: is_pid(socket.parent_pid),
         daily_gift_available?:
           if(scope && scope.user, do: Wallets.daily_gift_available?(scope.user), else: false)
       )}
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

      if connected?(socket) && scope && scope.user do
        Phoenix.PubSub.subscribe(Qlarius.PubSub, "wallet:#{scope.user.id}")
      end

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

      {:ok,
       socket
       |> init_pwa_assigns(session)
       |> assign(
         mounted: true,
         inline?: inline?,
         base_path: base_path,
         title: "Arqade",
         current_path: "/arqade/group/#{group_id}",
         group: group,
         pieces: pieces,
         selected_tiqit_class: nil,
         show_connect_modal: false,
         show_auth_sheet: false,
         auth_referral_context: Qlarius.Referrals.Context.none(),
         auth_sheet_host_enabled?: auth_sheet_host_enabled?,
         force_theme: force_theme,
         show_title: show_title,
         show_tiqit_content_modal: false,
         tiqit_content_modal_leaving?: false,
         tiqit_content_modal_close_timer_ref: nil,
         embed_phx_id: session["embed_phx_id"],
         arqade_expand_parent?: is_pid(socket.parent_pid),
         fixed_viewport: base_path == "" and not inline?
       )
       |> assign(scope_assigns(scope, group))
       |> maybe_init_selected_piece(inline?, session, params)}
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
  # mount and `handle_info(:update_balance, ...)` refresh path, and
  # (b) when ArcadeLive is later extracted to a LiveComponent this
  # function can be called from the LC's `update/2` callback unchanged.
  defp scope_assigns(scope, group) do
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
      daily_gift_available?: daily_gift_available?
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
    socket
    |> assign(
      selected_tiqit_class: ContentPiece.default_tiqit_class(socket.assigns.selected_piece),
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
          socket.assigns.selected_piece,
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

  def handle_event("daily-gift", _params, socket) do
    with {:cont, socket} <- maybe_intercept_for_unauth(socket) do
      user = socket.assigns.current_scope.user

      case Wallets.claim_daily_gift(user) do
        {:ok, :credited} ->
          Phoenix.PubSub.broadcast(Qlarius.PubSub, "wallet:#{user.id}", :update_balance)

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

  def handle_event("open-tiqit-content", _params, socket) do
    socket
    |> cancel_tiqit_content_modal_close_timer()
    |> assign(:show_tiqit_content_modal, true)
    |> noreply()
  end

  def handle_event("close-tiqit-content", _params, socket) do
    {:noreply, begin_tiqit_content_modal_close(socket)}
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

      user = socket.assigns.current_scope.user

      Phoenix.PubSub.broadcast(Qlarius.PubSub, "wallet:#{user.id}", :update_balance)

      if socket.assigns.inline? do
        tiqit =
          Arcade.get_valid_tiqit(socket.assigns.current_scope, socket.assigns.selected_piece)

        balance = Wallets.get_user_current_balance(user)
        scope = socket.assigns.current_scope
        updated_scope = scope && %{scope | wallet_balance: balance}

        socket
        |> cancel_tiqit_content_modal_close_timer()
        |> assign(
          tiqit: tiqit,
          selected_tiqit_class: nil,
          show_tiqit_content_modal: true,
          balance: balance,
          current_scope: updated_scope
        )
        |> noreply()
      else
        base = socket.assigns.base_path

        redirect_path =
          if socket.assigns.force_theme do
            "#{base}/content/#{socket.assigns.selected_piece.id}?force_theme=#{socket.assigns.force_theme}"
          else
            "#{base}/content/#{socket.assigns.selected_piece.id}"
          end

        socket
        |> redirect(to: redirect_path)
        |> noreply()
      end
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

  def handle_info(:tiqit_content_modal_close_done, socket) do
    if socket.assigns[:tiqit_content_modal_leaving?] == true do
      {:noreply,
       socket
       |> assign(:show_tiqit_content_modal, false)
       |> assign(:tiqit_content_modal_leaving?, false)
       |> assign(:tiqit_content_modal_close_timer_ref, nil)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(:update_balance, socket) do
    # Only update if mounted to prevent race conditions
    if socket.assigns[:mounted] do
      user = socket.assigns.current_scope.user
      scope = socket.assigns.current_scope

      # Only fetch balance if user exists
      balance = if user, do: Wallets.get_user_current_balance(user), else: socket.assigns.balance

      updated_scope = %{scope | wallet_balance: balance}

      daily_gift_available? = if user, do: Wallets.daily_gift_available?(user), else: false

      {:noreply,
       assign(socket,
         balance: balance,
         current_scope: updated_scope,
         offered_amount: scope && scope.offered_amount,
         daily_gift_available?: daily_gift_available?
       )}
    else
      {:noreply, socket}
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

        piece_count =
          catalog.content_groups
          |> Enum.map(fn g ->
            if Ecto.assoc_loaded?(g.content_pieces),
              do: length(g.content_pieces),
              else: 0
          end)
          |> Enum.sum()

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

  # Heuristic: matches ~3 line-clamp at text-xs without measuring DOM.
  defp description_exceeds_preview?(nil), do: false

  defp description_exceeds_preview?(description) do
    t = String.trim(to_string(description))
    line_blocks = String.split(t, "\n", trim: true)

    t != "" and
      (String.length(t) > 120 or length(line_blocks) > 3)
  end

  defp description_preview_text(description) do
    (description || "")
    |> String.trim()
    |> String.replace("\n", " ")
  end

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

  defp generated_placeholder_duration(piece_id) do
    :rand.seed(:exsplus, {piece_id, piece_id, piece_id})
    mins = :rand.uniform(14) + 18
    secs = :rand.uniform(59) + 1
    :io_lib.format("~B:~2..0B", [mins, secs]) |> IO.iodata_to_binary()
  end

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
