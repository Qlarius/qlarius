defmodule QlariusWeb.Components.InAppBrowserEscape do
  use Phoenix.Component

  import QlariusWeb.CoreComponents

  alias Qlarius.Browsers.InAppClassifier

  attr :show, :boolean, required: true
  attr :canonical_url, :string, required: true
  attr :in_app_browser, :map, required: true

  def in_app_browser_escape(%{show: false} = assigns) do
    ~H""
  end

  def in_app_browser_escape(assigns) do
    assigns =
      assigns
      |> assign(:platform_name, InAppClassifier.display_name(assigns.in_app_browser.family))
      |> assign(
        :escape_directions_style,
        InAppClassifier.escape_directions_style(
          assigns.in_app_browser.family,
          assigns.in_app_browser.os
        )
      )

    ~H"""
    <div
      id="qlarius-in-app-escape"
      class="iab-escape-popover"
      role="presentation"
      phx-hook="InAppEscapePopover"
      aria-hidden="true"
    >
      <div class="iab-escape-popover__backdrop" data-iab-escape-backdrop aria-hidden="true" />
      <div
        class="iab-escape-popover__panel flex flex-col items-center text-center"
        data-iab-escape-panel
        role="dialog"
        aria-modal="true"
        aria-labelledby="qlarius-in-app-escape-title"
      >
        <button
          type="button"
          data-iab-escape-dismiss
          class="btn btn-ghost btn-sm btn-circle absolute top-2 right-2 shrink-0"
          aria-label="Dismiss"
        >
          <.icon name="hero-x-mark" class="w-5 h-5" />
        </button>

        <img
          src="/images/qlink_logo_color_horiz.svg"
          alt="Qlink"
          class="h-8 w-auto max-w-[11rem] mb-4"
        />

        <h2 id="qlarius-in-app-escape-title" class="text-base font-semibold leading-snug text-base-content w-full">
          Might be fine here, but...
        </h2>

        <p class="mt-2 text-sm text-base-content/80 leading-relaxed">
          <%= if @platform_name do %>
            If things get wonky or crowded in this in-app ({@platform_name}) browser window, open this page in an external browser window.
          <% else %>
            If things get wonky or crowded in this in-app browser window, open this page in an external browser window.
          <% end %>
        </p>

        <%= case @escape_directions_style do %>
          <% :ios_browser_icon -> %>
            <p class="mt-3 text-sm text-base-content/80 leading-relaxed">
              Look for the
              <span class="iab-escape-open-browser-icon" aria-hidden="true">
                <.iab_safari_compass_icon />
              </span>
              icon at the top or bottom of this screen.
            </p>
          <% :android_browser_menu -> %>
            <p class="mt-3 text-sm text-base-content/80 leading-relaxed">
              Usually:
              <kbd class="kbd kbd-sm align-middle mx-0.5">⋮</kbd>
              →
              <span class="font-semibold text-base-content">Open in browser</span>
              <span class="text-base-content/70">, or look for the</span>
              <span class="iab-escape-open-browser-icon iab-escape-open-browser-icon--android" aria-hidden="true">
                <.iab_android_open_browser_icon />
              </span>
              <span class="text-base-content/70">icon in the toolbar.</span>
            </p>
          <% _ -> %>
            <p class="mt-3 text-sm text-base-content/80">
              Usually:<br />
              <kbd class="kbd kbd-sm align-middle mx-0.5">⋯</kbd>
              →
              <span class="font-semibold text-base-content">Open in External Browser</span>
            </p>
        <% end %>
      </div>
    </div>
    """
  end

  # Safari / iOS in-app toolbar: circle + tilted compass needle + center hub (see iOS X/Reddit IAB).
  defp iab_safari_compass_icon(assigns) do
    ~H"""
    <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" class="h-[1.05rem] w-[1.05rem]" aria-hidden="true">
      <circle cx="12" cy="12" r="8.85" stroke="currentColor" stroke-width="1.5" />
      <path
        d="M12 5.85 15.55 12 12 18.15 8.45 12 12 5.85Z"
        fill="currentColor"
      />
      <circle cx="12" cy="12" r="1.2" fill="var(--color-base-200, #f5f5f5)" />
    </svg>
    """
  end

  # Android in-app / Chrome Custom Tab: "open in browser" (box with outward arrow).
  defp iab_android_open_browser_icon(assigns) do
    ~H"""
    <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" class="h-[1.05rem] w-[1.05rem]" aria-hidden="true">
      <path
        d="M8.5 15.5H6.75A1.75 1.75 0 0 1 5 13.75V6.75A1.75 1.75 0 0 1 6.75 5h6.75A1.75 1.75 0 0 1 15.25 6.75V8.5"
        stroke="currentColor"
        stroke-width="1.5"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
      <path
        d="M11 13h6.25V6.75M11 13 18.5 5.5"
        stroke="currentColor"
        stroke-width="1.75"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
    </svg>
    """
  end
end
