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
        InAppClassifier.escape_directions_style(assigns.in_app_browser.family)
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

        <%= if @escape_directions_style == :browser_icon do %>
          <p class="mt-3 text-sm text-base-content/80 leading-relaxed">
            Look for the
            <span class="iab-escape-open-browser-icon" aria-hidden="true">
              <.iab_open_in_browser_icon />
            </span>
            icon at the top or bottom of this screen.
          </p>
        <% else %>
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

  defp iab_open_in_browser_icon(assigns) do
    ~H"""
    <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" class="h-4 w-4">
      <circle cx="12" cy="12" r="8.25" stroke="currentColor" stroke-width="1.75" />
      <path d="M12 5.75 14.1 14.35 12 11.85 9.9 14.35 12 5.75Z" fill="currentColor" />
      <circle cx="12" cy="12" r="1.15" fill="currentColor" />
    </svg>
    """
  end
end
