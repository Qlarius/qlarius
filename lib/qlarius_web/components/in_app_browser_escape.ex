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
          Wallet and payments work best in Safari or Chrome. Use the button below, or copy the link and paste it into your browser.
        </p>
        <div class="px-4 pb-4 flex flex-col gap-2">
          <%= case @in_app_browser.os do %>
            <% :ios -> %>
              <button
                type="button"
                phx-click="iab_escape_open_external"
                phx-value-kind="ios"
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
          <div class="flex gap-2 items-stretch">
            <input
              id="iab-escape-url-field"
              type="text"
              readonly
              class="input input-bordered input-sm flex-1 font-mono text-xs"
              value={@canonical_url}
            />
            <button
              type="button"
              id="iab-escape-copy-btn"
              class="btn btn-outline btn-sm shrink-0"
              phx-hook="CopyToClipboard"
              data-target="iab-escape-url-field"
            >
              Copy
            </button>
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
