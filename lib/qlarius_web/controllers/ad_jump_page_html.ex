defmodule QlariusWeb.AdJumpPageHTML do
  use QlariusWeb, :html

  attr :offer, :any, required: true
  attr :recipient_id, :string, default: nil
  attr :use_location_replace, :boolean, default: true
  attr :autosplit_disabled, :boolean, default: false

  def jump(assigns) do
    ~H"""
    <div
      id="jump-page"
      class="max-w-md mx-auto bg-base-50 p-8 flex flex-col items-center justify-center text-center space-y-6 min-h-screen"
      data-offer-id={@offer.id}
      data-recipient-id={@recipient_id || ""}
      data-jump-url={@offer.media_piece.jump_url}
      data-csrf={Plug.CSRFProtection.get_csrf_token()}
      data-use-location-replace={to_string(@use_location_replace)}
      data-autosplit-disabled={to_string(@autosplit_disabled)}
    >
      <%!-- Countdown UI (shown initially) --%>
      <div id="countdown-ui">
        <h2 class="text-2xl font-semibold text-base-content/70">
          Be careful out there!
        </h2>

        <img
          src={~p"/images/qlarius_app_icon_180.png"}
          width="100"
          height="71"
          class="my-6 block mx-auto"
        />

        <p class="text-base-content/50">Leaving the no-tracking safety of Qadabra.</p>

        <div class="w-full mt-6">
          <p class="text-sm text-base-content/60 mb-2">
            Redirecting in <span id="countdown">2</span> seconds...
          </p>
          <progress id="progress-bar" class="progress progress-primary w-full" value="0" max="100">
          </progress>
        </div>
      </div>

      <%!-- Collect failed — no payment; user can retry or open advertiser without earning --%>
      <div id="collect-error-ui" class="hidden w-full space-y-4">
        <h2 class="text-xl font-semibold text-warning">
          Could not complete your visit reward
        </h2>
        <p id="collect-error-message" class="text-sm text-base-content/70">
          Something went wrong processing this jump. You can try again or open the link directly.
        </p>
        <button type="button" id="retry-collect-btn" class="btn btn-primary btn-block rounded-xl">
          Try again
        </button>
        <p class="text-xs text-base-content/50">
          <a id="advertiser-fallback-link" href={@offer.media_piece.jump_url} class="link link-hover">
            Open advertiser site (visit may not earn reward)
          </a>
        </p>
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
        const datasetJumpUrl = container.dataset.jumpUrl;
        const csrfToken = container.dataset.csrf;
        const useLocationReplace = container.dataset.useLocationReplace === 'true';
        const autosplitDisabled = container.dataset.autosplitDisabled === 'true';

        const progressBar = document.getElementById('progress-bar');
        const countdown = document.getElementById('countdown');
        const countdownUI = document.getElementById('countdown-ui');
        const collectErrorUI = document.getElementById('collect-error-ui');
        const collectErrorMessage = document.getElementById('collect-error-message');
        const retryCollectBtn = document.getElementById('retry-collect-btn');
        const advertiserFallbackLink = document.getElementById('advertiser-fallback-link');
        const redirectCompleteUI = document.getElementById('redirect-complete-ui');
        let hasRedirected = false;

        const isMacOS = navigator.platform.toUpperCase().indexOf('MAC') >= 0;
        const isStandalone = window.navigator.standalone === true ||
                            window.matchMedia('(display-mode: standalone)').matches;
        const isMacOSPWA = isMacOS && isStandalone;
        const isMobile = /iPhone|iPad|iPod|Android/i.test(navigator.userAgent) ||
          (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
        const shouldAutoClose = isStandalone && !isMobile;

        document.addEventListener('visibilitychange', function() {
          if (document.visibilityState === 'visible' && hasRedirected) {
            window.location.href = '/ads';
          }
        });

        function showCollectError(message) {
          clearInterval(window.__jumpPageTimer);
          countdownUI.classList.add('hidden');
          collectErrorUI.classList.remove('hidden');
          if (message) collectErrorMessage.textContent = message;
        }

        function navigateToAdvertiser(url) {
          hasRedirected = true;
          if (useLocationReplace) {
            window.location.replace(url);
          } else {
            window.location.href = url;
          }
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
        }

        function runCollect() {
          // Do not send Accept: application/json — `:browser` uses
          // `plug :accepts, ["html"]` which rejects that with 406 before the controller runs.
          return fetch('/jump/collect', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'x-csrf-token': csrfToken
            },
            credentials: 'same-origin',
            body: JSON.stringify({
              offer_id: offerId,
              recipient_id: recipientId,
              autosplit: autosplitDisabled ? '0' : undefined
            })
          }).then(async (response) => {
            let data = {};
            try {
              data = await response.json();
            } catch (_e) {}

            if (!response.ok) {
              const msg = data.error || ('Request failed (' + response.status + ')');
              throw new Error(msg);
            }
            if (!data.success || !data.jump_url) {
              throw new Error(data.error || 'Invalid response from server');
            }
            return data;
          });
        }

        function startCountdownThenCollect() {
          let timeLeft = 2000;
          const interval = 50;
          window.__jumpPageTimer = setInterval(() => {
            timeLeft -= interval;
            const progress = ((2000 - timeLeft) / 2000) * 100;
            progressBar.value = progress;
            countdown.textContent = Math.ceil(timeLeft / 1000);

            if (timeLeft <= 0) {
              clearInterval(window.__jumpPageTimer);
              runCollect()
                .then((data) => {
                  navigateToAdvertiser(data.jump_url);
                })
                .catch((error) => {
                  console.error('Jump collect error:', error);
                  showCollectError(error.message || 'Could not complete this jump.');
                });
            }
          }, interval);
        }

        retryCollectBtn.addEventListener('click', () => {
          collectErrorUI.classList.add('hidden');
          countdownUI.classList.remove('hidden');
          progressBar.value = 0;
          countdown.textContent = '2';
          startCountdownThenCollect();
        });

        if (advertiserFallbackLink) {
          advertiserFallbackLink.href = datasetJumpUrl;
        }

        startCountdownThenCollect();
      })();
    </script>
    """
  end
end
