defmodule QlariusWeb.Components.InAppBrowserEscape do
  use Phoenix.Component

  import QlariusWeb.CoreComponents

  alias Qlarius.Browsers.InAppEscapeUrls

  attr :show, :boolean, required: true
  attr :canonical_url, :string, required: true
  attr :in_app_browser, :map, required: true

  def in_app_browser_escape(%{show: false} = assigns) do
    ~H""
  end

  def in_app_browser_escape(assigns) do
    intent_href =
      if assigns.in_app_browser.os == :android do
        InAppEscapeUrls.android_chrome_intent(assigns.canonical_url)
      else
        nil
      end

    assigns = assign(assigns, :intent_href, intent_href)

    ~H"""
    <div
      id="qlarius-in-app-escape"
      class="fixed inset-x-0 bottom-0 z-[60] px-3 pb-[max(0.75rem,env(safe-area-inset-bottom))] pointer-events-none"
      role="region"
      aria-labelledby="qlarius-in-app-escape-title"
      phx-hook="InAppEscapeDismissPersist"
    >
      <div class="pointer-events-auto max-w-lg mx-auto rounded-t-2xl shadow-2xl border border-base-300 bg-base-100 text-base-content">
        <div class="px-4 pt-4 pb-3 border-b border-base-200 flex items-start justify-between gap-2">
          <h2 id="qlarius-in-app-escape-title" class="text-base font-semibold leading-snug pr-2">
            Open in your browser
          </h2>
          <button
            type="button"
            phx-click="iab_escape_dismiss"
            class="btn btn-ghost btn-sm btn-circle shrink-0"
            aria-label="Dismiss"
          >
            <.icon name="hero-x-mark" class="w-5 h-5" />
          </button>
        </div>

        <p class="px-4 py-3 text-sm text-base-content/80">
          <%= if @in_app_browser.family == :reddit do %>
            Reddit’s in-app browser can block sign-in. Open this page in
            Safari or Chrome: tap <kbd class="kbd kbd-sm align-middle">⋯</kbd>
            (often top right) → <span class="font-semibold">Open in external browser</span>
            or similar.
          <% else %>
            Should work fine here, but works better in your browser. Tap the menu
            <kbd class="kbd kbd-sm align-middle">⋯</kbd>
            → <span class="font-semibold">Open in Browser</span>.
          <% end %>
        </p>

        <div class="px-4 pb-4 flex flex-col gap-2">
          <%= case @in_app_browser.os do %>
            <% :ios -> %>
              <%!--
                iOS button no longer routes through the LiveView handler
                because Meta's webviews (IG/FB) currently block single-shot
                `x-safari-https://` redirects on iOS 26.x+. The JS hook
                attempts multiple schemes in quick succession, watches the
                Page Visibility API, and falls back to the "⋯ menu" hint
                below if nothing happened. Android keeps the server path
                because `intent://…` to Chrome still works reliably.
              --%>
              <button
                type="button"
                id="iab-escape-ios-btn"
                phx-hook="IabEscapeIos"
                data-canonical-url={@canonical_url}
                data-fail-hint-id="iab-escape-fail-hint"
                class="btn btn-primary btn-block rounded-xl"
              >
                Open in Safari
              </button>
            <% :android -> %>
              <%= if @intent_href do %>
                <button
                  type="button"
                  phx-click="iab_escape_open_external"
                  phx-value-kind="android_intent"
                  class="btn btn-primary btn-block rounded-xl"
                >
                  Open in Chrome
                </button>
              <% else %>
                <button
                  type="button"
                  phx-click="iab_escape_open_external"
                  phx-value-kind="android_https"
                  class="btn btn-primary btn-block rounded-xl"
                >
                  Open in browser
                </button>
              <% end %>
            <% _ -> %>
              <button
                type="button"
                phx-click="iab_escape_open_external"
                phx-value-kind="https"
                class="btn btn-primary btn-block rounded-xl"
              >
                Open in browser
              </button>
          <% end %>

          <%!--
            Revealed by the `IabEscapeIos` hook when the multi-scheme
            handoff doesn't move the user out of the webview within
            ~1.5s. We deliberately don't offer copy-link here — users
            can reach the webview's own "Open in Browser" in fewer
            taps than a paste round-trip.
          --%>
          <div
            id="iab-escape-fail-hint"
            class="hidden rounded-lg border border-warning/30 bg-warning/10 px-3 py-2 text-sm text-base-content"
            role="status"
            aria-live="polite"
          >
            Didn't open? Tap <kbd class="kbd kbd-sm align-middle">⋯</kbd>
            in the top right → <span class="font-semibold">Open in Browser</span>.
          </div>

          <button type="button" phx-click="iab_escape_dismiss" class="btn btn-ghost btn-sm">
            Continue here anyway
          </button>
        </div>
      </div>
    </div>
    """
  end
end
