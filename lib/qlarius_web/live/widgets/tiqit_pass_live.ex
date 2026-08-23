defmodule QlariusWeb.Widgets.TiqitPassLive do
  @moduledoc """
  Third-party General Admission popover: catalog-level tiqit purchase.
  """
  use QlariusWeb, :live_view

  alias Qlarius.Tiqit.Arcade.Arcade
  alias Qlarius.Tiqit.Arcade.Catalog
  alias Qlarius.Tiqit.Arcade.TiqitClass
  alias Qlarius.Wallets
  alias QlariusWeb.WalletBalanceSync

  import QlariusWeb.Money
  import QlariusWeb.TiqitClassHTML
  import QlariusWeb.Widgets.Arcade.Components
  import QlariusWeb.Widgets.UnauthCTA
  import QlariusWeb.Helpers.ImageHelpers, only: [catalog_image_url: 1]

  on_mount {QlariusWeb.UserAuth, :mount_current_scope}
  on_mount {QlariusWeb.GetUserIP, :assign_ip}

  @impl true
  def mount(%{"catalog_id" => catalog_id} = params, _session, socket) do
    catalog = Arcade.get_catalog!(catalog_id)
    scope = socket.assigns.current_scope
    force_theme = Map.get(params, "force_theme", "light")
    default_tiqit_class = Catalog.default_tiqit_class(catalog)
    tiqit = Arcade.get_valid_catalog_tiqit(scope, catalog.id)
    has_tiqit? = !!tiqit

    socket =
      socket
      |> assign(
        page_title: "Tiqit Pass",
        catalog: catalog,
        force_theme: force_theme,
        default_tiqit_class: default_tiqit_class,
        selected_tiqit_class: nil,
        selected_tiqit_class_adjusted_price: nil,
        selected_tiqit_class_credit: Decimal.new(0),
        selected_tiqit_class_active_count: 0,
        options_modal: false,
        show_connect_modal: false,
        show_auth_sheet: false,
        auth_referral_context: Qlarius.Referrals.Context.none(),
        tiqit: tiqit,
        has_tiqit?: has_tiqit?
      )
      |> assign(scope_assigns(scope, catalog))

    socket =
      if has_tiqit? do
        send_post_message(socket, "tiqit_already_active", tiqit)
      else
        socket
      end

    {:ok, socket}
  end

  defp scope_assigns(scope, catalog) do
    {catalog_credit, catalog_count} =
      if scope,
        do: Arcade.calculate_tiqit_up_credit_with_count(scope, catalog),
        else: {Decimal.new(0), 0}

    daily_gift_available? =
      if scope && scope.user,
        do: Wallets.daily_gift_available?(scope.user),
        else: false

    %{
      balance: scope && scope.wallet_balance,
      offered_amount: scope && scope.offered_amount,
      tiqit_up_catalog_credit: catalog_credit,
      tiqit_up_catalog_count: catalog_count,
      daily_gift_available?: daily_gift_available?
    }
  end

  @impl true
  def handle_event("close-confirm-purchase-modal", _params, socket) do
    {:noreply, assign(socket, selected_tiqit_class: nil, options_modal: false)}
  end

  def handle_event("hide-options", _params, socket) do
    {:noreply, assign(socket, :options_modal, false)}
  end

  def handle_event("close-connect-modal", _params, socket) do
    {:noreply, assign(socket, :show_connect_modal, false)}
  end

  def handle_event("open_auth_sheet", _params, socket) do
    {:noreply, socket |> assign(:show_auth_sheet, true) |> assign(:show_connect_modal, false)}
  end

  def handle_event("close_auth_sheet", _params, socket) do
    {:noreply, assign(socket, :show_auth_sheet, false)}
  end

  def handle_event("sign-in", _params, socket) do
    if auth_sheet_enabled?(socket.assigns) do
      {:noreply, socket |> assign(:show_auth_sheet, true) |> assign(:show_connect_modal, false)}
    else
      {:noreply, assign(socket, :show_connect_modal, true)}
    end
  end

  def handle_event("tiqit_pass_back_home", _params, socket) do
    {:noreply, push_event(socket, "send-post-message", %{type: "tiqit_pass_back_home"})}
  end

  def handle_event("browse-tiqit-options", _params, socket) do
    {:noreply,
     assign(socket,
       selected_tiqit_class: socket.assigns.default_tiqit_class,
       options_modal: true
     )}
  end

  def handle_event("select-tiqit-class", %{"tiqit-class-id" => tc_id}, socket) do
    with {:cont, socket} <- maybe_intercept_for_unauth(socket) do
      tc = Arcade.get_tiqit_class_for_catalog!(tc_id, socket.assigns.catalog)

      active =
        Arcade.active_catalog_tiqit_classes(
          socket.assigns.current_scope,
          socket.assigns.catalog.id
        )

      if Arcade.tiqit_class_purchasable?(tc, active) do
        credit = socket.assigns.tiqit_up_catalog_credit
        count = socket.assigns.tiqit_up_catalog_count
        adjusted = Decimal.max(Decimal.new(0), Decimal.sub(tc.price, credit))

        {:noreply,
         assign(socket,
           selected_tiqit_class: tc,
           selected_tiqit_class_adjusted_price: adjusted,
           selected_tiqit_class_credit: credit,
           selected_tiqit_class_active_count: count,
           options_modal: false
         )}
      else
        {:noreply, socket}
      end
    end
  end

  def handle_event("show-options", _params, socket) do
    {:noreply, assign(socket, :options_modal, true)}
  end

  def handle_event("daily-gift", _params, socket) do
    with {:cont, socket} <- maybe_intercept_for_unauth(socket) do
      user = socket.assigns.current_scope.user

      case Wallets.claim_daily_gift(user) do
        {:ok, :credited} ->
          WalletBalanceSync.broadcast_balance_change(user)
          {:noreply, assign(socket, :daily_gift_available?, false)}

        {:error, :cooldown} ->
          {:noreply,
           socket
           |> put_flash(:error, "You already claimed your daily gift.")
           |> assign(:daily_gift_available?, false)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not apply daily gift. Please try again.")}
      end
    end
  end

  def handle_event("open-sponster-drawer", _params, socket) do
    {:noreply, push_event(socket, "send-post-message", %{type: "open_sponster_drawer"})}
  end

  def handle_event("purchase-tiqit", %{"tiqit-class-id" => tiqit_class_id}, socket) do
    with {:cont, socket} <- maybe_intercept_for_unauth(socket) do
      tiqit_class = Arcade.get_tiqit_class_for_catalog!(tiqit_class_id, socket.assigns.catalog)

      active =
        Arcade.active_catalog_tiqit_classes(
          socket.assigns.current_scope,
          socket.assigns.catalog.id
        )

      if Arcade.tiqit_class_purchasable?(tiqit_class, active) do
        case Arcade.purchase_tiqit(socket.assigns.current_scope, tiqit_class,
               tiqit_up_credit: socket.assigns.selected_tiqit_class_credit
             ) do
          :ok ->
            user = socket.assigns.current_scope.user
            balance = Wallets.get_user_current_balance(user)
            WalletBalanceSync.broadcast_balance_change(user, balance)

            tiqit =
              Arcade.get_valid_catalog_tiqit(
                socket.assigns.current_scope,
                socket.assigns.catalog.id
              )

            scope = socket.assigns.current_scope
            updated_scope = scope && %{scope | wallet_balance: balance}

            {:noreply,
             socket
             |> assign(
               has_tiqit?: true,
               tiqit: tiqit,
               selected_tiqit_class: nil,
               options_modal: false,
               balance: balance,
               current_scope: updated_scope
             )
             |> send_post_message("tiqit_purchased", tiqit)}

          {:error, :insufficient_funds} ->
            {:noreply, put_flash(socket, :error, "Not enough available to buy this Tiqit.")}
        end
      else
        {:noreply,
         put_flash(socket, :error, "That Tiqit is not an upgrade from your current access.")}
      end
    end
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp maybe_intercept_for_unauth(socket) do
    if authed?(socket.assigns.current_scope) do
      {:cont, socket}
    else
      {:noreply, assign(socket, :show_connect_modal, true)}
    end
  end

  defp send_post_message(socket, event_type, tiqit) do
    push_event(socket, "send-post-message", %{
      type: event_type,
      catalog_id: socket.assigns.catalog.id,
      expires_at: tiqit.expires_at && DateTime.to_iso8601(tiqit.expires_at)
    })
  end

  defp auth_sheet_enabled?(assigns) do
    anonymous? =
      is_nil(assigns[:current_scope]) or is_nil(assigns[:current_scope].true_user)

    flag_on? = Application.get_env(:qlarius, :auth_sheet, [])[:on_widget_standalone] == true
    anonymous? and flag_on?
  end

  @impl true
  def render(assigns) do
    catalog_label = Catalog.type_label(assigns.catalog.type)
    assigns = assign(assigns, :catalog_label, catalog_label)

    ~H"""
    <div
      id="tiqit-pass-root"
      phx-hook="PostMessage"
      data-theme={@force_theme}
      class="min-h-screen w-full bg-transparent"
    >
      <div class="fixed inset-0 bg-black/55" aria-hidden="true"></div>

      <div class="relative z-10 flex min-h-screen items-center justify-center p-4">
        <div class="relative w-full max-w-md rounded-2xl border border-base-300 bg-base-100 shadow-2xl">
          <button
            type="button"
            phx-click="tiqit_pass_back_home"
            class="absolute right-4 top-4 text-sm text-base-content/60 underline underline-offset-2 hover:text-base-content"
          >
            Back Home
          </button>

          <%= if @has_tiqit? do %>
            <div class="flex flex-col items-center gap-4 p-8 pt-12 text-center">
              <img src="/images/Tiqit_logo_color_horiz.svg" alt="Tiqit" class="h-8 w-auto" />
              <p class="text-lg font-semibold text-base-content">
                You're in — {@catalog_label} Access active
              </p>
              <QlariusWeb.Components.TiqitExpirationCountdown.badge
                :if={@tiqit && @tiqit.expires_at}
                expires_at={@tiqit.expires_at}
                class="badge-outline badge-md px-2 py-3 rounded-lg"
              />
            </div>
          <% else %>
            <div class="flex flex-col items-center gap-5 p-8 pt-12 text-center">
              <p class="text-xs font-bold tracking-[0.12em] text-base-content/70 uppercase">
                Readers get the full story
              </p>

              <%= if Enum.empty?(@catalog.tiqit_classes) do %>
                <div class="alert alert-warning text-left">
                  <.icon name="hero-exclamation-triangle" class="h-6 w-6 shrink-0" />
                  <span>
                    No {@catalog_label} Access Tiqit classes are configured for this catalog.
                    Add catalog-level tiqit classes before embedding this Pass.
                  </span>
                </div>
              <% else %>
                <div class="w-full overflow-hidden rounded-xl border border-base-300">
                  <div class="bg-primary px-4 py-2 text-center text-xs font-bold tracking-wide text-primary-content uppercase">
                    Best offer — {@catalog_label} Access
                  </div>
                  <div class="space-y-3 bg-base-100 px-5 py-6">
                    <p class="text-2xl font-bold text-base-content">
                      {format_tiqit_class_duration(@default_tiqit_class.duration_hours)} for {format_usd(
                        @default_tiqit_class.price,
                        zero_free: true
                      )}
                    </p>
                    <p class="text-sm text-base-content/70">
                      Unlock general {@catalog_label |> String.downcase()} reporting and stories
                      worth coming back to.
                    </p>

                    <% is_authed = authed?(@current_scope) %>
                    <% can_afford =
                      is_authed &&
                        Decimal.compare(@balance || Decimal.new(0), @default_tiqit_class.price) !=
                          :lt %>
                    <button
                      type="button"
                      phx-click="select-tiqit-class"
                      phx-value-tiqit-class-id={@default_tiqit_class.id}
                      disabled={is_authed && !can_afford}
                      class={[
                        "btn-widget btn-widget-emphasis btn-lg btn-block rounded-full",
                        is_authed && !can_afford && "btn-disabled"
                      ]}
                    >
                      Act Now
                    </button>

                    <button
                      type="button"
                      phx-click="browse-tiqit-options"
                      class="btn-widget btn-md btn-block rounded-full"
                    >
                      Full purchase options
                    </button>

                    <%= if is_authed && !can_afford do %>
                      <p class="text-sm text-warning">Not enough funds — top up below.</p>
                    <% end %>
                  </div>
                </div>

                <.wallet_strip_or_connect
                  id="wallet-balance-tiqit-pass"
                  scope={@current_scope}
                  balance={@current_scope && @current_scope.wallet_balance}
                  offered_amount={@offered_amount}
                  ads_count={@current_scope && @current_scope.ads_count}
                  daily_gift_available?={@daily_gift_available?}
                  on_click={
                    if auth_sheet_enabled?(assigns),
                      do: Phoenix.LiveView.JS.push("open_auth_sheet"),
                      else: nil
                  }
                />

                <p class="text-sm text-base-content/60">
                  Already a reader?
                  <button type="button" phx-click="sign-in" class="link link-primary font-medium">
                    Sign in
                  </button>
                </p>
              <% end %>

              <div class="flex items-center gap-1 pt-2">
                <span class="text-xs text-base-content/40">Access via</span>
                <img src="/images/Tiqit_logo_color_horiz.svg" alt="Tiqit" class="h-5 w-auto" />
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <.modal
        :if={@selected_tiqit_class}
        id="tiqit-pass-confirm-modal"
        border_class={tiqit_arqade_modal_border_class()}
        on_cancel={JS.push("close-confirm-purchase-modal")}
        show
      >
        <div class="flex flex-col space-y-4 p-8">
          <%= if @options_modal do %>
            <h2 class="text-xl font-bold text-base-content text-center">
              {@catalog_label} Access Options
            </h2>
            <div class="mx-auto w-full max-w-[400px] rounded-xl border border-base-300/70 bg-base-200/40 p-3">
              <div class="flex flex-row items-center gap-4">
                <img
                  src={catalog_image_url(@catalog)}
                  alt={@catalog.name}
                  class="block h-auto w-24 rounded-lg object-contain"
                />
                <div class="min-w-0 flex-1 text-left">
                  <h3 class="text-lg font-bold text-base-content">{@catalog.name}</h3>
                  <p class="text-sm text-base-content/60">Entire {@catalog_label}</p>
                </div>
              </div>
            </div>
            <div class="flex flex-col gap-2">
              <%= for tc <- TiqitClass.order_by_duration_hours_asc(@catalog.tiqit_classes) do %>
                <div class="flex items-center justify-between gap-3 rounded-lg border border-base-300 px-3 py-2">
                  <span class="text-sm font-medium text-base-content">
                    {format_tiqit_class_duration(tc.duration_hours)}
                  </span>
                  <.tiqit_class_grid_price
                    tiqit_class={tc}
                    balance={@balance}
                    selected_class_id={@selected_tiqit_class && @selected_tiqit_class.id}
                    active_tiqit_classes={
                      Arcade.active_catalog_tiqit_classes(@current_scope, @catalog.id)
                    }
                  />
                </div>
              <% end %>
            </div>
          <% else %>
            <div class="mx-auto w-full max-w-[400px] rounded-xl border border-base-300/70 bg-base-200/40 p-3">
              <div class="flex flex-row items-center gap-4">
                <img
                  src={catalog_image_url(@catalog)}
                  alt={@catalog.name}
                  class="block h-auto w-24 rounded-lg object-contain"
                />
                <div class="min-w-0 flex-1 text-left">
                  <h3 class="text-lg font-bold text-base-content">{@catalog.name}</h3>
                  <p class="text-sm text-base-content/60">Entire {@catalog_label}</p>
                </div>
              </div>
            </div>
            <p class="text-center text-base-content/60">
              <%= if @selected_tiqit_class.duration_hours do %>
                You are purchasing
                <span class="font-bold text-base-content">{@catalog_label} Access</span>
                for <span class="font-bold text-base-content">
                  {format_tiqit_class_duration(@selected_tiqit_class.duration_hours)}
                </span>.
              <% else %>
                You are purchasing <span class="font-bold text-base-content">lifetime {@catalog_label} Access</span>.
              <% end %>
            </p>
            <button
              type="button"
              phx-click="purchase-tiqit"
              phx-value-tiqit-class-id={@selected_tiqit_class.id}
              class="btn-widget btn-widget-emphasis btn-lg btn-block rounded-full"
            >
              <.icon name="hero-check" class="mr-2 h-4 w-4" /> Confirm •
              <span class="font-bold">
                {format_usd(
                  @selected_tiqit_class_adjusted_price || @selected_tiqit_class.price,
                  zero_free: true
                )}
              </span>
            </button>
            <%= if Decimal.gt?(@selected_tiqit_class_credit, 0) do %>
              <div class="alert mt-2 justify-center border border-widget-300 bg-widget-100 py-2">
                <span class="flex items-center gap-1 text-sm">
                  <.icon name="hero-sparkles-solid" class="h-4 w-4 text-widget-700" />
                  TiqitUp discount of {format_usd(@selected_tiqit_class_credit)} applied.
                </span>
              </div>
            <% end %>
            <div class="divider m-1"></div>
            <div class="flex flex-row items-center justify-center gap-2">
              <p class="text-base-content/60">Want a longer pass?</p>
              <button
                type="button"
                phx-click="show-options"
                class="btn btn-outline btn-md rounded-full"
              >
                All options
              </button>
            </div>
          <% end %>
          <div class="mt-2 flex justify-center">
            <img src="/images/TIQIT_logo_color_square.svg" alt="Tiqit" class="h-8 w-auto" />
          </div>
        </div>
      </.modal>

      <.connect_wallet_modal
        show={@show_connect_modal}
        scope={@current_scope}
        connect_brand={:tiqit}
        on_click={
          if auth_sheet_enabled?(assigns),
            do: Phoenix.LiveView.JS.push("open_auth_sheet"),
            else: nil
        }
      />

      <%= if auth_sheet_enabled?(assigns) do %>
        <.live_component
          module={QlariusWeb.Components.AuthSheet}
          id="tiqit-pass-auth-sheet"
          show={@show_auth_sheet}
          surface={:on_widget_standalone}
          iframe_hint={true}
          referral_context={@auth_referral_context}
          client_ip={assigns[:user_ip] || "0.0.0.0"}
          connect_brand={:tiqit}
          on_cancel={Phoenix.LiveView.JS.push("close_auth_sheet")}
        />
      <% end %>
    </div>
    """
  end
end
