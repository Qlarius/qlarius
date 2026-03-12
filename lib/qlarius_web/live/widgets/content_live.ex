defmodule QlariusWeb.Widgets.ContentLive do
  @moduledoc """
  Displays unlocked content (e.g. video playback) for a valid tiqit.

  This is the in-app equivalent of ContentController. It wraps content
  in the mobile layout shell so users get full app chrome (nav, sidebar)
  when accessing content from /content/:id via tiqit cards.

  If the user lacks a valid tiqit, they're redirected to the arqade
  purchase page for the content's group.
  """
  use QlariusWeb, :live_view

  alias Qlarius.Tiqit.Arcade.Arcade
  alias QlariusWeb.Layouts

  import QlariusWeb.Helpers.ImageHelpers
  import QlariusWeb.PWAHelpers
  import QlariusWeb.Widgets.Arcade.Components, only: [arqade_breadcrumbs: 1]

  on_mount {QlariusWeb.DetectMobile, :detect_mobile}

  def mount(%{"id" => id}, session, socket) do
    piece =
      Arcade.get_content_piece!(id)
      |> Qlarius.Repo.preload(content_group: [catalog: :creator])
    scope = socket.assigns[:current_scope]

    case Arcade.get_valid_tiqit(scope, piece) do
      nil ->
        group_id = piece.content_group_id || piece.content_group.id

        {:ok,
         socket
         |> put_flash(:error, "You don't have access to this content")
         |> redirect(to: "/arqade/group/#{group_id}?content_id=#{piece.id}")}

      tiqit ->
        {:ok,
         socket
         |> init_pwa_assigns(session)
         |> assign(
           content: piece,
           tiqit: tiqit,
           title: "Arqade",
           current_path: "/content/#{id}"
         )}
    end
  end

  def handle_event("pwa_detected", params, socket) do
    handle_pwa_detection(socket, params)
  end

  def handle_event("referral_code_from_storage", _params, socket) do
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div id="content-pwa-detect" phx-hook="PWADetect">
    <Layouts.maybe_mobile wrap={true} {assigns}>
      <.arqade_breadcrumbs
        base_path=""
        crumbs={[
          {@content.content_group.catalog.creator.name, "/arqade"},
          {@content.content_group.catalog.name, "/arqade/catalog/#{@content.content_group.catalog.id}"},
          {@content.content_group.title, "/arqade/group/#{@content.content_group.id}"}
        ]}
      />
      <div class="container mx-auto px-4 py-4 max-w-4xl">
        <div class="p-4">
          <div class="aspect-video bg-base-200 rounded-box overflow-hidden mb-2 border border-base-300 relative">
            <div
              id="video-poster"
              class="absolute inset-0 cursor-pointer"
              phx-hook="YouTubePoster"
              data-youtube-id={@content.youtube_id}
            >
              <img
                src={content_image_url(@content, @content.content_group)}
                alt={@content.title}
                class="w-full h-full object-cover"
              />
              <div class="absolute inset-0 flex items-center justify-center bg-black/30 hover:bg-black/40 transition-colors">
                <div class="bg-white/90 hover:bg-white rounded-full p-6 transition-colors">
                  <svg class="w-16 h-16 text-primary" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M8 5v14l11-7z" />
                  </svg>
                </div>
              </div>
            </div>

            <iframe
              id="video-iframe"
              class="w-full h-full hidden"
              src=""
              title="YouTube video player"
              frameborder="0"
              allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
              referrerpolicy="strict-origin-when-cross-origin"
              allowfullscreen
            >
            </iframe>
          </div>

          <div class="flex items-start justify-between mt-0">
            <div class="flex-1">
              <h1 class="text-2xl font-bold text-base-content mb-0">
                {@content.title}
              </h1>
              <p class="text-base-content/70 text-sm mb-3">
                {@content.content_group.title}
              </p>
            </div>
          </div>

          <QlariusWeb.Components.TiqitExpirationCountdown.badge
            expires_at={@tiqit.expires_at}
            class="badge-outline badge-md px-2 py-3 rounded-lg"
          />
        </div>
      </div>
    </Layouts.maybe_mobile>
    </div>
    """
  end
end
