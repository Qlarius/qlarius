defmodule QlariusWeb.Widgets.ContentHTML do
  use QlariusWeb, :html

  def show(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-100">
      <div class="container mx-auto px-4 py-8 max-w-4xl">
        <div class="card bg-base-100 shadow-xl border border-base-300">
          <div class="card-body">
            <.header class="mb-0">
              <.back navigate={~p"/widgets/arcade/group/#{@content.content_group.id}"}>
                Back to Arcade
              </.back>
              <div class="flex items-start justify-between mt-3">
                <div class="flex-1">
                  <p class="text-base-content/70">
                    {@content.content_group.title}
                  </p>
                  <h1 class="text-2xl font-bold text-base-content mb-2">
                    {@content.title}
                  </h1>
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

            <div class="stats stats-vertical lg:stats-horizontal shadow bg-base-200">
              <div class="stat">
                <div class="stat-figure text-primary">
                  <.icon name="hero-clock" class="w-6 h-6" />
                </div>
                <div class="stat-title text-base-content/70">Time Remaining:</div>
                <div
                  class="stat-value text-primary text-lg"
                  id="expiration-timer"
                  data-expires-at={@tiqit.expires_at}
                >
                  {@tiqit.expires_at}
                </div>
              </div>
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
          if (days < 1 && hours < 1) parts.push(`${seconds} ${seconds === 1 ? 'second' : 'seconds'}`);

          timerElement.textContent = parts.join(' : ');

          setTimeout(updateTimer, 1000);
      }

      updateTimer();
      });
    </script>
    """
  end
end
