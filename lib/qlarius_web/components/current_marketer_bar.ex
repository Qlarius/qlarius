defmodule QlariusWeb.Components.CurrentMarketerBar do
  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: QlariusWeb.Endpoint,
    router: QlariusWeb.Router,
    statics: QlariusWeb.static_paths()

  import QlariusWeb.CoreComponents, only: [icon: 1]

  attr :current_marketer, :any, default: nil
  attr :current_path, :string, required: true

  def current_marketer_bar(assigns) do
    ~H"""
    <div class="bg-base-200 px-6 py-3 border-b border-base-300">
      <div class="flex items-center justify-between gap-6">
        <nav class="flex items-center gap-1">
          <.nav_item
            icon="hero-tag"
            label="Traits"
            path={~p"/marketer/traits"}
            current_path={@current_path}
            disabled={is_nil(@current_marketer)}
          />

          <.arrow_icon direction="right" />

          <.nav_item
            icon="target-bullseye"
            label="Targets"
            path={~p"/marketer/targets"}
            current_path={@current_path}
            disabled={is_nil(@current_marketer)}
          />

          <.arrow_icon direction="right" />

          <.nav_item
            icon="hero-megaphone"
            label="Campaigns"
            path={~p"/marketer/campaigns"}
            current_path={@current_path}
            disabled={is_nil(@current_marketer)}
          />

          <.arrow_icon direction="left" />

          <.nav_item
            icon="hero-numbered-list"
            label="Sequences"
            path={~p"/marketer/sequences"}
            current_path={@current_path}
            disabled={is_nil(@current_marketer)}
          />

          <.arrow_icon direction="left" />

          <.nav_item
            icon="hero-photo"
            label="Media"
            path={~p"/marketer/media"}
            current_path={@current_path}
            disabled={is_nil(@current_marketer)}
          />
        </nav>

        <div class="flex items-center gap-2 shrink-0">
          <%= if @current_marketer do %>
            <.icon name="hero-check-circle" class="w-5 h-5 text-success" />
            <span class="font-medium">Current Marketer:</span>
            <span class="text-lg">{@current_marketer.business_name}</span>
          <% else %>
            <.icon name="hero-exclamation-circle" class="w-5 h-5 text-warning" />
            <span class="text-base-content/70">No marketer selected</span>
            <span class="text-base-content/50">—</span>
            <a href="/admin/marketers" class="link link-primary text-sm">
              Select a marketer
            </a>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :path, :string, required: true
  attr :current_path, :string, required: true
  attr :disabled, :boolean, default: false

  defp nav_item(assigns) do
    assigns = assign(assigns, :is_current, assigns.path == assigns.current_path)

    ~H"""
    <%= if @disabled do %>
      <div class="flex items-center gap-2 px-3 py-2 rounded-lg opacity-40 cursor-not-allowed">
        <%= if @icon == "target-bullseye" do %>
          <svg class="w-5 h-5" viewBox="0 0 20 20" fill="none" stroke="currentColor">
            <circle cx="10" cy="10" r="8.5" stroke-width="1.5" />
            <circle cx="10" cy="10" r="5.5" stroke-width="1.5" />
            <circle cx="10" cy="10" r="2.5" fill="currentColor" />
          </svg>
        <% else %>
          <.icon name={@icon} class="w-5 h-5" />
        <% end %>
        <span class="text-sm font-medium">{@label}</span>
      </div>
    <% else %>
      <.link
        navigate={@path}
        class={[
          "flex items-center gap-2 px-3 py-2 rounded-lg transition-colors",
          @is_current && "bg-primary text-primary-content",
          !@is_current && "hover:bg-base-300"
        ]}
      >
        <%= if @icon == "target-bullseye" do %>
          <svg class="w-5 h-5" viewBox="0 0 20 20" fill="none" stroke="currentColor">
            <circle cx="10" cy="10" r="8.5" stroke-width="1.5" />
            <circle cx="10" cy="10" r="5.5" stroke-width="1.5" />
            <circle cx="10" cy="10" r="2.5" fill="currentColor" />
          </svg>
        <% else %>
          <.icon name={@icon} class="w-5 h-5" />
        <% end %>
        <span class="text-sm font-medium">{@label}</span>
      </.link>
    <% end %>
    """
  end

  attr :direction, :string, required: true

  defp arrow_icon(assigns) do
    ~H"""
    <.icon
      name={if @direction == "right", do: "hero-arrow-right", else: "hero-arrow-left"}
      class="w-4 h-4 text-base-content/30"
    />
    """
  end
end
