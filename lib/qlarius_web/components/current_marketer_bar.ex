defmodule QlariusWeb.Components.CurrentMarketerBar do
  use Phoenix.Component

  import QlariusWeb.CoreComponents, only: [icon: 1]

  attr :current_marketer, :map, default: nil

  def current_marketer_bar(assigns) do
    ~H"""
    <div class="bg-base-200 px-6 py-3 border-b border-base-300">
      <%= if @current_marketer do %>
        <div class="flex items-center gap-2">
          <.icon name="hero-check-circle" class="w-5 h-5 text-success" />
          <span class="font-medium">Current Marketer:</span>
          <span class="text-lg">{@current_marketer.business_name}</span>
        </div>
      <% else %>
        <div class="flex items-center gap-2">
          <.icon name="hero-exclamation-circle" class="w-5 h-5 text-warning" />
          <span class="text-base-content/70">No marketer selected</span>
          <span class="text-base-content/50">—</span>
          <a href="/admin/marketers" class="link link-primary text-sm">
            Select a marketer
          </a>
        </div>
      <% end %>
    </div>
    """
  end
end
