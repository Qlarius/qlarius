defmodule QlariusWeb.WhyYouPanel do
  @moduledoc """
  Content-match disclosure for discovery suggestions.

  In-app mobile uses the shared `#right-sidebar` drawer (same chrome and
  transitions as wallet Transaction Details). Other hosts use a centered modal.
  """
  use QlariusWeb, :html

  import QlariusWeb.MeFileHTML, only: [parent_traits_display: 1]

  attr :show, :boolean, required: true
  attr :why_you, :map, default: nil
  attr :content, :map, default: nil

  def content_details_overlay(assigns) do
    ~H"""
    <div
      :if={@show}
      id="why-you-modal"
      class="fixed inset-0 z-[200] flex items-center justify-center p-4"
    >
      <button
        type="button"
        class="absolute inset-0 bg-black/40"
        aria-label="Close"
        phx-click="close_why_you"
      />
      <div class="relative z-10 flex max-h-[90vh] w-full max-w-lg flex-col overflow-hidden bg-base-100 rounded-box shadow-2xl">
        <div class="flex items-center justify-between border-b border-base-300 px-5 py-4">
          <h3 class="text-lg font-semibold">Why you?</h3>
          <button
            type="button"
            class="btn btn-circle btn-ghost btn-sm"
            aria-label="Close"
            phx-click="close_why_you"
          >
            <.icon name="hero-x-mark" class="h-5 w-5" />
          </button>
        </div>
        <div class="flex-1 overflow-y-auto px-5 py-4 space-y-4">
          <.content_details_body why_you={@why_you} content={@content} />
        </div>
      </div>
    </div>
    """
  end

  attr :why_you, :map, default: nil
  attr :content, :map, default: nil

  def content_details_body(assigns) do
    ~H"""
    <div :if={@content}>
      <h4 class="text-sm font-semibold text-base-content/60 mb-2 px-0.5">Show</h4>
      <.surface_panel padding={false} class="overflow-hidden">
        <div class="flex items-start gap-3 p-3">
          <img
            :if={@content[:image_src]}
            src={@content.image_src}
            alt=""
            class="h-20 w-20 shrink-0 rounded-lg object-cover bg-base-300/40"
          />
          <div class="min-w-0 py-0.5">
            <p class="text-sm font-medium leading-snug">{@content[:title]}</p>
            <p :if={@content[:subtitle]} class="text-xs text-base-content/60 mt-0.5 truncate">
              {@content.subtitle}
            </p>
            <p :if={@content[:detail]} class="text-xs text-base-content/50 mt-0.5">
              {@content.detail}
            </p>
            <p
              :if={@content[:price_info] && @content.price_info[:min_price]}
              class="text-xs font-medium text-widget-700 mt-1"
            >
              from {@content.price_info.min_price}
            </p>
          </div>
        </div>
      </.surface_panel>
    </div>

    <div>
      <h4 class="text-sm font-semibold text-base-content/60 mb-2 px-0.5">
        Matching Tags (Why you?)
      </h4>
      <%= if @why_you && @why_you.parent_traits != [] do %>
        <.surface_panel padding={false}>
          <.parent_traits_display
            parent_traits={@why_you.parent_traits}
            tag_display_mode="tag"
            readonly
          />
        </.surface_panel>
      <% else %>
        <.surface_panel>
          <p class="text-sm text-base-content/60">No matching info found.</p>
        </.surface_panel>
      <% end %>
    </div>
    """
  end
end
