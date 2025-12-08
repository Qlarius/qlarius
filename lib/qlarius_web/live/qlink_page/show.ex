defmodule QlariusWeb.QlinkPage.Show do
  use QlariusWeb, :live_view

  alias Qlarius.Qlink
  alias Qlarius.Repo

  @impl true
  def mount(%{"alias" => page_alias}, _session, socket) do
    case Qlink.get_page_by_alias(page_alias) do
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

          {:ok,
           socket
           |> assign(:page, page)
           |> assign(:links, links)
           |> assign(:sections, sections)
           |> assign(:page_title, page.title)
           |> assign(:display_image, Qlink.get_display_image(page))}
        else
          {:ok,
           socket
           |> put_flash(:error, "This page is not published yet")
           |> redirect(to: ~p"/")}
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
              forwarded_for = Enum.find_value(headers, fn {k, v} ->
                if String.downcase(to_string(k)) == "x-forwarded-for", do: v
              end) || Enum.find_value(headers, fn {k, v} ->
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

  defp render_link(link) do
    assigns = %{link: link}

    cond do
      link.type == :embed && link.embed_config ->
        render_embed(assigns)
      true ->
        render_standard_link(assigns)
    end
  end

  defp render_standard_link(assigns) do
    ~H"""
    <a
      href={@link.url}
      target="_blank"
      rel="noopener noreferrer"
      class="block w-full rounded-full bg-base-200 hover:bg-base-300 transition-colors border border-base-300"
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

  defp render_embed(assigns) do
    embed_config = assigns.link.embed_config

    platform = get_embed_platform(embed_config)
    video_id = get_embed_value(embed_config, "video_id") || get_embed_value(embed_config, :video_id)
    content_id = get_embed_value(embed_config, "content_id") || get_embed_value(embed_config, :content_id)

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
    ~H"""
    <div class="mb-4">
      <%= if @link.title do %>
        <h3 class="text-lg font-semibold mb-2">{@link.title}</h3>
      <% end %>
      <%= if @link.description do %>
        <p class="text-sm text-base-content/70 mb-3">{@link.description}</p>
      <% end %>
      <div class="aspect-video bg-base-200 rounded-lg overflow-hidden border border-base-300">
        <iframe
          class="w-full h-full"
          src={"https://www.youtube.com/embed/#{video_id}"}
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
    ~H"""
    <div class="mb-4">
      <%= if @link.title do %>
        <h3 class="text-lg font-semibold mb-2">{@link.title}</h3>
      <% end %>
      <%= if @link.description do %>
        <p class="text-sm text-base-content/70 mb-3">{@link.description}</p>
      <% end %>
      <div class="bg-base-200 rounded-lg overflow-hidden border border-base-300 p-4">
        <iframe
          style="border-radius: 12px;"
          src={"https://open.spotify.com/embed/#{content_id}"}
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
    ~H"""
    <div class="mb-4">
      <%= if @link.title do %>
        <h3 class="text-lg font-semibold mb-2">{@link.title}</h3>
      <% end %>
      <%= if @link.description do %>
        <p class="text-sm text-base-content/70 mb-3">{@link.description}</p>
      <% end %>
      <div class="bg-base-200 rounded-lg overflow-hidden border border-base-300 p-4">
        <blockquote
          class="tiktok-embed"
          data-video-id={video_id}
          style="max-width: 605px; min-width: 325px;"
        >
          <section>
            <a
              target="_blank"
              title={@link.title || "TikTok video"}
              href={"https://www.tiktok.com/#{video_id}"}
            >
              View on TikTok
            </a>
          </section>
        </blockquote>
        <script async src="https://www.tiktok.com/embed.js"></script>
      </div>
    </div>
    """
  end
end
