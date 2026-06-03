defmodule QlariusWeb.Components.MobileBottomNav do
  @moduledoc """
  Floating pill-shaped bottom navigation with frosted glass styling.

  Fixed to the viewport bottom and overlays page content; scroll regions use
  `--mobile-bottom-nav-offset` for bottom clearance. Styling lives in `app.css`:
  a frosted `backdrop-filter: blur()` layer with gradient highlights, applied
  consistently across browsers (no JS, no per-browser refraction).
  """
  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: QlariusWeb.Endpoint,
    router: QlariusWeb.Router,
    statics: QlariusWeb.static_paths()

  import QlariusWeb.CoreComponents, only: [icon: 1]

  alias Phoenix.LiveView.JS

  attr :class, :string, default: ""
  slot :inner_block, required: true

  def mobile_bottom_nav(assigns) do
    ~H"""
    <div class={["mobile-bottom-nav-area", @class]}>
      <nav class="mobile-bottom-nav" aria-label="Main navigation">
        <div class="mobile-bottom-nav__track">
          <div class="mobile-bottom-nav__glass-backdrop" aria-hidden="true"></div>
          {render_slot(@inner_block)}
        </div>
      </nav>
    </div>
    """
  end

  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :path, :string, default: nil
  attr :on_click, :any, default: nil
  attr :active, :boolean, default: false
  attr :badge, :integer, default: nil

  def mobile_bottom_nav_item(assigns) do
    ~H"""
    <button
      type="button"
      class={[
        "mobile-bottom-nav__item",
        @active && "mobile-bottom-nav__item--active"
      ]}
      phx-click={@on_click || JS.navigate(@path)}
      aria-current={if(@active, do: "page", else: nil)}
      aria-label={@label}
    >
      <.icon name={@icon} class="mobile-bottom-nav__icon" />
      <span class="mobile-bottom-nav__label">{@label}</span>
      <span
        :if={@badge && @badge > 0}
        class="mobile-bottom-nav__badge"
      >
        {@badge}
      </span>
    </button>
    """
  end
end
