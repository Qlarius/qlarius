defmodule QlariusWeb.AdJumpPageHTML do
  use QlariusWeb, :html

  attr :offer, :any, required: true

  def jump(assigns) do
    ~H"""
    <div class="max-w-md mx-auto bg-base-50 p-8 flex flex-col items-center justify-center text-center space-y-6">
      <h2 class="text-2xl font-semibold text-base-content/70">Leaving the no-tracking safety of Qlarius.</h2>

      <img src={~p"/images/qlarius_app_icon_180.png"} width="100" height="71" />

      <p class="text-base-content/50">Be careful out there.</p>

      <div class="w-full">
        <p class="text-sm text-base-content/60 mb-2">Redirecting in <span id="countdown">2</span> seconds...</p>
        <progress id="progress-bar" class="progress progress-primary w-full" value="0" max="100"></progress>
      </div>
    </div>

    <script>
      let timeLeft = 2000;
      const interval = 50;
      const progressBar = document.getElementById('progress-bar');
      const countdown = document.getElementById('countdown');

      const timer = setInterval(() => {
        timeLeft -= interval;
        const progress = ((2000 - timeLeft) / 2000) * 100;
        progressBar.value = progress;
        countdown.textContent = Math.ceil(timeLeft / 1000);

        if (timeLeft <= 0) {
          clearInterval(timer);
          window.location.href = "<%= @offer.media_piece.jump_url %>";
        }
      }, interval);
    </script>
    """
  end
end
