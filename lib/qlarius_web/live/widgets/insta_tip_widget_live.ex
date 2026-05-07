defmodule QlariusWeb.Widgets.InstaTipWidgetLive do
  use QlariusWeb, :live_view

  alias Qlarius.Accounts.Users
  alias Qlarius.Wallets

  import QlariusWeb.InstaTipComponents
  # Shared helpers for the "View anywhere, Act only when authed"
  # pattern — `authed?/1`, `connect_wallet_modal/1`, etc. Same imports
  # the arcade standalone widget uses so CTA behavior stays in lockstep.
  import QlariusWeb.Widgets.UnauthCTA

  on_mount {QlariusWeb.GetUserIP, :assign_ip}

  # `current_scope` is already assigned by the router `live_session`
  # (see `/widgets` scope in router.ex) via `:mount_current_scope`,
  # which uses `assign_new`. This re-assert is a no-op in that path;
  # kept here so the LV continues to work if ever rendered outside
  # the widgets scope (mirrors `ArcadeLive`).
  on_mount {QlariusWeb.UserAuth, :mount_current_scope}

  @default_amounts [
    Decimal.new("0.25"),
    Decimal.new("0.50"),
    Decimal.new("1.00"),
    Decimal.new("2.00")
  ]

  @impl true
  def mount(params, _session, socket) do
    split_code = Map.get(params, "split_code")
    force_theme = Map.get(params, "force_theme", "light")
    amounts_param = Map.get(params, "amounts")

    recipient = Users.get_recipient_by_split_code(split_code)

    amounts =
      case amounts_param do
        nil ->
          @default_amounts

        "" ->
          @default_amounts

        csv ->
          csv
          |> String.split([",", " "], trim: true)
          |> Enum.map(&Decimal.new/1)
          |> Enum.reject(&is_nil/1)
          |> case do
            [] -> @default_amounts
            list -> list
          end
      end

    scope = socket.assigns.current_scope
    user = scope && scope.user

    daily_gift_available? = if user, do: Wallets.daily_gift_available?(user), else: false

    socket =
      socket
      |> assign(:page_title, "InstaTip")
      |> assign(:recipient, recipient)
      |> assign(:amounts, amounts)
      |> assign(:force_theme, force_theme)
      |> assign(:show_insta_tip_modal, false)
      |> assign(:insta_tip_amount, nil)
      |> assign(:show_insta_tip_thanks_modal, false)
      |> assign(:insta_tip_thanks_amount, nil)
      |> assign(:insta_tip_thanks_recipient, nil)
      |> assign(:show_connect_modal, false)
      |> assign(:show_auth_sheet, false)
      |> assign(:auth_referral_context, Qlarius.Referrals.Context.none())
      |> assign(:current_balance, user && Wallets.get_user_current_balance(user))
      |> assign(:daily_gift_available?, daily_gift_available?)

    if connected?(socket) and user do
      # Subscribe to wallet balance updates for this me_file
      Qlarius.Wallets.MeFileStatsBroadcaster.subscribe_to_me_file_stats(user.me_file.id)

      # Subscribe to InstaTip notifications
      Phoenix.PubSub.subscribe(Qlarius.PubSub, "user:#{user.id}")
      Phoenix.PubSub.subscribe(Qlarius.PubSub, "wallet:#{user.id}")
    end

    {:ok, socket}
  end

  @impl true
  def handle_info({:refresh_wallet_balance, _me_file_id}, socket) do
    new_balance =
      Wallets.get_me_file_ledger_header_balance(socket.assigns.current_scope.user.me_file)

    current_scope = Map.put(socket.assigns.current_scope, :wallet_balance, new_balance)
    {:noreply, assign(socket, :current_scope, current_scope)}
  end

  @impl true
  def handle_info({:me_file_balance_updated, new_balance}, socket) do
    current_scope = Map.put(socket.assigns.current_scope, :wallet_balance, new_balance)
    {:noreply, assign(socket, :current_scope, current_scope)}
  end

  @impl true
  def handle_info("insta_tip_success", socket) do
    {:noreply, put_flash(socket, :info, "InstaTip sent successfully!")}
  end

  @impl true
  def handle_info("insta_tip_failure", socket) do
    {:noreply, put_flash(socket, :error, "InstaTip failed. Please try again.")}
  end

  @impl true
  def handle_info(:close_insta_tip_thanks_modal, socket) do
    {:noreply,
     socket
     |> assign(:show_insta_tip_thanks_modal, false)
     |> assign(:insta_tip_thanks_amount, nil)
     |> assign(:insta_tip_thanks_recipient, nil)}
  end

  @impl true
  def handle_info({:me_file_pending_referral_clicks_updated, pending_clicks_count}, socket) do
    current_scope =
      Map.put(socket.assigns.current_scope, :pending_referral_clicks_count, pending_clicks_count)

    {:noreply, assign(socket, :current_scope, current_scope)}
  end

  @impl true
  def handle_info(:update_balance, socket) do
    user = socket.assigns.current_scope && socket.assigns.current_scope.user

    if user do
      new_balance = Wallets.get_user_current_balance(user)
      current_scope = Map.put(socket.assigns.current_scope, :wallet_balance, new_balance)

      {:noreply,
       socket
       |> assign(:current_scope, current_scope)
       |> assign(:current_balance, new_balance)
       |> assign(:daily_gift_available?, Wallets.daily_gift_available?(user))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("initiate_insta_tip", %{"amount" => amount_str}, socket) do
    with {:cont, socket} <- maybe_intercept_for_unauth(socket) do
      amount = Decimal.new(to_string(amount_str))

      socket =
        socket
        |> assign(:insta_tip_amount, amount)
        |> assign(:show_insta_tip_modal, true)
        |> assign(
          :current_balance,
          Wallets.get_user_current_balance(socket.assigns.current_scope.user)
        )

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("confirm_insta_tip", %{"amount" => amount_str}, socket) do
    amount = Decimal.new(amount_str)
    user = socket.assigns.current_scope.user
    recipient = socket.assigns.recipient

    case Wallets.create_insta_tip_request(user, recipient, amount, user) do
      {:ok, _ledger_event} ->
        Process.send_after(self(), :close_insta_tip_thanks_modal, 3000)

        socket =
          socket
          |> assign(:show_insta_tip_modal, false)
          |> assign(:insta_tip_amount, nil)
          |> assign(:show_insta_tip_thanks_modal, true)
          |> assign(:insta_tip_thanks_amount, amount)
          |> assign(:insta_tip_thanks_recipient, (recipient && recipient.name) || "Recipient")

        {:noreply, socket}

      {:error, _changeset} ->
        socket =
          socket
          |> assign(:show_insta_tip_modal, false)
          |> assign(:insta_tip_amount, nil)
          |> put_flash(:error, "Failed to send InstaTip. Please try again.")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_insta_tip", _params, socket) do
    {:noreply, socket |> assign(:show_insta_tip_modal, false) |> assign(:insta_tip_amount, nil)}
  end

  @impl true
  def handle_event("close-insta-tip-modal", _params, socket) do
    {:noreply, socket |> assign(:show_insta_tip_modal, false) |> assign(:insta_tip_amount, nil)}
  end

  @impl true
  def handle_event("close-insta-tip-thanks-modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_insta_tip_thanks_modal, false)
     |> assign(:insta_tip_thanks_amount, nil)
     |> assign(:insta_tip_thanks_recipient, nil)}
  end

  # Shared "close the Connect interstitial" handler. Fires from both
  # the connect_wallet_modal's Cancel button and its default
  # `on_cancel` JS command.
  def handle_event("close-connect-modal", _params, socket) do
    {:noreply, assign(socket, :show_connect_modal, false)}
  end

  # AuthSheet open/close. Gated behind `auth_sheet_enabled?/1` — when
  # the flag is off, CTAs fall back to the legacy `interact_login_url`
  # redirect (via `wallet_strip_or_connect/1` with `on_click={nil}`)
  # and these events never fire.
  #
  # Unlike arcade, this LV is ONLY ever mounted standalone (it's at
  # /widgets/insta_tip, not rendered inline from another LV), so
  # there's no `socket.parent_pid` forwarding to consider — we always
  # host the sheet locally. Also closes the intermediate
  # `show_connect_modal` to avoid stacking two modals when the user
  # clicks "Connect your wallet" from inside the interstitial.
  def handle_event("open_auth_sheet", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_auth_sheet, true)
     |> assign(:show_connect_modal, false)}
  end

  def handle_event("close_auth_sheet", _params, socket) do
    {:noreply, assign(socket, :show_auth_sheet, false)}
  end

  def handle_event("open-sponster-drawer", _params, socket) do
    {:noreply, push_event(socket, "send-post-message", %{type: "open_sponster_drawer"})}
  end

  def handle_event("daily-gift", _params, socket) do
    with {:cont, socket} <- maybe_intercept_for_unauth(socket) do
      user = socket.assigns.current_scope.user

      case Wallets.claim_daily_gift(user) do
        {:ok, :credited} ->
          Phoenix.PubSub.broadcast(Qlarius.PubSub, "wallet:#{user.id}", :update_balance)

          new_balance = Wallets.get_user_current_balance(user)
          current_scope = Map.put(socket.assigns.current_scope, :wallet_balance, new_balance)

          {:noreply,
           socket
           |> assign(:current_scope, current_scope)
           |> assign(:current_balance, new_balance)
           |> assign(:daily_gift_available?, false)}

        {:error, :cooldown} ->
          {:noreply,
           socket
           |> put_flash(
             :error,
             "You already claimed your daily gift. Try again 24 hours after your last claim."
           )
           |> assign(:daily_gift_available?, false)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not apply daily gift. Please try again.")}
      end
    end
  end

  # Gate for wallet-required handlers. Mirrors `ArcadeLive`'s helper.
  # Returns `{:cont, socket}` when authed, `{:noreply, socket}` with
  # `show_connect_modal: true` when unauthed — so a `with` clause at
  # the top of each gated handler short-circuits to open the modal
  # instead of running the real work.
  defp maybe_intercept_for_unauth(socket) do
    if authed?(socket.assigns.current_scope) do
      {:cont, socket}
    else
      {:noreply, assign(socket, :show_connect_modal, true)}
    end
  end

  # Whether the in-place AuthSheet should be rendered on this mount.
  # This LV is always standalone (routed at `/widgets/insta_tip`;
  # never rendered via `live_render/3`) so it always uses the
  # `:on_widget_standalone` flag — no inline/parent threading needed.
  # Also requires the visitor to be anonymous; authed users don't
  # see the sheet.
  def auth_sheet_enabled?(assigns) do
    anonymous? =
      is_nil(assigns[:current_scope]) or is_nil(assigns[:current_scope].true_user)

    flag_on? =
      Application.get_env(:qlarius, :auth_sheet, [])
      |> Keyword.get(:on_widget_standalone, false)

    flag_on? and anonymous?
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id="insta-tip-postmessage-bridge"
      phx-hook="PostMessage"
      class="hidden"
      aria-hidden="true"
    >
    </div>
    <div data-theme="light" class="bg-base-100 h-screen flex items-center justify-center mt-2">
      <div class="container mx-auto px-4">
        <.insta_tip_card
          :if={@recipient}
          recipient={@recipient}
          scope={@current_scope}
          wallet_balance={@current_scope && @current_scope.wallet_balance}
          offered_amount={@current_scope && @current_scope.offered_amount}
          ads_count={@current_scope && @current_scope.ads_count}
          amounts={Enum.map(@amounts, &Decimal.to_string/1)}
          wallet_strip_id="wallet-balance-tipjar-widget"
          daily_gift_available?={@daily_gift_available?}
          on_auth_click={
            if auth_sheet_enabled?(assigns),
              do: Phoenix.LiveView.JS.push("open_auth_sheet"),
              else: nil
          }
        />
        <div :if={!@recipient} class="text-center text-base-content/50">
          Recipient not found
        </div>
      </div>
    </div>

    <.insta_tip_modal
      show={@show_insta_tip_modal}
      recipient_name={(@recipient && @recipient.name) || "Recipient"}
      recipient_id={@recipient && @recipient.id}
      amount={@insta_tip_amount || Decimal.new("0.00")}
      current_balance={(@current_scope && @current_scope.wallet_balance) || Decimal.new("0.00")}
    />

    <.insta_tip_thanks_modal
      show={@show_insta_tip_thanks_modal}
      recipient_name={@insta_tip_thanks_recipient || "Recipient"}
      amount={@insta_tip_thanks_amount || Decimal.new("0.00")}
    />

    <%!--
      Connect-wallet interstitial (same component arcade uses).
      Shown when an anonymous viewer taps an amount button. Its CTA
      opens the in-place AuthSheet when `auth_sheet_enabled?/1` is
      true, or falls back to the legacy cross-host redirect otherwise.
    --%>
    <.connect_wallet_modal
      show={@show_connect_modal}
      on_click={
        if auth_sheet_enabled?(assigns),
          do: Phoenix.LiveView.JS.push("open_auth_sheet"),
          else: nil
      }
    />

    <%!--
      In-place AuthSheet. Mounted only when the `:on_widget_standalone`
      flag is on AND the viewer is anonymous (authed users never see
      the sheet). Completing sign-in here triggers the `AuthFinalize`
      JS hook's `liveSocket.disconnect/connect`, re-mounting this LV
      with the authed session so the wallet strip + amount buttons
      flip to their authed state without a page navigation.
    --%>
    <%= if auth_sheet_enabled?(assigns) do %>
      <.live_component
        module={QlariusWeb.Components.AuthSheet}
        id="insta-tip-auth-sheet"
        show={@show_auth_sheet}
        surface={:on_widget_standalone}
        referral_context={@auth_referral_context}
        client_ip={assigns[:user_ip] || "0.0.0.0"}
        on_cancel={Phoenix.LiveView.JS.push("close_auth_sheet")}
      />
    <% end %>
    """
  end
end
