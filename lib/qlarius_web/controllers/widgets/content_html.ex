defmodule QlariusWeb.Widgets.ContentHTML do
  use QlariusWeb, :html

  def show(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-100">
      <div class="container mx-auto px-4 py-8 max-w-4xl">
        <div class="card bg-base-100 shadow-xl border border-base-300">
          <div class="card-body">
            <.header class="mb-6">
              <div class="flex items-start justify-between">
                <div class="flex-1">
                  <h1 class="text-2xl font-bold text-base-content mb-2">
                    {@content.title}
                  </h1>
                  <p class="text-base-content/70">
                    {@content.content_group.title}
                  </p>
                </div>
                <div class="badge badge-primary badge-lg">
                  <.icon name="hero-play" class="w-4 h-4 mr-1" /> Now Playing
                </div>
              </div>
            </.header>

            <div class="aspect-video bg-base-200 rounded-box overflow-hidden mb-6 border border-base-300">
              <iframe
                class="w-full h-full"
                src={"https://www.youtube.com/embed/#{@content.youtube_id}"}
                title="YouTube video player"
                frameborder="0"
                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
                referrerpolicy="strict-origin-when-cross-origin"
                allowfullscreen
              >
              </iframe>
            </div>

            <div class="stats stats-vertical lg:stats-horizontal shadow mb-6 bg-base-200">
              <div class="stat">
                <div class="stat-figure text-primary">
                  <.icon name="hero-clock" class="w-6 h-6" />
                </div>
                <div class="stat-title text-base-content/70">Expires In</div>
                <div
                  class="stat-value text-primary text-lg"
                  id="expiration-timer"
                  data-expires-at={@tiqit.expires_at}
                >
                  {@tiqit.expires_at}
                </div>
                <div class="stat-desc text-base-content/50">
                  Keep watching before it expires
                </div>
              </div>
            </div>

            <div class="card-actions justify-between items-center">
              <div class="flex items-center text-sm text-base-content/60">
                <.icon name="hero-eye" class="w-4 h-4 mr-2" /> Enjoy your Tiqit access
              </div>
              <.back navigate={~p"/widgets/arcade/group/#{@content.content_group.id}"}>
                <.icon name="hero-arrow-left" class="w-4 h-4 mr-2" /> Back to Content
              </.back>
            </div>
          </div>
        </div>
      </div>
    </div>

    <script type="text/javascript">
      document.addEventListener('DOMContentLoaded', function() {
      const timerElement = document.getElementById('expiration-timer');
      if (!timerElement) return;

      const expiresAt = new Date(timerElement.dataset.expiresAt).getTime();

      function updateTimer() {
          const now = new Date().getTime();
          const distance = expiresAt - now;

          if (distance <= 0) {
              window.location.href = '/foo/bar';
              return;
          }

          const days = Math.floor(distance / (1000 * 60 * 60 * 24));
          const hours = Math.floor((distance % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
          const minutes = Math.floor((distance % (1000 * 60 * 60)) / (1000 * 60));
          const seconds = Math.floor((distance % (1000 * 60)) / 1000);

          const parts = [];
          if (days > 0) parts.push(`${days} ${days === 1 ? 'day' : 'days'}`);
          if (hours > 0 || days > 0) parts.push(`${hours} ${hours === 1 ? 'hour' : 'hours'}`);
          if (minutes > 0 || hours > 0 || days > 0) parts.push(`${minutes} ${minutes === 1 ? 'minute' : 'minutes'}`);
          parts.push(`${seconds} ${seconds === 1 ? 'second' : 'seconds'}`);

          timerElement.textContent = parts.join(', ');

          setTimeout(updateTimer, 1000);
      }

      updateTimer();
      });
    </script>
    """
  end
end
