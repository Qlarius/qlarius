defmodule QlariusWeb.AdJumpPageHTML do
  use QlariusWeb, :html

  attr :offer, :any, required: true
  attr :recipient_id, :string, default: nil

  def jump(assigns) do
    ~H"""
    <div
      id="jump-page"
      class="max-w-md mx-auto bg-base-50 p-8 flex flex-col items-center justify-center text-center space-y-6"
      data-offer-id={@offer.id}
      data-recipient-id={@recipient_id || ""}
      data-jump-url={@offer.media_piece.jump_url}
      data-csrf={Plug.CSRFProtection.get_csrf_token()}
    >
      <h2 class="text-2xl font-semibold text-base-content/70">
        Be careful out there!
      </h2>

      <img src={~p"/images/qlarius_app_icon_180.png"} width="100" height="71" />

      <p class="text-base-content/50">Leaving the no-tracking safety of Qadabra.</p>

      <div class="w-full">
        <p class="text-sm text-base-content/60 mb-2">
          Redirecting in <span id="countdown">2</span> seconds...
        </p>
        <progress id="progress-bar" class="progress progress-primary w-full" value="0" max="100">
        </progress>
      </div>
    </div>

    <script>
      (function() {
        const container = document.getElementById('jump-page');
        const offerId = container.dataset.offerId;
        const recipientId = container.dataset.recipientId;
        const jumpUrl = container.dataset.jumpUrl;
        const csrfToken = container.dataset.csrf;

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

            // Process payment via AJAX before redirecting
            fetch('/jump/collect', {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                'x-csrf-token': csrfToken
              },
              body: JSON.stringify({
                offer_id: offerId,
                recipient_id: recipientId
              })
            })
            .then(response => response.json())
            .then(data => {
              // Payment processed, now redirect to advertiser
              window.location.href = jumpUrl;
            })
            .catch(error => {
              // Still redirect even if payment fails - don't block user
              console.error('Payment error:', error);
              window.location.href = jumpUrl;
            });
          }
        }, interval);
      })();
    </script>
    """
  end
end
