defmodule QlariusWeb.QlinkPage.Show do
  use QlariusWeb, :live_view

  alias Qlarius.Qlink
  alias Qlarius.Repo
  alias Qlarius.Wallets
  alias QlariusWeb.SponsterRecipientSurface
  alias QlariusWeb.WalletBalanceSync

  import QlariusWeb.Components.AdsComponents
  import QlariusWeb.InstaTipComponents
  import QlariusWeb.Components.SponsterPublicPage, only: [sponster_stack: 1]

  # Shared "View anywhere, Act only when authed" helpers —
  # authed?/1, connect_wallet_modal/1, etc. Same module the arqade
  # widget consumes; keeps the anonymous-viewer UX consistent across
  # Qlink page + embedded widgets.
  import QlariusWeb.Widgets.UnauthCTA

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
            |> assign(:page_title, "Qlink | @#{page.alias}")
            |> assign(:display_image, Qlink.get_display_image(page))
            |> assign(:recipient, page.recipient)
            |> assign(:arqade_fullpane_dom_id, nil)
            |> assign(:arqade_fullpane_closing?, false)
            |> assign(:arqade_fullpane_close_timer_ref, nil)
            |> assign_surface_context(page)
            |> assign_auth_referral_context(page)
            |> SponsterRecipientSurface.init_assigns(page.recipient)
            |> assign_in_app_escape_canonical()
            |> maybe_fire_iab_escape_shown_telemetry()

          # Subscribe to PubSub if authenticated and connected
          socket =
            if connected?(socket) && socket.assigns.current_scope do
              SponsterRecipientSurface.subscribe(socket)
            else
              socket
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

  # All Sponster drawer / split / tip / video / auth-sheet / connect-modal
  # events are shared with the public Tiqit Arqade pages and the embed
  # widget via `SponsterRecipientSurface`.
  def handle_event(event, params, socket) do
    case SponsterRecipientSurface.handle_event(event, params, socket) do
      {:handled, socket} -> {:noreply, socket}
      :unhandled -> {:noreply, socket}
    end
  end

  # Handle info callbacks
  @impl true
  def handle_info({:inline_arcade_embed_ready, pid}, socket) when is_pid(pid) do
    {:noreply, WalletBalanceSync.register_inline_embed(socket, pid)}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, socket) do
    if ref == socket.assigns[:arcade_embed_monitor_ref] do
      {:noreply, WalletBalanceSync.clear_inline_embed(socket)}
    else
      {:noreply, socket}
    end
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

  # Remaining Sponster surface messages (drawer timers, disclaimer dock,
  # split reminder, auth sheet forwards, wallet stats) are shared via
  # `SponsterRecipientSurface`.
  def handle_info(msg, socket) do
    case SponsterRecipientSurface.handle_info(msg, socket) do
      {:handled, socket} -> {:noreply, socket}
      :unhandled -> {:noreply, socket}
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
  attr :creator, :map, default: nil

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
    <div class="w-full rounded-2xl border border-neutral/30 bg-base-200 overflow-hidden">
      <%= cond do %>
        <% is_nil(@block_recipient) -> %>
          <div class="text-center py-8">
            <span class="text-warning">Tip recipient not configured</span>
          </div>
        <% true -> %>
          <.insta_tip_card
            recipient={@block_recipient}
            creator={@creator}
            scope={@current_scope}
            wallet_balance={@current_scope && @current_scope.wallet_balance}
            offered_amount={@current_scope && @current_scope.offered_amount}
            ads_count={@current_scope && @current_scope.ads_count}
            show_image={@show_header}
            show_message={@show_header}
            wallet_strip_id={"wallet-balance-tipjar-#{@link.id}"}
            daily_gift_available?={
              @current_scope && @current_scope.user &&
                Wallets.daily_gift_available?(@current_scope.user)
            }
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
      class="qlink-link-card block w-full rounded-full bg-base-200 border border-neutral/30 transition-colors active:bg-base-300 outline-none focus:outline-none focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-base-content/35"
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

    height = iframe_embed_height_px(embed_config)

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
        "auth_sheet_host_enabled?" => auth_sheet_enabled?(assigns),
        "parent_phx_id" => assigns.socket.id
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

    # One shell + one `live_render` (see 82b0abc): toggle fixed full-pane via classes only.
    # No JS portal — avoids blank flash when closing and keeps LiveView DOM stable.
    ~H"""
    <div
      class={
        if(@arqade_fullpane_active?,
          do: "relative w-full",
          else: "relative w-full flex flex-col min-h-0"
        )
      }
      style={
        if(@arqade_fullpane_active?,
          do: "min-height: #{@inline_arqade_height}px;",
          else: "height: #{@inline_arqade_height}px; max-height: #{@inline_arqade_height}px;"
        )
      }
    >
      <div
        id={"arqade-embed-shell-#{@inline_arqade_dom_id}"}
        phx-hook="BodyScrollLock"
        data-body-scroll-lock={to_string(@arqade_fullpane_active?)}
        data-qlink-arqade-embed-height={@inline_arqade_height}
        class={[
          "w-full",
          !@arqade_fullpane_active? &&
            "qlink-arqade-embed-cage h-full min-h-0 flex flex-col overflow-hidden rounded-xl",
          @arqade_fullpane_active? &&
            "arqade-fullpane-active fixed inset-x-0 top-0 bottom-0 z-[58] flex w-full flex-col overflow-hidden bg-base-100 shadow-2xl",
          @arqade_fullpane_shell_leaving? && "arqade-fullpane-leaving"
        ]}
        phx-window-keydown={if(@arqade_fullpane_active?, do: "close-arqade-fullpane")}
        phx-key={if(@arqade_fullpane_active?, do: "Escape")}
      >
        <button
          :if={@arqade_fullpane_active?}
          type="button"
          phx-click="close-arqade-fullpane"
          class="absolute top-2 right-2 z-[60] btn btn-ghost btn-sm btn-circle flex-shrink-0 bg-base-200/90 hover:bg-base-300 shadow-sm"
          aria-label="Close full view"
        >
          <.icon name="hero-x-mark" class="h-5 w-5" />
        </button>
        <div
          class={[
            "qlink-arqade-embed-cage__inner h-full max-h-full min-h-0 flex flex-col",
            !@arqade_fullpane_active? && "overflow-hidden",
            @arqade_fullpane_active? &&
              "arqade-fullpane-active__motion relative min-h-0 flex-1 overflow-hidden"
          ]}
        >
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

  # Embed block "Height (px)" — stored on `embed_config["height"]` (forms may
  # persist integers or strings). Used for iframe `height` / inline arqade shell.
  defp iframe_embed_height_px(embed_config) when is_map(embed_config) do
    raw =
      get_embed_value(embed_config, "height") ||
        get_embed_value(embed_config, :height)

    n =
      cond do
        is_integer(raw) and raw > 0 ->
          raw

        is_float(raw) and raw > 0 ->
          trunc(raw)

        is_binary(raw) ->
          case Integer.parse(String.trim(raw)) do
            {i, _} when i > 0 -> i
            _ -> nil
          end

        true ->
          nil
      end

    n = n || 500
    min(max(n, 120), 8000)
  end

  defp iframe_embed_height_px(_), do: 500

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
              class="outline-none focus:outline-none focus-visible:underline"
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

    height = iframe_embed_height_px(embed_config)

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
    <div
      class="w-full rounded-xl overflow-hidden border border-neutral/50"
      style={"height: #{@iframe_height}px; max-height: #{@iframe_height}px;"}
    >
      <iframe
        src={@iframe_url}
        class="w-full max-h-full border-none block"
        height={@iframe_height}
        style={"height: #{@iframe_height}px; max-height: #{@iframe_height}px;"}
        title={@link.title || "Embedded content"}
        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
        allowfullscreen
      >
      </iframe>
    </div>
    """
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
