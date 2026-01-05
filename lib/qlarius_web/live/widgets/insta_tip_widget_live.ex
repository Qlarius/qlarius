defmodule QlariusWeb.Widgets.InstaTipWidgetLive do
  use QlariusWeb, :live_view

  alias Qlarius.Accounts.Users
  alias Qlarius.Wallets
  import QlariusWeb.InstaTipComponents

  on_mount {QlariusWeb.GetUserIP, :assign_ip}

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

    socket =
      socket
      |> assign(:page_title, "InstaTip")
      |> assign(:recipient, recipient)
      |> assign(:amounts, amounts)
      |> assign(:force_theme, force_theme)
      |> assign(:show_insta_tip_modal, false)
      |> assign(:insta_tip_amount, nil)
      |> assign(
        :current_balance,
        Wallets.get_user_current_balance(socket.assigns.current_scope.user)
      )

    if connected?(socket) do
      # Subscribe to wallet balance updates for this me_file
      Qlarius.Wallets.MeFileStatsBroadcaster.subscribe_to_me_file_stats(
        socket.assigns.current_scope.user.me_file.id
      )

      # Subscribe to InstaTip notifications
      Phoenix.PubSub.subscribe(Qlarius.PubSub, "user:#{socket.assigns.current_scope.user.id}")
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
  def handle_info({:me_file_pending_referral_clicks_updated, pending_clicks_count}, socket) do
    current_scope =
      Map.put(socket.assigns.current_scope, :pending_referral_clicks_count, pending_clicks_count)

    {:noreply, assign(socket, :current_scope, current_scope)}
  end

  @impl true
  def handle_event("initiate_insta_tip", %{"amount" => amount_str}, socket) do
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

  @impl true
  def handle_event("confirm_insta_tip", %{"amount" => amount_str}, socket) do
    amount = Decimal.new(amount_str)
    user = socket.assigns.current_scope.user
    recipient = socket.assigns.recipient

    case Wallets.create_insta_tip_request(user, recipient, amount, user) do
      {:ok, _ledger_event} ->
        socket =
          socket
          |> assign(:show_insta_tip_modal, false)
          |> assign(:insta_tip_amount, nil)
          |> put_flash(:info, "InstaTip processing…")

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
  def render(assigns) do
    ~H"""
    <div data-theme="light" class="bg-base-100 h-screen flex items-center justify-center mt-2">
      <div class="container mx-auto px-4">
        <div class="flex flex-col items-center">
          <div :if={@recipient} class="flex flex-col md:flex-row items-center gap-4">
            <div class="w-40 h-auto md:w-50 bg-base-300 shadow-md flex items-center justify-center mb-0 md:mb-4 overflow-hidden">
              <img
                src={
                  if @recipient && @recipient.graphic_url do
                    QlariusWeb.Uploaders.RecipientBrandImage.url({@recipient.graphic_url, @recipient})
                  else
                    ~p"/images/tipjar_love_default.png"
                  end
                }
                alt="Recipient"
                class="object-contain w-full h-full rounded"
              />
            </div>
            <div class="text-base-content/70 text-sm text-left md:text-center max-w-xs p-2 text-center">
              {(@recipient && @recipient.message) ||
                "Thank you for supporting this content. Your Sponster tips are greatly appreciated!"}
            </div>
          </div>
          <div class="divider" />
          <div class="text-md mb-5 font-bold text-base-content text-center md:text-left">
            Select an amount to InstaTip
          </div>

          <.insta_tip_button_group
            amounts={Enum.map(@amounts, &Decimal.to_string/1)}
            wallet_balance={@current_scope.wallet_balance}
            add_class="mb-4"
          />
          <.insta_tip_header wallet_balance={@current_scope.wallet_balance} />
        </div>
      </div>
    </div>

    <.insta_tip_modal
      show={@show_insta_tip_modal}
      recipient_name={(@recipient && @recipient.name) || "Recipient"}
      amount={@insta_tip_amount || Decimal.new("0.00")}
      current_balance={@current_scope.wallet_balance}
    />
    """
  end
end
