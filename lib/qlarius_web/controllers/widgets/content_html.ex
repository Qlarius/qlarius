defmodule QlariusWeb.Widgets.ContentHTML do
  use QlariusWeb, :html
  import QlariusWeb.Helpers.ImageHelpers

  def show(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-100" data-theme={@force_theme}>
      <div class="container mx-auto px-4 py-4 max-w-4xl">
        <div class="mb-3">
          <.back navigate={
            if @force_theme,
              do:
                ~p"/widgets/arcade/group/#{@content.content_group}?content_id=#{@content.id}&force_theme=#{@force_theme}",
              else: ~p"/widgets/arcade/group/#{@content.content_group}?content_id=#{@content.id}"
          }>
            Back to <%= String.capitalize(to_string(@content.content_group.catalog.piece_type)) %> list
          </.back>
        </div>
        <div class="p-4">
          <div class="aspect-video bg-base-200 rounded-box overflow-hidden mb-2 border border-base-300 relative">
            <!-- Poster frame with play button -->
            <div id="video-poster" class="absolute inset-0 cursor-pointer" onclick="playVideo()">
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
            
            <!-- YouTube iframe (hidden initially) -->
            <iframe
              id="video-iframe"
              class="w-full h-full hidden"
              src=""
              data-src={"https://www.youtube.com/embed/#{@content.youtube_id}?autoplay=1"}
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
    </div>

    <script>
      function playVideo() {
        const poster = document.getElementById('video-poster');
        const iframe = document.getElementById('video-iframe');
        
        // Hide poster
        poster.classList.add('hidden');
        
        // Show and load iframe
        iframe.classList.remove('hidden');
        iframe.src = iframe.dataset.src;
      }
    </script>
    """
  end
end
