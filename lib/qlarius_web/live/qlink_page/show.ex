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
  import QlariusWeb.InstaTipComponents

  on_mount {QlariusWeb.GetUserIP, :assign_ip}

  @impl true
  def mount(%{"alias" => page_alias}, _session, socket) do
    page =
      case Qlink.get_page_by_alias(page_alias) do
        nil -> nil
        p -> Repo.preload(p, :recipient)
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
            |> assign(:page_title, page.title)
            |> assign(:display_image, Qlink.get_display_image(page))
            |> assign(:recipient, page.recipient)
            |> init_sponster_assigns()

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

  defp init_sponster_assigns(socket) do
    socket
    |> assign(:show_sponster_drawer, false)
    |> assign(:selected_ad_type, "video")
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
    |> assign(:current_balance, get_current_balance(socket))
    |> assign(:show_ad_type_tabs, false)
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

  # Sponster drawer toggle
  @impl true
  def handle_event("toggle_sponster_drawer", _params, socket) do
    show = !socket.assigns.show_sponster_drawer

    socket =
      if show && Enum.empty?(socket.assigns.video_offers) && socket.assigns.current_scope do
        # Load offers when opening drawer
        socket
        |> assign(:loading_offers, true)
        |> load_offers()
      else
        socket
      end

    {:noreply, assign(socket, :show_sponster_drawer, show)}
  end

  @impl true
  def handle_event("close_sponster_drawer", _params, socket) do
    {:noreply, assign(socket, :show_sponster_drawer, false)}
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
             |> assign(:completed_video_offers, completed_ids)
             |> put_flash(:info, "Payment collected!")}

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

  # InstaTip events
  @impl true
  def handle_event("initiate_insta_tip", params, socket) do
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
        new_balance = Decimal.sub(socket.assigns.current_scope.wallet_balance, amount)
        current_scope = Map.put(socket.assigns.current_scope, :wallet_balance, new_balance)

        {:noreply,
         socket
         |> assign(:current_scope, current_scope)
         |> assign(:current_balance, new_balance)
         |> assign(:show_insta_tip_modal, false)
         |> assign(:insta_tip_amount, nil)
         |> assign(:insta_tip_recipient, nil)
         |> put_flash(:info, "InstaTip of #{format_usd(amount)} sent!")}

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

  # Handle info callbacks
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

        show_tabs = length(active_offers) > 0 && length(video_offers_with_rate) > 0

        socket
        |> assign(:active_offers, active_offers)
        |> assign(:video_offers, video_offers_with_rate)
        |> assign(:show_ad_type_tabs, show_tabs)
        |> assign(:loading_offers, false)
    end
  end

  defp creator_viewing_own_page?(socket, page) do
    case socket.assigns[:current_scope] do
      nil ->
        false

      %{user: user} ->
        Enum.any?(page.creator.users, fn creator_user ->
          creator_user.id == user.id
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

  defp get_theme(page) do
    case page.theme_config do
      %{"theme" => theme} -> theme
      _ -> "light"
    end
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

  attr :link, :map, required: true
  attr :recipient, :map, default: nil
  attr :current_scope, :map, default: nil

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

    ~H"""
    <div class="w-full rounded-2xl bg-base-200 border border-neutral/30 p-4">
      <%= if @block_recipient && @current_scope && @current_scope.user do %>
        <.insta_tip_card
          recipient={@block_recipient}
          wallet_balance={@current_scope.wallet_balance}
          show_image={@show_header}
          show_message={@show_header}
        />
      <% else %>
        <div class="text-center py-8">
          <%= if @block_recipient do %>
            <%= if @show_header do %>
              <div class="w-32 h-auto mx-auto mb-4 bg-base-300 shadow-md rounded overflow-hidden">
                <img
                  src={
                    if @block_recipient.graphic_url do
                      QlariusWeb.Uploaders.RecipientBrandImage.url({@block_recipient.graphic_url, @block_recipient})
                    else
                      ~p"/images/tipjar_love_default.png"
                    end
                  }
                  alt={@block_recipient.name || "Recipient"}
                  class="object-contain w-full h-full"
                />
              </div>
            <% end %>
            <div class="text-sm text-base-content/50">
              <.link navigate={~p"/login"} class="link link-primary">Sign in</.link>
              to send a tip
            </div>
          <% else %>
            <span class="text-warning">Tip recipient not configured</span>
          <% end %>
        </div>
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

    case platform do
      "youtube" when not is_nil(video_id) ->
        render_youtube_embed(assigns, video_id)

      "spotify" when not is_nil(content_id) ->
        render_spotify_embed(assigns, content_id)

      "tiktok" when not is_nil(video_id) ->
        render_tiktok_embed(assigns, video_id)

      _ ->
        render_standard_link(assigns)
    end
  end

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
    <div class="mb-4">
      <%= if @link.title do %>
        <h3 class="text-lg font-semibold mb-2">{@link.title}</h3>
      <% end %>
      <%= if @link.description do %>
        <p class="text-sm text-base-content/70 mb-3">{@link.description}</p>
      <% end %>
      <div class="aspect-video bg-base-200 rounded-lg overflow-hidden border border-neutral/30">
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
    <div class="mb-4">
      <%= if @link.title do %>
        <h3 class="text-lg font-semibold mb-2">{@link.title}</h3>
      <% end %>
      <%= if @link.description do %>
        <p class="text-sm text-base-content/70 mb-3">{@link.description}</p>
      <% end %>
      <div class="bg-base-200 rounded-lg overflow-hidden border border-neutral/30 p-4">
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
    <div class="mb-4">
      <%= if @link.title do %>
        <h3 class="text-lg font-semibold mb-2">{@link.title}</h3>
      <% end %>
      <%= if @link.description do %>
        <p class="text-sm text-base-content/70 mb-3">{@link.description}</p>
      <% end %>
      <div class="bg-base-200 rounded-lg overflow-hidden border border-neutral/30 p-4">
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
end
