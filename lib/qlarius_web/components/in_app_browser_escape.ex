defmodule QlariusWeb.Components.InAppBrowserEscape do
  use Phoenix.Component

  import QlariusWeb.CoreComponents

  attr :show, :boolean, required: true
  attr :canonical_url, :string, required: true
  attr :in_app_browser, :map, required: true

  def in_app_browser_escape(%{show: false} = assigns) do
    ~H""
  end

  def in_app_browser_escape(assigns) do
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
          If things get wonky or crowded in this in-app browser window, open this in an external browser window.
        </p>

        <p class="mt-3 text-sm text-base-content/80">
          Usually:<br />
          <kbd class="kbd kbd-sm align-middle mx-0.5">⋯</kbd>
          →
          <span class="font-semibold text-base-content">Open in External Browser</span>
        </p>
      </div>
    </div>
    """
  end
end
