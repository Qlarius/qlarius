defmodule QlariusWeb.AdJumpPageHTML do
  use QlariusWeb, :html

  attr :offer, :any, required: true
  attr :recipient_id, :string, default: nil

  def jump(assigns) do
    ~H"""
    <div
      id="jump-page"
      class="max-w-md mx-auto bg-base-50 p-8 flex flex-col items-center justify-center text-center space-y-6 min-h-screen"
      data-offer-id={@offer.id}
      data-recipient-id={@recipient_id || ""}
      data-jump-url={@offer.media_piece.jump_url}
      data-csrf={Plug.CSRFProtection.get_csrf_token()}
    >
      <%!-- Countdown UI (shown initially) --%>
      <div id="countdown-ui">
        <h2 class="text-2xl font-semibold text-base-content/70">
          Be careful out there!
        </h2>

        <img src={~p"/images/qlarius_app_icon_180.png"} width="100" height="71" class="my-6 block mx-auto" />

        <p class="text-base-content/50">Leaving the no-tracking safety of Qadabra.</p>

        <div class="w-full mt-6">
          <p class="text-sm text-base-content/60 mb-2">
            Redirecting in <span id="countdown">2</span> seconds...
          </p>
          <progress id="progress-bar" class="progress progress-primary w-full" value="0" max="100">
          </progress>
        </div>
      </div>

      <%!-- Redirect complete UI (shown after redirect, for macOS PWA orphan windows) --%>
      <div id="redirect-complete-ui" class="hidden">
        <div class="text-5xl mb-4">✓</div>
        <h2 class="text-2xl font-semibold text-success mb-4">
          Redirect Complete
        </h2>
        <p class="text-base-content/60 mb-6">
          You can close this window to return to Qadabra.
        </p>
        <button
          id="close-window-btn"
          class="btn btn-primary btn-lg"
          onclick="window.close(); return false;"
        >
          Close This Window
        </button>
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
        const countdownUI = document.getElementById('countdown-ui');
        const redirectCompleteUI = document.getElementById('redirect-complete-ui');
        let hasRedirected = false;

        // Detect PWA (standalone) and mobile for auto-close decision
        const isMacOS = navigator.platform.toUpperCase().indexOf('MAC') >= 0;
        const isStandalone = window.navigator.standalone === true ||
                            window.matchMedia('(display-mode: standalone)').matches;
        const isMacOSPWA = isMacOS && isStandalone;
        const isMobile = /iPhone|iPad|iPod|Android/i.test(navigator.userAgent) ||
          (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
        const shouldAutoClose = isStandalone && !isMobile;

        // Listen for page becoming visible again (user returns from external app)
        // This handles the case where deep linking opens a native app (e.g., Yelp)
        // and the user returns to the PWA which would otherwise be stuck
        document.addEventListener('visibilitychange', function() {
          if (document.visibilityState === 'visible' && hasRedirected) {
            // User returned after we redirected them - send them back to ads
            window.location.href = '/ads';
          }
        });

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
              // Mark that we've redirected (for visibilitychange handler)
              hasRedirected = true;
              // Payment processed, now redirect to advertiser
              window.location.href = jumpUrl;
              // Auto-close only on desktop PWA (mobile in-app browser handles it nicely)
              if (shouldAutoClose) {
                setTimeout(() => {
                  window.close();
                  if (isMacOSPWA) {
                    setTimeout(() => {
                      countdownUI.classList.add('hidden');
                      redirectCompleteUI.classList.remove('hidden');
                    }, 300);
                  }
                }, 500);
              }
            })
            .catch(error => {
              // Still redirect even if payment fails - don't block user
              console.error('Payment error:', error);
              hasRedirected = true;
              window.location.href = jumpUrl;
              if (shouldAutoClose) {
                setTimeout(() => {
                  window.close();
                  if (isMacOSPWA) {
                    setTimeout(() => {
                      countdownUI.classList.add('hidden');
                      redirectCompleteUI.classList.remove('hidden');
                    }, 300);
                  }
                }, 500);
              }
            });
          }
        }, interval);
      })();
    </script>
    """
  end
end
