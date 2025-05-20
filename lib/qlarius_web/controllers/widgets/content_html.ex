defmodule QlariusWeb.Widgets.ContentHTML do
  use QlariusWeb, :html

  def show(assigns) do
    ~H"""
    <div class="w-screen h-screen bg-white">
      <div class="flex flex-col gap-2 w-[640px] px-8 mx-auto">
        <.header>
          {@content.title}
          <:subtitle>{@content.content_group.title}</:subtitle>
        </.header>

        <div class="rounded-lg p-2 mx-auto bg-gray-300">
          <iframe
            class="mx-auto"
            width="560"
            height="315"
            src={"https://www.youtube.com/embed/#{@content.youtube_id}"}
            title="YouTube video player"
            frameborder="0"
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
            referrerpolicy="strict-origin-when-cross-origin"
            allowfullscreen
          >
          </iframe>
        </div>

        <div class="text-sm text-gray-700 text-center mt-3">
          Your Tiqit expires in:
          <span id="expiration-timer" data-expires-at={@tiqit.expires_at}>
            {@tiqit.expires_at}
          </span>
        </div>

        <.back navigate={~p"/widgets/arcade/group/#{@content.content_group.id}"}>Back</.back>
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
