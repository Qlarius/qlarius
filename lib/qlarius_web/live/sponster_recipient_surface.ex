defmodule QlariusWeb.SponsterRecipientSurface do
  import Ecto.Query, except: [update: 2, update: 3]

  alias Qlarius.Repo
  alias Qlarius.Sponster.Offer
  alias Qlarius.Sponster.Offers
  alias Qlarius.Sponster.Recipients
  alias Qlarius.Wallets
  alias Qlarius.YouData.MeFiles.MeFile
  alias QlariusWeb.WalletBalanceSync

  import QlariusWeb.Widgets.UnauthCTA, only: [authed?: 1]

  @sponster_drawer_slide_ms 300
  @sponster_disclaimer_peek_pause_after_drawer_ms 650
  @disclaimer_dock_expand_ms 500
  @disclaimer_dock_hold_visible_ms 4000

  @sponster_events ~w(
    toggle_sponster_drawer
    close_sponster_drawer
    toggle_split_drawer
    initiate_insta_tip
    confirm_insta_tip
    cancel_insta_tip
    close-insta-tip-modal
    close-insta-tip-thanks-modal
    close-connect-modal
    open-connect-modal
    open_auth_sheet
    close_auth_sheet
    open-sponster-drawer
    switch_ad_type
    open_video_ad
    close_video_player
    video_watched_complete
    collect_video_payment
    video_collect_timeout
    replay_video
    daily-gift
    set_split
    split_reminder_dismiss
    refresh_offers
  )

  @doc "Split pct applied to ad collections; 0 on Tiqit (tip-only) pages."
  def ad_event_split_amount(socket) do
    if socket.assigns[:tip_only?] do
      0
    else
      (socket.assigns.current_scope.user.me_file &&
         socket.assigns.current_scope.user.me_file.split_amount) || 0
    end
  end

  def init_assigns(socket, recipient, opts \\ []) do
    tip_only? = Keyword.get(opts, :tip_only?, false)

    host_uri =
      case socket.host_uri do
        %URI{host: host} = uri when is_binary(host) -> uri
        _ -> URI.parse("https://qadabra.app")
      end

    me_file_sponsorship_url = Qlarius.Qlink.Urls.me_file_url_for_sponsorship(host_uri)

    settings_notifications_url =
      Qlarius.Qlink.Urls.settings_notifications_url_for_sponsorship(host_uri)

    socket
    |> Phoenix.Component.assign(:recipient, recipient)
    |> Phoenix.Component.assign(:tip_only?, tip_only?)
    |> Phoenix.Component.assign(:show_sponster_drawer, false)
    |> Phoenix.Component.assign(:selected_ad_type, "three_tap")
    |> Phoenix.Component.assign(:active_offers, [])
    |> Phoenix.Component.assign(:video_offers, [])
    |> Phoenix.Component.assign(:loading_offers, false)
    |> Phoenix.Component.assign(:offers_refresh_gen, 0)
    |> Phoenix.Component.assign(:show_video_player, false)
    |> Phoenix.Component.assign(:current_video_offer, nil)
    |> Phoenix.Component.assign(:video_watched_complete, false)
    |> Phoenix.Component.assign(:show_replay_button, false)
    |> Phoenix.Component.assign(:video_payment_collected, false)
    |> Phoenix.Component.assign(:completed_video_offers, [])
    |> Phoenix.Component.assign(:show_collection_drawer, false)
    |> Phoenix.Component.assign(:drawer_closing, false)
    |> Phoenix.Component.assign(:show_insta_tip_modal, false)
    |> Phoenix.Component.assign(:insta_tip_amount, nil)
    |> Phoenix.Component.assign(:insta_tip_recipient, nil)
    |> Phoenix.Component.assign(:show_insta_tip_thanks_modal, false)
    |> Phoenix.Component.assign(:insta_tip_thanks_amount, nil)
    |> Phoenix.Component.assign(:insta_tip_thanks_recipient, nil)
    |> Phoenix.Component.assign(:current_balance, get_current_balance(socket))
    |> Phoenix.Component.assign(:show_ad_type_tabs, false)
    |> Phoenix.Component.assign(:show_split_drawer, false)
    |> Phoenix.Component.assign(:show_split_reminder, false)
    |> Phoenix.Component.assign(:sponster_disclaimer_dock_visible, false)
    |> Phoenix.Component.assign(:sponster_disclaimer_dock_gen, 0)
    |> Phoenix.Component.assign(:host_uri, host_uri)
    |> Phoenix.Component.assign(:me_file_sponsorship_url, me_file_sponsorship_url)
    |> Phoenix.Component.assign(:settings_notifications_url, settings_notifications_url)
    |> Phoenix.Component.assign(:show_connect_modal, false)
    |> Phoenix.Component.assign(:connect_modal_brand, :tiqit)
    |> Phoenix.Component.assign(:show_auth_sheet, false)
    |> Phoenix.Component.assign(:auth_sheet_connect_brand, :qadabra)
  end

  def subscribe(socket) do
    socket = WalletBalanceSync.subscribe(socket)

    if socket.assigns.current_scope && socket.assigns.current_scope.user do
      Phoenix.PubSub.subscribe(Qlarius.PubSub, "user:#{socket.assigns.current_scope.user.id}")
    end

    socket
  end

  @doc "Opens the Sponster ad drawer if not already open (Qlink / Tiqit parent pages)."
  def open_drawer(socket) do
    if socket.assigns.show_sponster_drawer do
      socket
    else
      ensure_sponster_drawer_open(socket)
    end
  end

  def handle_event(event, params, socket) when event in @sponster_events do
    {:handled, do_handle_event(event, params, socket)}
  end

  def handle_event(_event, _params, _socket), do: :unhandled

  def handle_info({:open_auth_sheet, brand}, socket) do
    {:handled, open_auth_sheet(socket, brand)}
  end

  def handle_info(:open_sponster_drawer_from_embed, socket) do
    {:handled, open_drawer(socket)}
  end

  def handle_info(:show_collection_drawer, socket) do
    {:handled, Phoenix.Component.assign(socket, :show_collection_drawer, true)}
  end

  def handle_info(:auto_close_drawer, socket) do
    socket = Phoenix.Component.assign(socket, :drawer_closing, true)
    Process.send_after(self(), :finish_closing_drawer, 300)
    {:handled, socket}
  end

  def handle_info(:finish_closing_drawer, socket) do
    {:handled,
     socket
     |> Phoenix.Component.assign(:video_watched_complete, false)
     |> Phoenix.Component.assign(:show_collection_drawer, false)
     |> Phoenix.Component.assign(:drawer_closing, false)}
  end

  def handle_info({:sponster_disclaimer_dock_show, gen}, socket) do
    if socket.assigns[:sponster_disclaimer_dock_gen] == gen &&
         socket.assigns[:show_sponster_drawer] do
      {:handled, Phoenix.Component.assign(socket, :sponster_disclaimer_dock_visible, true)}
    else
      {:handled, socket}
    end
  end

  def handle_info({:sponster_disclaimer_dock_hide, gen}, socket) do
    if socket.assigns[:sponster_disclaimer_dock_gen] == gen do
      {:handled, Phoenix.Component.assign(socket, :sponster_disclaimer_dock_visible, false)}
    else
      {:handled, socket}
    end
  end

  def handle_info(:show_split_reminder, socket) do
    if socket.assigns[:tip_only?] do
      {:handled, socket}
    else
      Process.send_after(self(), :split_reminder_auto_hide, 5000)
      {:handled, Phoenix.Component.assign(socket, :show_split_reminder, true)}
    end
  end

  def handle_info(:split_reminder_auto_hide, socket) do
    if socket.assigns[:tip_only?] do
      {:handled, socket}
    else
      me_file = socket.assigns.current_scope.user.me_file

      socket =
        if me_file && socket.assigns.show_split_reminder do
          case MeFile.increment_split_reminder_shown(me_file) do
            {:ok, updated} ->
              current_scope =
                Map.put(
                  socket.assigns.current_scope,
                  :user,
                  Map.put(socket.assigns.current_scope.user, :me_file, updated)
                )

              socket
              |> Phoenix.Component.assign(:current_scope, current_scope)
              |> Phoenix.Component.assign(:show_split_reminder, false)

            {:error, _} ->
              Phoenix.Component.assign(socket, :show_split_reminder, false)
          end
        else
          Phoenix.Component.assign(socket, :show_split_reminder, false)
        end

      {:handled, socket}
    end
  end

  def handle_info({:me_file_pending_referral_clicks_updated, _count}, socket) do
    {:handled, socket}
  end

  def handle_info(:refresh_offers, socket) do
    socket =
      case socket.assigns[:current_scope] do
        %{user: %{me_file: %{id: me_file_id}}} when is_integer(me_file_id) ->
          Offers.refresh_statuses_for_me_file(me_file_id)

          socket
          |> Phoenix.Component.assign(
            :offers_refresh_gen,
            (socket.assigns[:offers_refresh_gen] || 0) + 1
          )
          |> load_offers(preserve_selected_ad_type: true)
          |> WalletBalanceSync.refresh_scope_stats()

        _ ->
          Phoenix.Component.assign(socket, :loading_offers, false)
      end

    {:handled, socket}
  end

  def handle_info(_msg, _socket), do: :unhandled

  defp do_handle_event("toggle_sponster_drawer", _params, socket) do
    if socket.assigns.show_sponster_drawer do
      socket
      |> Phoenix.Component.assign(:show_sponster_drawer, false)
      |> Phoenix.Component.assign(:show_split_reminder, false)
      |> Phoenix.Component.assign(:sponster_disclaimer_dock_visible, false)
      |> bump_sponster_disclaimer_dock_gen()
      |> request_offers_refresh()
    else
      ensure_sponster_drawer_open(socket)
    end
  end

  defp do_handle_event("close_sponster_drawer", _params, socket) do
    socket
    |> Phoenix.Component.assign(:show_sponster_drawer, false)
    |> Phoenix.Component.assign(:show_split_drawer, false)
    |> Phoenix.Component.assign(:show_split_reminder, false)
    |> Phoenix.Component.assign(:sponster_disclaimer_dock_visible, false)
    |> bump_sponster_disclaimer_dock_gen()
    |> request_offers_refresh()
  end

  defp do_handle_event("toggle_split_drawer", _params, socket) do
    will_open = !socket.assigns.show_split_drawer

    socket
    |> Phoenix.Component.assign(:show_split_drawer, will_open)
    |> Phoenix.Component.assign(:show_split_reminder, false)
    |> then(fn s ->
      if will_open && !s.assigns.show_sponster_drawer do
        s =
          if Enum.empty?(s.assigns.video_offers) && Enum.empty?(s.assigns.active_offers) &&
               s.assigns.current_scope do
            s
            |> Phoenix.Component.assign(:loading_offers, true)
            |> load_offers()
          else
            s
          end

        s
        |> Phoenix.Component.assign(:show_sponster_drawer, true)
        |> maybe_schedule_disclaimer_dock_peek()
      else
        s
      end
    end)
  end

  defp do_handle_event("split_reminder_dismiss", _params, socket) do
    if socket.assigns[:tip_only?] do
      Phoenix.Component.assign(socket, :show_split_reminder, false)
    else
      me_file = socket.assigns.current_scope.user.me_file

      if me_file do
        case MeFile.dismiss_split_reminder_forever(me_file) do
          {:ok, updated} ->
            current_scope =
              Map.put(
                socket.assigns.current_scope,
                :user,
                Map.put(socket.assigns.current_scope.user, :me_file, updated)
              )

            socket
            |> Phoenix.Component.assign(:current_scope, current_scope)
            |> Phoenix.Component.assign(:show_split_reminder, false)

          {:error, _} ->
            Phoenix.Component.assign(socket, :show_split_reminder, false)
        end
      else
        Phoenix.Component.assign(socket, :show_split_reminder, false)
      end
    end
  end

  defp do_handle_event("set_split", %{"split" => split}, socket) do
    if socket.assigns[:tip_only?] do
      socket
    else
      split_amount = String.to_integer(split)
      me_file = socket.assigns.current_scope.user.me_file

      case MeFile.update_me_file_split_amount(me_file, split_amount) do
        {:ok, updated_me_file} ->
          current_scope =
            Map.put(
              socket.assigns.current_scope,
              :user,
              Map.put(socket.assigns.current_scope.user, :me_file, updated_me_file)
            )

          Phoenix.Component.assign(socket, :current_scope, current_scope)

        {:error, _changeset} ->
          Phoenix.LiveView.put_flash(socket, :error, "Failed to update split amount")
      end
    end
  end

  defp do_handle_event("refresh_offers", _params, socket) do
    send(self(), :refresh_offers)

    Phoenix.Component.assign(socket, :loading_offers, true)
  end

  defp do_handle_event("switch_ad_type", %{"type" => ad_type}, socket) do
    Phoenix.Component.assign(socket, :selected_ad_type, ad_type)
  end

  defp do_handle_event("open_video_ad", %{"offer_id" => offer_id}, socket) do
    offer_id = String.to_integer(offer_id)

    {offer, _rate} =
      Enum.find(socket.assigns.video_offers, fn {o, _r} -> o.id == offer_id end)

    socket
    |> Phoenix.Component.assign(:current_video_offer, offer)
    |> Phoenix.Component.assign(:show_video_player, true)
    |> Phoenix.Component.assign(:video_watched_complete, false)
    |> Phoenix.Component.assign(:show_replay_button, false)
    |> Phoenix.Component.assign(:show_collection_drawer, false)
  end

  defp do_handle_event("close_video_player", _params, socket) do
    socket
    |> Phoenix.Component.assign(:show_video_player, false)
    |> Phoenix.Component.assign(:current_video_offer, nil)
    |> Phoenix.Component.assign(:video_watched_complete, false)
    |> Phoenix.Component.assign(:show_replay_button, false)
    |> Phoenix.Component.assign(:video_payment_collected, false)
    |> Phoenix.Component.assign(:show_collection_drawer, false)
  end

  defp do_handle_event("video_watched_complete", _params, socket) do
    already_collected =
      socket.assigns.current_video_offer.id in socket.assigns.completed_video_offers

    if already_collected do
      socket
    else
      socket = Phoenix.Component.assign(socket, :video_watched_complete, true)
      Process.send_after(self(), :show_collection_drawer, 100)
      socket
    end
  end

  defp do_handle_event("collect_video_payment", %{"offer_id" => offer_id}, socket) do
    offer_id = String.to_integer(offer_id)

    case Enum.find(socket.assigns.video_offers, fn {o, _r} -> o.id == offer_id end) do
      nil ->
        Phoenix.LiveView.put_flash(socket, :error, "Offer not found")

      {offer, _rate} ->
        recipient = socket.assigns.recipient
        split_amount = ad_event_split_amount(socket)
        user_ip = socket.assigns[:user_ip] || "0.0.0.0"

        case Qlarius.Sponster.Ads.Video.create_video_ad_event(
               offer,
               recipient,
               split_amount,
               user_ip
             ) do
          {:ok, _ad_event} ->
            completed_ids = [offer_id | socket.assigns.completed_video_offers]
            Process.send_after(self(), :auto_close_drawer, 3000)

            socket
            |> Phoenix.Component.assign(:video_watched_complete, false)
            |> Phoenix.Component.assign(:show_replay_button, false)
            |> Phoenix.Component.assign(:video_payment_collected, true)
            |> Phoenix.Component.assign(:completed_video_offers, completed_ids)

          {:error, _reason} ->
            Phoenix.LiveView.put_flash(socket, :error, "Failed to collect payment")
        end
    end
  end

  defp do_handle_event("video_collect_timeout", _params, socket) do
    Process.send_after(self(), :auto_close_drawer, 3000)

    socket
    |> Phoenix.Component.assign(:video_watched_complete, false)
    |> Phoenix.Component.assign(:show_replay_button, true)
    |> Phoenix.Component.assign(:show_collection_drawer, true)
  end

  defp do_handle_event("replay_video", _params, socket) do
    socket
    |> Phoenix.Component.assign(:show_replay_button, false)
    |> Phoenix.Component.assign(:video_payment_collected, false)
    |> Phoenix.Component.assign(:show_collection_drawer, false)
    |> Phoenix.Component.assign(:drawer_closing, false)
    |> Phoenix.LiveView.push_event("replay-video", %{})
  end

  defp do_handle_event("close-connect-modal", _params, socket) do
    Phoenix.Component.assign(socket, :show_connect_modal, false)
  end

  defp do_handle_event("open-connect-modal", params, socket) do
    brand = normalize_auth_sheet_connect_brand(params["brand"])

    socket
    |> Phoenix.Component.assign(:connect_modal_brand, brand)
    |> Phoenix.Component.assign(:show_connect_modal, true)
  end

  defp do_handle_event("open_auth_sheet", params, socket) do
    brand = normalize_auth_sheet_connect_brand(params["brand"])
    open_auth_sheet(socket, brand)
  end

  defp do_handle_event("close_auth_sheet", _params, socket) do
    socket
    |> Phoenix.Component.assign(:show_auth_sheet, false)
    |> Phoenix.Component.assign(:auth_sheet_connect_brand, :qadabra)
  end

  defp do_handle_event("open-sponster-drawer", _params, socket) do
    open_drawer(socket)
  end

  defp do_handle_event("daily-gift", _params, socket) do
    if authed?(socket.assigns.current_scope) do
      user = socket.assigns.current_scope.user

      case Wallets.claim_daily_gift(user) do
        {:ok, :credited} ->
          new_balance = Wallets.get_user_current_balance(user)
          WalletBalanceSync.broadcast_balance_change(user, new_balance)
          current_scope = Map.put(socket.assigns.current_scope, :wallet_balance, new_balance)

          socket
          |> Phoenix.Component.assign(:current_scope, current_scope)
          |> Phoenix.Component.assign(:current_balance, new_balance)
          |> WalletBalanceSync.forward_to_inline_embed(:update_balance)

        {:error, :cooldown} ->
          socket
          |> Phoenix.LiveView.put_flash(
            :error,
            "You already claimed your daily gift. Try again 24 hours after your last claim."
          )

        {:error, _} ->
          Phoenix.LiveView.put_flash(
            socket,
            :error,
            "Could not apply daily gift. Please try again."
          )
      end
    else
      Phoenix.Component.assign(socket, :show_connect_modal, true)
    end
  end

  defp do_handle_event("initiate_insta_tip", params, socket) do
    if authed?(socket.assigns.current_scope) do
      amount = Decimal.new(to_string(params["amount"]))
      recipient_id = params["recipient-id"] || params["recipient_id"]

      tip_recipient =
        if recipient_id do
          Recipients.get_recipient!(String.to_integer(recipient_id))
        else
          socket.assigns.recipient
        end

      socket
      |> Phoenix.Component.assign(:insta_tip_amount, amount)
      |> Phoenix.Component.assign(:insta_tip_recipient, tip_recipient)
      |> Phoenix.Component.assign(:show_insta_tip_modal, true)
      |> Phoenix.Component.assign(:current_balance, get_current_balance(socket))
    else
      Phoenix.Component.assign(socket, :show_connect_modal, true)
    end
  end

  defp do_handle_event("confirm_insta_tip", params, socket) do
    amount = Decimal.new(params["amount"])
    user = socket.assigns.current_scope.user
    recipient_id = params["recipient-id"] || params["recipient_id"]

    recipient =
      if recipient_id do
        Recipients.get_recipient!(String.to_integer(recipient_id))
      else
        socket.assigns[:insta_tip_recipient] || socket.assigns.recipient
      end

    case Wallets.create_insta_tip_request(user, recipient, amount, user) do
      {:ok, _ledger_event} ->
        new_balance = Decimal.sub(socket.assigns.current_scope.wallet_balance, amount)
        current_scope = Map.put(socket.assigns.current_scope, :wallet_balance, new_balance)

        socket
        |> Phoenix.Component.assign(:current_scope, current_scope)
        |> Phoenix.Component.assign(:current_balance, new_balance)
        |> WalletBalanceSync.forward_to_inline_embed(:update_balance)
        |> Phoenix.Component.assign(:show_insta_tip_modal, false)
        |> Phoenix.Component.assign(:insta_tip_amount, nil)
        |> Phoenix.Component.assign(:insta_tip_recipient, nil)
        |> Phoenix.Component.assign(:show_insta_tip_thanks_modal, true)
        |> Phoenix.Component.assign(:insta_tip_thanks_amount, amount)
        |> Phoenix.Component.assign(
          :insta_tip_thanks_recipient,
          (recipient && recipient.name) || "Recipient"
        )

      {:error, _changeset} ->
        socket
        |> Phoenix.Component.assign(:show_insta_tip_modal, false)
        |> Phoenix.Component.assign(:insta_tip_amount, nil)
        |> Phoenix.Component.assign(:insta_tip_recipient, nil)
        |> Phoenix.LiveView.put_flash(:error, "Failed to send InstaTip. Please try again.")
    end
  end

  defp do_handle_event("cancel_insta_tip", _params, socket) do
    socket
    |> Phoenix.Component.assign(:show_insta_tip_modal, false)
    |> Phoenix.Component.assign(:insta_tip_amount, nil)
  end

  defp do_handle_event("close-insta-tip-modal", _params, socket) do
    socket
    |> Phoenix.Component.assign(:show_insta_tip_modal, false)
    |> Phoenix.Component.assign(:insta_tip_amount, nil)
  end

  defp do_handle_event("close-insta-tip-thanks-modal", _params, socket) do
    socket
    |> Phoenix.Component.assign(:show_insta_tip_thanks_modal, false)
    |> Phoenix.Component.assign(:insta_tip_thanks_amount, nil)
    |> Phoenix.Component.assign(:insta_tip_thanks_recipient, nil)
  end

  defp request_offers_refresh(socket) do
    if socket.assigns[:current_scope] do
      send(self(), :refresh_offers)
    end

    socket
  end

  defp ensure_sponster_drawer_open(socket) do
    me_file =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.me_file

    socket
    |> then(fn s ->
      if Enum.empty?(s.assigns.video_offers) && s.assigns.current_scope do
        s
        |> Phoenix.Component.assign(:loading_offers, true)
        |> load_offers()
      else
        s
      end
    end)
    |> Phoenix.Component.assign(:show_sponster_drawer, true)
    |> Phoenix.Component.assign(:show_split_reminder, false)
    |> then(fn s ->
      if !s.assigns[:tip_only?] && me_file && MeFile.should_show_split_reminder?(me_file) do
        Process.send_after(self(), :show_split_reminder, 1500)
        s
      else
        s
      end
    end)
    |> maybe_schedule_disclaimer_dock_peek()
  end

  # Disclaimer peek fires on every page (Tiqit + Qlink) when the ad drawer opens.
  defp maybe_schedule_disclaimer_dock_peek(socket) do
    schedule_sponster_disclaimer_dock_peek(socket)
  end

  defp bump_sponster_disclaimer_dock_gen(socket) do
    Phoenix.Component.assign(
      socket,
      :sponster_disclaimer_dock_gen,
      (socket.assigns[:sponster_disclaimer_dock_gen] || 0) + 1
    )
  end

  defp schedule_sponster_disclaimer_dock_peek(socket) do
    if authed?(socket.assigns[:current_scope]) do
      gen = (socket.assigns[:sponster_disclaimer_dock_gen] || 0) + 1

      peek_show_ms = @sponster_drawer_slide_ms + @sponster_disclaimer_peek_pause_after_drawer_ms

      peek_hide_ms =
        peek_show_ms + @disclaimer_dock_expand_ms + @disclaimer_dock_hold_visible_ms

      Process.send_after(self(), {:sponster_disclaimer_dock_show, gen}, peek_show_ms)
      Process.send_after(self(), {:sponster_disclaimer_dock_hide, gen}, peek_hide_ms)

      socket
      |> Phoenix.Component.assign(:sponster_disclaimer_dock_gen, gen)
      |> Phoenix.Component.assign(:sponster_disclaimer_dock_visible, false)
    else
      socket
    end
  end

  defp load_offers(socket, opts \\ []) do
    case socket.assigns[:current_scope] do
      nil ->
        Phoenix.Component.assign(socket, :loading_offers, false)

      scope ->
        me_file_id = scope.user.me_file.id

        active_offers = Offers.list_current_three_tap_offers(me_file_id)

        video_query =
          from(o in Offer,
            join: mp in assoc(o, :media_piece),
            where:
              o.me_file_id == ^me_file_id and o.is_current == true and mp.media_piece_type_id == 2,
            preload: [media_run: [media_piece: :ad_category]]
          )

        video_offers = Repo.all(video_query)

        video_offers_with_rate =
          Enum.map(video_offers, fn offer ->
            duration = offer.media_run.media_piece.duration || 1
            rate = Decimal.div(offer.offer_amt || Decimal.new("0"), Decimal.new(duration))
            {offer, rate}
          end)
          |> Enum.sort_by(fn {_offer, rate} -> Decimal.to_float(rate) end, :desc)

        {show_tabs, default_selected_ad_type} =
          QlariusWeb.Components.AdsComponents.determine_ad_type_display(
            length(active_offers),
            length(video_offers_with_rate)
          )

        selected_ad_type =
          if Keyword.get(opts, :preserve_selected_ad_type, false) do
            preserve_selected_ad_type(
              socket.assigns[:selected_ad_type],
              length(active_offers),
              length(video_offers_with_rate),
              default_selected_ad_type
            )
          else
            default_selected_ad_type
          end

        socket
        |> Phoenix.Component.assign(:active_offers, active_offers)
        |> Phoenix.Component.assign(:video_offers, video_offers_with_rate)
        |> Phoenix.Component.assign(:show_ad_type_tabs, show_tabs)
        |> Phoenix.Component.assign(:selected_ad_type, selected_ad_type)
        |> Phoenix.Component.assign(:loading_offers, false)
    end
  end

  defp preserve_selected_ad_type("three_tap", three_tap_count, _video_count, _default)
       when three_tap_count > 0,
       do: "three_tap"

  defp preserve_selected_ad_type("video", _three_tap_count, video_count, _default)
       when video_count > 0,
       do: "video"

  defp preserve_selected_ad_type(_current, _three_tap_count, _video_count, default), do: default

  defp get_current_balance(socket) do
    case socket.assigns[:current_scope] do
      nil -> Decimal.new("0")
      scope -> Wallets.get_user_current_balance(scope.user)
    end
  end

  defp open_auth_sheet(socket, brand) do
    socket
    |> Phoenix.Component.assign(:show_auth_sheet, true)
    |> Phoenix.Component.assign(:show_connect_modal, false)
    |> Phoenix.Component.assign(
      :auth_sheet_connect_brand,
      normalize_auth_sheet_connect_brand(brand)
    )
  end

  defp normalize_auth_sheet_connect_brand(nil), do: :qadabra

  defp normalize_auth_sheet_connect_brand(b) when b in [:qadabra, :sponster, :tiqit],
    do: b

  defp normalize_auth_sheet_connect_brand(b) when is_binary(b) do
    case String.downcase(String.trim(b)) do
      "sponster" -> :sponster
      "tiqit" -> :tiqit
      "qadabra" -> :qadabra
      _ -> :qadabra
    end
  end

  defp normalize_auth_sheet_connect_brand(_), do: :qadabra
end
