defmodule QlariusWeb.Components.TiqitUnlockedContent do
  @moduledoc """
  YouTube unlock UI for tiqit-backed content. Shared by the `/content/:id` page
  and the fullscreen in-page player used on inline Qlink arqade embeds.
  """
  use Phoenix.Component

  import QlariusWeb.Helpers.ImageHelpers

  attr :id_prefix, :string, required: true

  attr :piece, :map,
    required: true,
    doc: "Qlarius struct `ContentPiece` (with associations as needed)"

  attr :group, :map, required: true, doc: "Parent `ContentGroup` (for `content_image_url/2`)"
  attr :tiqit, :map, required: true, doc: "The active tiqit for countdown badge"
  attr :class, :string, default: nil, doc: "Optional outer wrapper class"

  def tiqit_unlocked_content_player(assigns) do
    ~H"""
    <div class={["w-full", @class]}>
      <div class="aspect-video bg-base-200 rounded-box overflow-hidden mb-2 border border-base-300 relative">
        <div
          id={poster_id(@id_prefix)}
          class="absolute inset-0 cursor-pointer"
          phx-hook="YouTubePoster"
          data-youtube-id={@piece.youtube_id}
        >
          <img
            src={content_image_url(@piece, @group)}
            alt={@piece.title}
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
          class="tiqit-yt-embed w-full h-full hidden"
          data-tiqit-player-iframe
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
            {@piece.title}
          </h1>
          <p class="text-base-content/70 text-sm mb-3">
            {@group.title}
          </p>
        </div>
      </div>

      <QlariusWeb.Components.TiqitExpirationCountdown.badge
        expires_at={@tiqit.expires_at}
        class="badge-outline badge-md px-2 py-3 rounded-lg"
      />
    </div>
    """
  end

  defp poster_id(prefix), do: "#{prefix}-video-poster"
end
