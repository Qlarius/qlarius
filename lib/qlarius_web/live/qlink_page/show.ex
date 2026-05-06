defmodule QlariusWeb.QlinkPage.Show do
  use QlariusWeb, :live_view

  alias Qlarius.Qlink
  alias Qlarius.Repo
  alias Qlarius.Sponster.Offer
  alias Qlarius.Wallets
  alias Qlarius.Wallets.MeFileStatsBroadcaster

  import Ecto.Query, except: [update: 2, update: 3]
  import QlariusWeb.Money, only: [format_usd: 1]
  import QlariusWeb.Components.AdsComponents
  import QlariusWeb.Components.SplitComponents
  import QlariusWeb.InstaTipComponents
  # Shared "View anywhere, Act only when authed" helpers —
  # authed?/1, connect_wallet_modal/1, etc. Same module the arqade
  # widget consumes; keeps the anonymous-viewer UX consistent across
  # Qlink page + embedded widgets.
  import QlariusWeb.Widgets.UnauthCTA

  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.Browsers.InAppEscapeUrls

  on_mount {QlariusWeb.GetUserIP, :assign_ip}

  @arqade_fullpane_close_ms 300

  @impl true
  def mount(%{"alias" => page_alias}, _session, socket) do
    page =
      case Qlink.get_page_by_alias(page_alias) do
        nil -> nil
        p -> Repo.preload(p, [:recipient, creator: :users])
      end

    case page do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Page not found")
         |> redirect(to: ~p"/")}

      page ->
        if page.is_published or creator_viewing_own_page?(socket, page) do
          # Record page view only when WebSocket is connected (prevents double counting)
          if connected?(socket) do
            record_page_view(socket, page)
          end

          # Get links organized by section
          links = Qlink.list_visible_links(page.id)
          sections = Qlink.list_page_sections(page.id)

          socket =
            socket
            |> assign(:page, page)
            |> assign(:links, links)
            |> assign(:sections, sections)
            |> assign(:page_title, "Qlink | #{page.alias}")
            |> assign(:display_image, Qlink.get_display_image(page))
            |> assign(:recipient, page.recipient)
            |> assign(:arqade_fullpane_dom_id, nil)
            |> assign(:arqade_fullpane_closing?, false)
            |> assign(:arqade_fullpane_close_timer_ref, nil)
            |> assign_surface_context(page)
            |> assign_auth_referral_context(page)
            |> init_sponster_assigns()
            |> assign_in_app_escape_canonical()
            |> maybe_fire_iab_escape_shown_telemetry()

          # Subscribe to PubSub if authenticated and connected
          if connected?(socket) && socket.assigns.current_scope do
            subscribe_to_updates(socket)
          end

          {:ok, socket}
        else
          {:ok,
           socket
           |> put_flash(:error, "This page is not published yet")
           |> redirect(to: ~p"/")}
        end
    end
  end

  # The Qlink page has two public surfaces, both of which are now
  # interactive and auth-capable (B6):
  #
  #   * qlinkin.bio — the public vanity host. Hosts the `AuthSheet` for
  #     in-place sign-in behind the `:auth_sheet[:on_qlinkin_bio]`
  #     flag. Sessions set here are host-scoped (they do NOT share
  #     the `.qadabra.app` cookie — see `HostAwareSession`).
  #
  #   * qlink.qadabra.app (and localhost in dev) — the "interact" host.
  #     Hosts the `AuthSheet` behind `:auth_sheet[:on_qlink_page]`.
  #     Sessions set here are shared across `*.qadabra.app`.
  #
  # `auth_sheet_enabled?/1` picks the correct flag based on the
  # request host.
  #
  # `@interact_login_url` / `@interact_url` remain assigned because
  # they're still used as the flag-OFF fallback target in both templates
  # and by `UnauthCTA` components rendered in iframe embeds — those
  # surfaces continue to hand off cross-host until B8 retires the iframe
  # path. They're NOT used on qlinkin.bio when the AuthSheet flag is on.
  defp assign_surface_context(socket, page) do
    # `socket.host_uri` is populated by Phoenix.LiveView on BOTH the
    # dead HTTP render (from `Plug.Conn.request_url/1`) and the
    # connected LV mount (from the live channel's join URL), so it's
    # available uniformly across both phases — unlike
    # `get_connect_info/2`, which only returns a URI after LV connect
    # and would leave the dead render pointing at the stale stored
    # iframe URL.
    parent_uri =
      case socket.host_uri do
        %URI{host: host} = uri when is_binary(host) -> uri
        _ -> nil
      end

    socket
    # Used by `render_iframe_embed/2` to rewrite arqade widget iframe
    # hosts to match the parent page, so the shared `.qadabra.app`
    # cookie is sent on iframe requests. Also used by
    # `auth_sheet_enabled?/1` to pick the right per-host feature flag.
    |> assign(:parent_request_uri, parent_uri)
    |> assign(:interact_url, Qlarius.Qlink.Urls.interact_url(page.alias))
    |> assign(
      :interact_login_url,
      Qlarius.Qlink.Urls.interact_login_url("/@#{page.alias}")
    )
  end

  defp assign_in_app_escape_canonical(socket) do
    assign(socket, :in_app_escape_canonical_url, build_canonical_escape_url(socket))
  end

  # `socket.host_uri` only carries scheme/host/port, so we rebuild the
  # full Qlink URL from `page.alias` instead of trusting the URI's own
  # path (which is usually nil on connected mount and would collapse to
  # "/", landing the visitor on the homepage in the external browser).
  defp build_canonical_escape_url(socket) do
    uri =
      case socket.host_uri do
        %URI{host: h} = u when is_binary(h) ->
          u

        _ ->
          case socket.assigns[:parent_request_uri] do
            %URI{host: h} = u when is_binary(h) -> u
            _ -> nil
          end
      end

    page = socket.assigns[:page]

    case {uri, page} do
      {%URI{} = u, %{alias: alias_str}} when is_binary(alias_str) and alias_str != "" ->
        URI.to_string(%{u | path: "/@" <> alias_str})

      {%URI{} = u, _} ->
        URI.to_string(%{u | path: u.path || "/"})

      _ ->
        nil
    end
  end

  defp maybe_fire_iab_escape_shown_telemetry(socket) do
    iab = socket.assigns[:in_app_browser]
    url = socket.assigns[:in_app_escape_canonical_url]
    dismissed? = socket.assigns[:in_app_escape_dismissed] == true

    if connected?(socket) && iab && is_binary(url) && !dismissed? do
      :telemetry.execute(
        [:qlarius, :in_app_browser_escape, :gate_shown],
        %{},
        %{family: iab.family, os: iab.os}
      )
    end

    socket
  end

  defp iab_escape_target("ios", canonical),
    do: {:ok, InAppEscapeUrls.ios_open_in_system_browser(canonical)}

  defp iab_escape_target("android_intent", canonical) do
    {:ok, InAppEscapeUrls.android_chrome_intent(canonical) || canonical}
  end

  defp iab_escape_target("android_https", canonical), do: {:ok, canonical}
  defp iab_escape_target("https", canonical), do: {:ok, canonical}
  defp iab_escape_target(_, _), do: :error

  defp iab_escape_url_allowed?(url) when is_binary(url) do
    String.starts_with?(url, "x-safari-https://") or
      String.starts_with?(url, "x-safari-http://") or
      String.starts_with?(url, "intent://") or
      String.starts_with?(url, "https://") or
      String.starts_with?(url, "http://")
  end

  defp iab_escape_url_allowed?(_), do: false

  defp init_sponster_assigns(socket) do
    host_uri =
      case get_connect_info(socket, :uri) do
        nil -> URI.parse("http://localhost")
        uri -> uri
      end

    socket
    |> assign(:show_sponster_drawer, false)
    |> assign(:selected_ad_type, "three_tap")
    |> assign(:active_offers, [])
    |> assign(:video_offers, [])
    |> assign(:loading_offers, false)
    |> assign(:show_video_player, false)
    |> assign(:current_video_offer, nil)
    |> assign(:video_watched_complete, false)
    |> assign(:show_replay_button, false)
    |> assign(:video_payment_collected, false)
    |> assign(:completed_video_offers, [])
    |> assign(:show_collection_drawer, false)
    |> assign(:drawer_closing, false)
    |> assign(:show_insta_tip_modal, false)
    |> assign(:insta_tip_amount, nil)
    |> assign(:insta_tip_recipient, nil)
    |> assign(:show_insta_tip_thanks_modal, false)
    |> assign(:insta_tip_thanks_amount, nil)
    |> assign(:insta_tip_thanks_recipient, nil)
    |> assign(:current_balance, get_current_balance(socket))
    |> assign(:show_ad_type_tabs, false)
    |> assign(:show_split_drawer, false)
    |> assign(:show_split_reminder, false)
    |> assign(:host_uri, host_uri)
    |> assign(:show_connect_modal, false)
    |> assign(:show_auth_sheet, false)
  end

  defp get_current_balance(socket) do
    case socket.assigns[:current_scope] do
      nil -> Decimal.new("0")
      scope -> Wallets.get_user_current_balance(scope.user)
    end
  end

  defp subscribe_to_updates(socket) do
    if socket.assigns.current_scope && socket.assigns.current_scope.user do
      me_file = socket.assigns.current_scope.user.me_file

      if me_file do
        MeFileStatsBroadcaster.subscribe_to_me_file_stats(me_file.id)
        Phoenix.PubSub.subscribe(Qlarius.PubSub, "user:#{socket.assigns.current_scope.user.id}")
      end
    end
  end

  @impl true
  def handle_event("iab_escape_dismiss", _params, socket) do
    :telemetry.execute([:qlarius, :in_app_browser_escape, :dismissed], %{}, %{})

    {:noreply,
     socket
     |> assign(:in_app_escape_dismissed, true)
     |> push_event("iab_escape_store_dismiss", %{})}
  end

  @impl true
  def handle_event("iab_escape_client_dismissed", _params, socket) do
    {:noreply, assign(socket, :in_app_escape_dismissed, true)}
  end

  @impl true
  def handle_event("iab_escape_open_external", %{"kind" => kind}, socket) do
    canonical = socket.assigns[:in_app_escape_canonical_url]

    with true <- is_binary(canonical),
         {:ok, target} <- iab_escape_target(kind, canonical),
         true <- iab_escape_url_allowed?(target) do
      :telemetry.execute(
        [:qlarius, :in_app_browser_escape, :open_external],
        %{},
        %{kind: kind}
      )

      {:noreply, redirect(socket, external: target)}
    else
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("link_click", %{"link_id" => link_id}, socket) do
    # Record link click
    link = Qlink.get_link!(link_id)

    Qlink.record_link_click(%{
      qlink_page_id: socket.assigns.page.id,
      qlink_link_id: link_id,
      visitor_fingerprint: get_visitor_fingerprint(socket),
      session_id: get_session_id(socket),
      referer: get_referer(socket),
      user_agent: get_user_agent(socket)
    })

    # Redirect to the link URL
    {:noreply, redirect(socket, external: link.url)}
  end

  # Sponster drawer toggle (ad drawer)
  @impl true
  def handle_event("close-arqade-fullpane", _params, socket) do
    {:noreply, begin_arqade_fullpane_close(socket)}
  end

  def handle_event("toggle_sponster_drawer", _params, socket) do
    will_open = !socket.assigns.show_sponster_drawer

    me_file =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.me_file

    socket =
      socket
      |> then(fn s ->
        if will_open && Enum.empty?(s.assigns.video_offers) && s.assigns.current_scope do
          s
          |> assign(:loading_offers, true)
          |> load_offers()
        else
          s
        end
      end)
      |> assign(:show_sponster_drawer, will_open)
      |> assign(:show_split_reminder, false)
      |> then(fn s ->
        if will_open && me_file && MeFile.should_show_split_reminder?(me_file) do
          Process.send_after(self(), :show_split_reminder, 1500)
          s
        else
          s
        end
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_sponster_drawer", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_sponster_drawer, false)
     |> assign(:show_split_drawer, false)
     |> assign(:show_split_reminder, false)}
  end

  @impl true
  def handle_event("toggle_split_drawer", _params, socket) do
    will_open = !socket.assigns.show_split_drawer

    socket =
      socket
      |> assign(:show_split_drawer, will_open)
      |> assign(:show_split_reminder, false)
      |> then(fn s ->
        if will_open && !s.assigns.show_sponster_drawer do
          s =
            if Enum.empty?(s.assigns.video_offers) && Enum.empty?(s.assigns.active_offers) &&
                 s.assigns.current_scope do
              s
              |> assign(:loading_offers, true)
              |> load_offers()
            else
              s
            end

          assign(s, :show_sponster_drawer, true)
        else
          s
        end
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("split_reminder_dismiss", _params, socket) do
    me_file = socket.assigns.current_scope.user.me_file

    socket =
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
            |> assign(:current_scope, current_scope)
            |> assign(:show_split_reminder, false)

          {:error, _} ->
            assign(socket, :show_split_reminder, false)
        end
      else
        assign(socket, :show_split_reminder, false)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("set_split", %{"split" => split}, socket) do
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

        {:noreply, assign(socket, :current_scope, current_scope)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update split amount")}
    end
  end

  @impl true
  def handle_event("switch_ad_type", %{"type" => ad_type}, socket) do
    {:noreply, assign(socket, :selected_ad_type, ad_type)}
  end

  @impl true
  def handle_event("open_video_ad", %{"offer_id" => offer_id}, socket) do
    offer_id = String.to_integer(offer_id)

    {offer, _rate} =
      Enum.find(socket.assigns.video_offers, fn {o, _r} -> o.id == offer_id end)

    {:noreply,
     socket
     |> assign(:current_video_offer, offer)
     |> assign(:show_video_player, true)
     |> assign(:video_watched_complete, false)
     |> assign(:show_replay_button, false)
     |> assign(:show_collection_drawer, false)}
  end

  @impl true
  def handle_event("close_video_player", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_video_player, false)
     |> assign(:current_video_offer, nil)
     |> assign(:video_watched_complete, false)
     |> assign(:show_replay_button, false)
     |> assign(:video_payment_collected, false)
     |> assign(:show_collection_drawer, false)}
  end

  @impl true
  def handle_event("video_watched_complete", _params, socket) do
    already_collected =
      socket.assigns.current_video_offer.id in socket.assigns.completed_video_offers

    if already_collected do
      {:noreply, socket}
    else
      socket = assign(socket, :video_watched_complete, true)
      Process.send_after(self(), :show_collection_drawer, 100)
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("collect_video_payment", %{"offer_id" => offer_id}, socket) do
    offer_id = String.to_integer(offer_id)

    case Enum.find(socket.assigns.video_offers, fn {o, _r} -> o.id == offer_id end) do
      nil ->
        {:noreply, put_flash(socket, :error, "Offer not found")}

      {offer, _rate} ->
        recipient = socket.assigns.recipient
        split_amount = socket.assigns.current_scope.user.me_file.split_amount || 0
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

            {:noreply,
             socket
             |> assign(:video_watched_complete, false)
             |> assign(:show_replay_button, false)
             |> assign(:video_payment_collected, true)
             |> assign(:completed_video_offers, completed_ids)}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Failed to collect payment")}
        end
    end
  end

  @impl true
  def handle_event("video_collect_timeout", _params, socket) do
    Process.send_after(self(), :auto_close_drawer, 3000)

    {:noreply,
     socket
     |> assign(:video_watched_complete, false)
     |> assign(:show_replay_button, true)
     |> assign(:show_collection_drawer, true)}
  end

  @impl true
  def handle_event("replay_video", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_replay_button, false)
     |> assign(:video_payment_collected, false)
     |> assign(:show_collection_drawer, false)
     |> assign(:drawer_closing, false)
     |> push_event("replay-video", %{})}
  end

  # Close the shared Connect-wallet modal. Symmetric with the
  # `phx-click` inside `connect_wallet_modal/1`'s "Keep browsing"
  # button.
  @impl true
  def handle_event("close-connect-modal", _params, socket) do
    {:noreply, assign(socket, :show_connect_modal, false)}
  end

  # AuthSheet open/close. Gated behind `:auth_sheet[:on_qlink_page]` —
  # when the flag is off, the FAB falls back to the legacy `/login`
  # redirect and these events never fire.
  def handle_event("open_auth_sheet", _params, socket) do
    {:noreply, open_auth_sheet(socket)}
  end

  def handle_event("close_auth_sheet", _params, socket) do
    {:noreply, assign(socket, :show_auth_sheet, false)}
  end

  # InstaTip events
  @impl true
  def handle_event("initiate_insta_tip", params, socket) do
    # Anonymous viewers see the full tip-button grid so they can
    # explore the interaction — but the tip itself requires a
    # connected wallet. Intercept and show the Connect modal
    # instead of opening the confirm modal.
    if authed?(socket.assigns.current_scope) do
      amount = Decimal.new(to_string(params["amount"]))
      recipient_id = params["recipient-id"] || params["recipient_id"]

      # Look up the recipient for the modal
      tip_recipient =
        if recipient_id do
          Qlarius.Sponster.Recipients.get_recipient!(String.to_integer(recipient_id))
        else
          socket.assigns.recipient
        end

      socket =
        socket
        |> assign(:insta_tip_amount, amount)
        |> assign(:insta_tip_recipient, tip_recipient)
        |> assign(:show_insta_tip_modal, true)
        |> assign(:current_balance, get_current_balance(socket))

      {:noreply, socket}
    else
      {:noreply, assign(socket, :show_connect_modal, true)}
    end
  end

  @impl true
  def handle_event("confirm_insta_tip", params, socket) do
    amount = Decimal.new(params["amount"])
    user = socket.assigns.current_scope.user
    recipient_id = params["recipient-id"] || params["recipient_id"]

    # Use the stored tip recipient or look it up
    recipient =
      if recipient_id do
        Qlarius.Sponster.Recipients.get_recipient!(String.to_integer(recipient_id))
      else
        socket.assigns[:insta_tip_recipient] || socket.assigns.recipient
      end

    case Wallets.create_insta_tip_request(user, recipient, amount, user) do
      {:ok, _ledger_event} ->
        Process.send_after(self(), :close_insta_tip_thanks_modal, 3000)
        new_balance = Decimal.sub(socket.assigns.current_scope.wallet_balance, amount)
        current_scope = Map.put(socket.assigns.current_scope, :wallet_balance, new_balance)

        {:noreply,
         socket
         |> assign(:current_scope, current_scope)
         |> assign(:current_balance, new_balance)
         |> assign(:show_insta_tip_modal, false)
         |> assign(:insta_tip_amount, nil)
         |> assign(:insta_tip_recipient, nil)
         |> assign(:show_insta_tip_thanks_modal, true)
         |> assign(:insta_tip_thanks_amount, amount)
         |> assign(:insta_tip_thanks_recipient, (recipient && recipient.name) || "Recipient")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:show_insta_tip_modal, false)
         |> assign(:insta_tip_amount, nil)
         |> assign(:insta_tip_recipient, nil)
         |> put_flash(:error, "Failed to send InstaTip. Please try again.")}
    end
  end

  @impl true
  def handle_event("cancel_insta_tip", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_insta_tip_modal, false)
     |> assign(:insta_tip_amount, nil)}
  end

  @impl true
  def handle_event("close-insta-tip-modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_insta_tip_modal, false)
     |> assign(:insta_tip_amount, nil)}
  end

  @impl true
  def handle_event("close-insta-tip-thanks-modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_insta_tip_thanks_modal, false)
     |> assign(:insta_tip_thanks_amount, nil)
     |> assign(:insta_tip_thanks_recipient, nil)}
  end

  # Handle info callbacks
  @impl true
  # Forwarded from a nested arcade LV when its Connect-wallet CTA is
  # clicked (see `ArcadeLive.handle_event("open_auth_sheet", …)`).
  # The nested LV sends this via `send(socket.parent_pid, …)` instead
  # of mounting its own `AuthSheet` so the page never stacks two
  # sheet instances.
  def handle_info(:open_auth_sheet, socket) do
    {:noreply, open_auth_sheet(socket)}
  end

  @impl true
  def handle_info({:arqade_fullpane_toggle, dom_id}, socket) when is_binary(dom_id) do
    current = socket.assigns[:arqade_fullpane_dom_id]
    closing? = socket.assigns[:arqade_fullpane_closing?] == true

    cond do
      closing? && current == dom_id ->
        {:noreply, cancel_arqade_fullpane_close_timer(socket)}

      current == dom_id && not closing? ->
        {:noreply, begin_arqade_fullpane_close(socket)}

      true ->
        socket = if closing?, do: cancel_arqade_fullpane_close_timer(socket), else: socket
        {:noreply, assign(socket, :arqade_fullpane_dom_id, dom_id)}
    end
  end

  def handle_info(:arqade_fullpane_close_done, socket) do
    if socket.assigns[:arqade_fullpane_closing?] == true do
      {:noreply,
       socket
       |> assign(:arqade_fullpane_dom_id, nil)
       |> assign(:arqade_fullpane_closing?, false)
       |> assign(:arqade_fullpane_close_timer_ref, nil)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(:close_insta_tip_thanks_modal, socket) do
    {:noreply,
     socket
     |> assign(:show_insta_tip_thanks_modal, false)
     |> assign(:insta_tip_thanks_amount, nil)
     |> assign(:insta_tip_thanks_recipient, nil)}
  end

  @impl true
  def handle_info(:show_collection_drawer, socket) do
    {:noreply, assign(socket, :show_collection_drawer, true)}
  end

  @impl true
  def handle_info(:auto_close_drawer, socket) do
    socket = assign(socket, :drawer_closing, true)
    Process.send_after(self(), :finish_closing_drawer, 300)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:finish_closing_drawer, socket) do
    {:noreply,
     socket
     |> assign(:video_watched_complete, false)
     |> assign(:show_collection_drawer, false)
     |> assign(:drawer_closing, false)}
  end

  @impl true
  def handle_info(:show_split_reminder, socket) do
    Process.send_after(self(), :split_reminder_auto_hide, 5000)
    {:noreply, assign(socket, :show_split_reminder, true)}
  end

  @impl true
  def handle_info(:split_reminder_auto_hide, socket) do
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
            |> assign(:current_scope, current_scope)
            |> assign(:show_split_reminder, false)

          {:error, _} ->
            assign(socket, :show_split_reminder, false)
        end
      else
        assign(socket, :show_split_reminder, false)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:me_file_balance_updated, new_balance}, socket) do
    if socket.assigns[:current_scope] do
      current_scope = Map.put(socket.assigns.current_scope, :wallet_balance, new_balance)

      {:noreply,
       socket
       |> assign(:current_scope, current_scope)
       |> assign(:current_balance, new_balance)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:me_file_offers_updated, _me_file_id}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:me_file_pending_referral_clicks_updated, _count}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:refresh_wallet_balance, _me_file_id}, socket) do
    if socket.assigns[:current_scope] do
      new_balance =
        Wallets.get_me_file_ledger_header_balance(socket.assigns.current_scope.user.me_file)

      current_scope = Map.put(socket.assigns.current_scope, :wallet_balance, new_balance)
      {:noreply, assign(socket, :current_scope, current_scope)}
    else
      {:noreply, socket}
    end
  end

  defp load_offers(socket) do
    case socket.assigns[:current_scope] do
      nil ->
        assign(socket, :loading_offers, false)

      scope ->
        me_file_id = scope.user.me_file.id

        # Load 3-tap offers
        three_tap_query =
          from(o in Offer,
            join: mp in assoc(o, :media_piece),
            where:
              o.me_file_id == ^me_file_id and o.is_current == true and mp.media_piece_type_id == 1,
            order_by: [desc: o.offer_amt],
            preload: [media_piece: :ad_category]
          )

        active_offers =
          three_tap_query
          |> Repo.all()
          |> Enum.map(fn offer -> {offer, 0} end)

        # Load video offers
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

        # Use shared helper to determine tab visibility and default ad type
        {show_tabs, selected_ad_type} =
          QlariusWeb.Components.AdsComponents.determine_ad_type_display(
            length(active_offers),
            length(video_offers_with_rate)
          )

        socket
        |> assign(:active_offers, active_offers)
        |> assign(:video_offers, video_offers_with_rate)
        |> assign(:show_ad_type_tabs, show_tabs)
        |> assign(:selected_ad_type, selected_ad_type)
        |> assign(:loading_offers, false)
    end
  end

  defp creator_viewing_own_page?(socket, page) do
    case socket.assigns[:current_scope] do
      nil ->
        false

      scope ->
        # Check both current user and true_user (for proxy user scenarios)
        user_ids_to_check =
          [scope.user.id, Map.get(scope, :true_user) && scope.true_user.id]
          |> Enum.reject(&is_nil/1)

        Enum.any?(page.creator.users, fn creator_user ->
          creator_user.id in user_ids_to_check
        end)
    end
  end

  defp record_page_view(socket, page) do
    Qlink.record_page_view(%{
      qlink_page_id: page.id,
      event_type: :page_view,
      visitor_fingerprint: get_visitor_fingerprint(socket),
      session_id: get_session_id(socket),
      referer: get_referer(socket),
      user_agent: get_user_agent(socket)
    })
  end

  defp get_visitor_fingerprint(socket) do
    # Simple fingerprint based on IP and user agent
    ip =
      case get_connect_info(socket, :peer_data) do
        %{address: address} when is_tuple(address) ->
          :inet.ntoa(address) |> to_string()

        _ ->
          case get_connect_info(socket, :x_headers) do
            headers when is_list(headers) ->
              # Try to get IP from X-Forwarded-For or X-Real-IP headers
              forwarded_for =
                Enum.find_value(headers, fn {k, v} ->
                  if String.downcase(to_string(k)) == "x-forwarded-for", do: v
                end) ||
                  Enum.find_value(headers, fn {k, v} ->
                    if String.downcase(to_string(k)) == "x-real-ip", do: v
                  end)

              forwarded_for || "unknown"

            _ ->
              "unknown"
          end
      end

    user_agent = get_user_agent(socket)
    :crypto.hash(:sha256, "#{ip}#{user_agent}") |> Base.encode16()
  end

  defp get_session_id(socket) do
    # Use LiveView session ID
    socket.id
  end

  defp get_referer(socket) do
    case get_connect_info(socket, :uri) do
      nil -> nil
      %{query: query} -> query
      _ -> nil
    end
  end

  defp get_user_agent(socket) do
    case get_connect_info(socket, :user_agent) do
      nil -> "unknown"
      ua -> ua
    end
  end

  # Template helpers

  defp get_theme(_page) do
    # Qlink surfaces are light-only for now (no dark page shell). Re-enable
    # per-page `theme_config["theme"]` when Qlink dark theme is product-ready.
    "light"
  end

  defp get_background_style(page) do
    case page.background_config do
      %{"type" => "image", "value" => url} ->
        "background-image: url('#{url}'); background-size: cover; background-position: center;"

      %{"type" => "gradient", "value" => gradient} ->
        "background: #{gradient};"

      %{"type" => "solid", "value" => color} ->
        "background-color: #{color};"

      _ ->
        ""
    end
  end

  defp get_social_icon_path(platform) do
    case platform do
      "twitter" -> "/images/social-icons/x.svg"
      "instagram" -> "/images/social-icons/instagram.svg"
      "facebook" -> "/images/social-icons/facebook.svg"
      "linkedin" -> "/images/social-icons/linkedin.svg"
      "youtube" -> "/images/social-icons/youtube.svg"
      "tiktok" -> "/images/social-icons/tiktok.svg"
      "github" -> "/images/social-icons/github.svg"
      _ -> nil
    end
  end

  @doc """
  One column of the Sponster announcer-bar stats box (WALLET / ADS /
  OFFERED). Kept as a component so the authed and anon branches of
  the bar can share exact markup — only the wrapping element
  (`<div>` vs. `<.link>`) and the values differ.
  """
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :value_class, :string, required: true

  def sponster_stat_cell(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center w-full" style="padding: 6px 0;">
      <div
        class={@value_class}
        style="font-size: 16px; line-height: 16px; letter-spacing: 0.4px;"
      >
        {@value}
      </div>
      <div
        class="text-base-content/40 font-medium"
        style="font-size: 8px; line-height: 10px; letter-spacing: 0.2px;"
      >
        {@label}
      </div>
    </div>
    """
  end

  attr :link, :map, required: true
  attr :recipient, :map, default: nil
  attr :current_scope, :map, default: nil
  # `socket` is forwarded from the parent LV so embed renderers can
  # call `Phoenix.LiveView.live_render/3` (required for inline arqade
  # widgets — see `render_embed/1`). Function components don't
  # receive `@socket` automatically; callers must pass it explicitly.
  attr :socket, :any, default: nil
  # JS command threaded through to embedded widgets' Connect-wallet
  # CTAs (currently just `insta_tip_card`'s wallet strip). Computed
  # at the template call site where the full parent assigns (incl.
  # `@parent_request_uri` for per-host flag resolution) are in scope —
  # `nil` falls back to the legacy cross-host redirect on the
  # embedded `wallet_strip_or_connect/1`. Mirrors the pattern used
  # by arcade's `on_click` wiring.
  attr :on_auth_click, Phoenix.LiveView.JS, default: nil

  # Passed from `show.html.heex` — do not read from `socket.assigns[...]`
  # here: during static render `socket.assigns` is `AssignsNotInSocket`
  # and does not implement Access.
  attr :arqade_fullpane_dom_id, :any, default: nil
  attr :arqade_fullpane_closing?, :boolean, default: false

  def render_link(assigns) do
    cond do
      assigns.link.type == :insta_tip ->
        render_insta_tip_block(assigns)

      assigns.link.type == :embed && assigns.link.embed_config ->
        render_embed(assigns)

      true ->
        render_standard_link(assigns)
    end
  end

  defp render_insta_tip_block(assigns) do
    # Use the block's recipient, not the page recipient
    block_recipient = assigns.link.recipient
    show_header = assigns.link.show_tip_header != false

    assigns =
      assigns
      |> assign(:block_recipient, block_recipient)
      |> assign(:show_header, show_header)

    # Render the full insta_tip_card (image + message + amount
    # buttons + wallet footer) for everyone, authed or not.
    # Anonymous viewers get the same UI with `wallet_balance: nil`;
    # the card shows `$--.--` in the footer and the amount buttons
    # remain clickable. The `initiate_insta_tip` LV handler
    # intercepts unauth clicks and opens the shared Connect-wallet
    # modal instead of proceeding to confirm.
    ~H"""
    <div class="w-full rounded-2xl border border-neutral/50 overflow-hidden">
      <%= cond do %>
        <% is_nil(@block_recipient) -> %>
          <div class="text-center py-8">
            <span class="text-warning">Tip recipient not configured</span>
          </div>
        <% true -> %>
          <.insta_tip_card
            recipient={@block_recipient}
            scope={@current_scope}
            wallet_balance={@current_scope && @current_scope.wallet_balance}
            offered_amount={@current_scope && @current_scope.offered_amount}
            ads_count={@current_scope && @current_scope.ads_count}
            show_image={@show_header}
            show_message={@show_header}
            wallet_strip_id={"wallet-balance-tipjar-#{@link.id}"}
            on_auth_click={@on_auth_click}
          />
      <% end %>
    </div>
    """
  end

  attr :link, :map, required: true

  defp render_standard_link(assigns) do
    ~H"""
    <a
      href={@link.url}
      target="_blank"
      rel="noopener noreferrer"
      class="block w-full rounded-full bg-base-200 hover:bg-base-300 transition-colors border border-neutral/30"
      style="padding: 1.25rem 1.5rem !important;"
    >
      <div class="flex items-center gap-4 w-full">
        <%= if @link.icon do %>
          <span class="text-2xl flex-shrink-0">{@link.icon}</span>
        <% end %>
        <div class="flex-1 text-left min-w-0">
          <div class="font-semibold">{@link.title}</div>
          <%= if @link.description do %>
            <div class="text-sm opacity-70">{@link.description}</div>
          <% end %>
        </div>
        <%= if @link.thumbnail do %>
          <img src={@link.thumbnail} alt="" class="w-12 h-12 rounded object-cover flex-shrink-0" />
        <% end %>
      </div>
    </a>
    """
  end

  attr :link, :map, required: true

  defp render_embed(assigns) do
    embed_config = assigns.link.embed_config

    platform = get_embed_platform(embed_config)

    video_id =
      get_embed_value(embed_config, "video_id") || get_embed_value(embed_config, :video_id)

    content_id =
      get_embed_value(embed_config, "content_id") || get_embed_value(embed_config, :content_id)

    # For iframe embeds the admin form's `url` field is the source of
    # truth — it's what creators see and edit. `embed_config.url` is
    # a denormalized copy written by `QlinkLink.parse_embed_config/1`
    # at save time, and it can drift out of sync with `link.url` when
    # the auto-detect pathway falls back to the existing embed_config
    # (see `QlinkLink.same_domain_url?/1`). Prefer `link.url` here so
    # render always reflects the latest admin value, and fall back to
    # the denormalized copy only if `link.url` is missing.
    iframe_url =
      assigns.link.url ||
        get_embed_value(embed_config, "url") ||
        get_embed_value(embed_config, :url)

    case platform do
      "youtube" when not is_nil(video_id) ->
        render_youtube_embed(assigns, video_id)

      "spotify" when not is_nil(content_id) ->
        render_spotify_embed(assigns, content_id)

      "tiktok" when not is_nil(video_id) ->
        render_tiktok_embed(assigns, video_id)

      "iframe" when not is_nil(iframe_url) ->
        # For arqade widgets served by this deployment on the
        # interactive surface, render as a nested LiveView via
        # `live_render/3`. The nested LV shares the same auth scope
        # and wallet PubSub as the page, so balance/wallet updates
        # flow through naturally — no iframe, no cross-origin cookie
        # handshake, no extra network hop. Third-party embeds and
        # the anonymous share surface (qlinkin.bio) still use the
        # iframe path.
        cond do
          inline_arqade_candidate?(assigns, iframe_url) ->
            render_inline_arqade(assigns, iframe_url)

          true ->
            render_iframe_embed(assigns, iframe_url)
        end

      _ ->
        render_standard_link(assigns)
    end
  end

  # Inline rendering is the preferred path for every own-deployment
  # arqade widget on both the interactive host (qlink.qadabra.app)
  # AND the anonymous share surface (qlinkin.bio). The parent
  # QlinkPage.Show LV is already mounted on qlinkin.bio (via the
  # `:qlink_anon` live_session) and opens a WebSocket either way,
  # so a nested LV costs nothing extra — it rides the same socket.
  # The iframe path, by contrast, spawns a second LV process on the
  # widget origin and forces the `normalize_widget_iframe_url/2`
  # cross-origin cookie dance, which is pointless on qlinkin.bio
  # (no auth to propagate) and strictly overhead on qlink.qadabra.app.
  #
  # Gates:
  #   1. URL parses as an arqade widget on a host in our deployment
  #      family (see `Qlarius.Qlink.Urls.own_deployment_arqade_url?/1`).
  #      Third-party arqade-looking URLs would still iframe.
  #   2. `@socket` is present — required to call `live_render/3`.
  #      Passed from the parent LV via
  #      `<.render_link socket={@socket} ...>` since function
  #      components don't receive `@socket` automatically.
  #
  # TODO(arqade-block): today the arqade ↔ Qlink binding is a pasted
  # URL in a generic `:embed` block; we parse it back out here. Once
  # we add a first-class `:arqade` link type with FKs to
  # content_catalog / content_group / content_piece (see
  # docs/qlink_arqade_block_followup.md), this URL-parsing dance
  # goes away and we dispatch directly on the FK.
  defp inline_arqade_candidate?(assigns, iframe_url) do
    not is_nil(assigns[:socket]) and
      Qlarius.Qlink.Urls.own_deployment_arqade_url?(iframe_url)
  end

  # Resolves the arqade widget type + id from the stored URL, then
  # dispatches to the appropriate LiveView via `live_render/3`. The
  # nested LV inherits the parent page's session (so auth flows
  # through) and is handed a `session:` map that signals inline
  # mode + carries the `content_id` / `force_theme` / `show_title`
  # values that would otherwise arrive as query params on the
  # standalone widget URL.
  defp render_inline_arqade(assigns, iframe_url) do
    case Qlarius.Qlink.Urls.parse_arqade_widget_url(iframe_url) do
      {:ok, {:group, group_id}} ->
        render_inline_arqade_live(assigns, QlariusWeb.Widgets.Arcade.ArcadeLive,
          path: build_widget_path(iframe_url, "/widgets/arqade/group/#{group_id}"),
          session_params: %{"group_id" => group_id},
          dom_id: "inline-arqade-group-#{group_id}-link-#{assigns.link.id}"
        )

      {:ok, {:single, piece_id}} ->
        render_inline_arqade_live(assigns, QlariusWeb.Widgets.Arcade.ArcadeSingleLive,
          path: build_widget_path(iframe_url, "/widgets/arqade/#{piece_id}"),
          session_params: %{"piece_id" => piece_id},
          dom_id: "inline-arqade-piece-#{piece_id}-link-#{assigns.link.id}"
        )

      # Catalog and discovery arqade URLs don't have a dedicated LV
      # yet (they're rendered by the standalone widget controller).
      # Fall through to the iframe path so creators keep a working
      # embed until those are inlined.
      _ ->
        render_iframe_embed(assigns, iframe_url)
    end
  end

  # Preserves the original URL's query string (e.g. `?force_theme=dark`)
  # when handing a path to `render_inline_arqade_live`, so
  # `extract_query_params/1` can recover `force_theme` / `content_id`
  # from it. The standalone URL path itself is otherwise irrelevant
  # inline (the nested LV is mounted via `live_render/3`, not routed).
  defp build_widget_path(iframe_url, default_path) do
    case URI.parse(iframe_url) do
      %URI{query: q} when is_binary(q) and q != "" -> default_path <> "?" <> q
      _ -> default_path
    end
  end

  defp begin_arqade_fullpane_close(socket) do
    cond do
      is_nil(socket.assigns[:arqade_fullpane_dom_id]) ->
        socket

      socket.assigns[:arqade_fullpane_closing?] == true ->
        socket

      true ->
        ref = Process.send_after(self(), :arqade_fullpane_close_done, @arqade_fullpane_close_ms)

        socket
        |> assign(:arqade_fullpane_closing?, true)
        |> assign(:arqade_fullpane_close_timer_ref, ref)
    end
  end

  defp cancel_arqade_fullpane_close_timer(socket) do
    case socket.assigns[:arqade_fullpane_close_timer_ref] do
      ref when is_reference(ref) -> Process.cancel_timer(ref)
      _ -> :ok
    end

    socket
    |> assign(:arqade_fullpane_closing?, false)
    |> assign(:arqade_fullpane_close_timer_ref, nil)
  end

  # Performs the `live_render/3` call. Kept out of render_inline_arqade
  # so slice A.4 (catalog + single-piece) can reuse the same plumbing.
  defp render_inline_arqade_live(assigns, module, opts) do
    embed_config = assigns.link.embed_config

    height =
      get_embed_value(embed_config, "height") || get_embed_value(embed_config, :height) || 500

    show_title_raw =
      case {get_embed_value(embed_config, "show_title"),
            get_embed_value(embed_config, :show_title)} do
        {nil, nil} -> nil
        {s, _} when not is_nil(s) -> s
        {_, s} -> s
      end

    # Extract `force_theme` and `content_id` from the stored URL's
    # query string — they're persisted that way because the same URL
    # also feeds the iframe path, which passes them as query params.
    query_params = extract_query_params(opts[:path])

    session =
      %{
        "inline?" => true,
        "base_path" => "",
        # show_title defaults to true (standalone path does the same).
        # Only pass false when explicitly set, so the nested LV can
        # honor the creator's "hide title" setting.
        "show_title" => show_title_raw != false,
        "content_id" => Map.get(query_params, "content_id"),
        "force_theme" => Map.get(query_params, "force_theme"),
        # Same as `id:` in `live_render/3` — nested LV events must
        # `phx-target` this so they reach the child, not the Qlink parent.
        "embed_phx_id" => opts[:dom_id],
        # Parent's AuthSheet-enabled decision (per-host flag).
        # The nested arcade LV reuses this so its CTA-gating stays in
        # lockstep with what the parent will actually render — otherwise
        # an `open_auth_sheet` event forwarded up to the parent could
        # fall on deaf ears when the parent's flag is off for this host.
        "auth_sheet_host_enabled?" => auth_sheet_enabled?(assigns)
      }
      |> Map.merge(opts[:session_params] || %{})

    dom_id = opts[:dom_id]
    fullpane? = assigns.arqade_fullpane_dom_id == dom_id

    shell_leaving? =
      fullpane? && assigns[:arqade_fullpane_closing?] == true

    assigns =
      assigns
      |> assign(:inline_arqade_module, module)
      |> assign(:inline_arqade_dom_id, dom_id)
      |> assign(:inline_arqade_session, session)
      |> assign(:inline_arqade_height, height)
      |> assign(:arqade_fullpane_active?, fullpane?)
      |> assign(:arqade_fullpane_shell_leaving?, shell_leaving?)

    # Thin outer box reserves min-height in the link list while the
    # nested LV boots. When `@arqade_fullpane_active?`, the inner shell
    # is `fixed` full viewport width between the top and the Sponster bar
    # (`bottom-[50px]`, `z-[45]` below the Sponster drawer at z-[46]/[47]
    # and the bar's `z-50`) — not limited to
    # the qlink `max-w-2xl` column. Same DOM / same `live_render`.
    ~H"""
    <div class="relative w-full" style={"min-height: #{@inline_arqade_height}px;"}>
      <div
        id={"arqade-embed-shell-#{@inline_arqade_dom_id}"}
        class={[
          "w-full",
          @arqade_fullpane_active? &&
            "arqade-fullpane-active fixed inset-x-0 top-0 bottom-[50px] z-[45] flex w-full flex-col overflow-hidden bg-base-100 shadow-2xl",
          @arqade_fullpane_shell_leaving? && "arqade-fullpane-leaving"
        ]}
        phx-window-keydown={if(@arqade_fullpane_active?, do: "close-arqade-fullpane")}
        phx-key={if(@arqade_fullpane_active?, do: "Escape")}
      >
        <%= if @arqade_fullpane_active? do %>
          <div class="flex flex-none items-center justify-between gap-2 border-b border-base-300 bg-base-200 px-3 py-2">
            <span class="truncate text-sm font-semibold text-base-content">Arqade</span>
            <button
              type="button"
              phx-click="close-arqade-fullpane"
              class="btn btn-ghost btn-sm btn-circle flex-shrink-0"
              aria-label="Close full view"
            >
              <.icon name="hero-x-mark" class="h-5 w-5" />
            </button>
          </div>
        <% end %>
        <div class={if(@arqade_fullpane_active?, do: "min-h-0 flex-1 overflow-y-auto", else: "w-full")}>
          {live_render(@socket, @inline_arqade_module,
            id: @inline_arqade_dom_id,
            session: @inline_arqade_session
          )}
        </div>
      </div>
    </div>
    """
  end

  defp extract_query_params(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{query: q} when is_binary(q) -> URI.decode_query(q)
      _ -> %{}
    end
  end

  defp extract_query_params(_), do: %{}

  defp get_embed_platform(embed_config) when is_map(embed_config) do
    Map.get(embed_config, "platform") || Map.get(embed_config, :platform)
  end

  defp get_embed_platform(_), do: nil

  defp get_embed_value(embed_config, key) when is_map(embed_config) do
    Map.get(embed_config, key)
  end

  defp get_embed_value(_, _), do: nil

  defp render_youtube_embed(assigns, video_id) do
    assigns = assign(assigns, :video_id, video_id)

    ~H"""
    <div class="w-full rounded-2xl bg-base-200 border border-neutral/30 p-4">
      <%= if @link.title do %>
        <h3 class="text-lg font-semibold mb-2">{@link.title}</h3>
      <% end %>
      <%= if @link.description do %>
        <p class="text-sm text-base-content/70 mb-3">{@link.description}</p>
      <% end %>
      <div class="aspect-video rounded-xl overflow-hidden">
        <iframe
          class="w-full h-full"
          src={"https://www.youtube.com/embed/#{@video_id}"}
          title={@link.title || "YouTube video"}
          frameborder="0"
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
          referrerpolicy="strict-origin-when-cross-origin"
          allowfullscreen
        >
        </iframe>
      </div>
    </div>
    """
  end

  defp render_spotify_embed(assigns, content_id) do
    assigns = assign(assigns, :content_id, content_id)

    ~H"""
    <div class="w-full rounded-2xl bg-base-200 border border-neutral/30 p-4">
      <%= if @link.title do %>
        <h3 class="text-lg font-semibold mb-2">{@link.title}</h3>
      <% end %>
      <%= if @link.description do %>
        <p class="text-sm text-base-content/70 mb-3">{@link.description}</p>
      <% end %>
      <div class="rounded-xl overflow-hidden">
        <iframe
          style="border-radius: 12px;"
          src={"https://open.spotify.com/embed/#{@content_id}"}
          width="100%"
          height="352"
          frameborder="0"
          allowtransparency="true"
          allow="encrypted-media"
          title={@link.title || "Spotify content"}
        >
        </iframe>
      </div>
    </div>
    """
  end

  defp render_tiktok_embed(assigns, video_id) do
    assigns = assign(assigns, :video_id, video_id)

    ~H"""
    <div class="w-full rounded-2xl bg-base-200 border border-neutral/30 p-4">
      <%= if @link.title do %>
        <h3 class="text-lg font-semibold mb-2">{@link.title}</h3>
      <% end %>
      <%= if @link.description do %>
        <p class="text-sm text-base-content/70 mb-3">{@link.description}</p>
      <% end %>
      <div class="rounded-xl overflow-hidden">
        <blockquote
          class="tiktok-embed"
          data-video-id={@video_id}
          style="max-width: 605px; min-width: 325px;"
        >
          <section>
            <a
              target="_blank"
              title={@link.title || "TikTok video"}
              href={"https://www.tiktok.com/#{@video_id}"}
            >
              View on TikTok
            </a>
          </section>
        </blockquote>
        <script async src="https://www.tiktok.com/embed.js">
        </script>
      </div>
    </div>
    """
  end

  defp render_iframe_embed(assigns, iframe_url) do
    embed_config = assigns.link.embed_config

    height =
      get_embed_value(embed_config, "height") || get_embed_value(embed_config, :height) || 500

    # Use case to properly handle false values (|| treats false as falsy)
    show_title =
      case {get_embed_value(embed_config, "show_title"),
            get_embed_value(embed_config, :show_title)} do
        {nil, nil} -> nil
        {s, _} when not is_nil(s) -> s
        {_, s} -> s
      end

    # Rewrite arqade widget iframe host to match the parent page so
    # the shared `.qadabra.app` session cookie is sent on iframe
    # requests. No-op for third-party embeds and on dead renders.
    iframe_url =
      Qlarius.Qlink.Urls.normalize_widget_iframe_url(
        iframe_url,
        assigns[:parent_request_uri]
      )

    # Append show_title param if explicitly set to false
    iframe_url =
      if show_title == false do
        separator = if String.contains?(iframe_url, "?"), do: "&", else: "?"
        "#{iframe_url}#{separator}show_title=false"
      else
        iframe_url
      end

    assigns =
      assigns
      |> assign(:iframe_url, iframe_url)
      |> assign(:iframe_height, height)

    ~H"""
    <div class="w-full rounded-xl overflow-hidden border border-neutral/50">
      <iframe
        src={@iframe_url}
        class="w-full border-none"
        style={"height: #{@iframe_height}px;"}
        title={@link.title || "Embedded content"}
        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
        allowfullscreen
      >
      </iframe>
    </div>
    """
  end

  # Open the in-place AuthSheet and simultaneously close the
  # intermediate `connect_wallet_modal` if it was open — otherwise
  # opening the sheet from inside that interstitial would stack two
  # modals on top of each other. Shared between the `phx-click`
  # event handler and the `:open_auth_sheet` info message forwarded
  # by nested arcade LVs.
  defp open_auth_sheet(socket) do
    socket
    |> assign(:show_auth_sheet, true)
    |> assign(:show_connect_modal, false)
  end

  # Whether the in-place AuthSheet should be rendered on this request.
  # Picks the feature-flag key based on the request host — qlinkin.bio
  # is governed by `:on_qlinkin_bio` (B6), every other host by
  # `:on_qlink_page` (B2). Also requires the visitor to be anonymous.
  def auth_sheet_enabled?(assigns) do
    flag_on? =
      Application.get_env(:qlarius, :auth_sheet, [])
      |> Keyword.get(surface_flag_key(assigns), false)

    anonymous? =
      is_nil(assigns[:current_scope]) or is_nil(assigns[:current_scope].true_user)

    flag_on? and anonymous?
  end

  # Template helper: `true` when the current request is on qlinkin.bio
  # (the public vanity host). Used by the flag-OFF CTA fallback
  # branches so they redirect cross-host to `@interact_login_url`
  # instead of to an in-app `/login` path that isn't mounted on
  # qlinkin.bio.
  def on_qlinkin_bio_host?(assigns) do
    case assigns[:parent_request_uri] do
      %URI{host: host} when is_binary(host) ->
        host in ["qlinkin.bio", "www.qlinkin.bio"]

      _ ->
        false
    end
  end

  defp surface_flag_key(assigns) do
    if on_qlinkin_bio_host?(assigns), do: :on_qlinkin_bio, else: :on_qlink_page
  end

  # Build the referral context for the AuthSheet. On a creator's Qlink
  # page the "referrer" is the creator: if a visitor signs up here, we
  # want the referral row to link back to the creator's me_file (plan
  # §5.4 — drop the referral-code text-entry step).
  #
  # `page.creator.users` is the preloaded many_to_many through
  # `creator_memberships`. We pick the first user as a simple default;
  # for creators with multiple members, refining this to prefer the
  # `:owner` role is a follow-up (requires preloading the membership
  # role, not just the user).
  defp assign_auth_referral_context(socket, page) do
    context =
      case page.creator do
        %{users: [owner_user | _]} ->
          Qlarius.Referrals.Context.from_creator(owner_user)

        _ ->
          Qlarius.Referrals.Context.none()
      end

    assign(socket, :auth_referral_context, context)
  end
end
