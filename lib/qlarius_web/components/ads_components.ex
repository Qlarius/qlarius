defmodule QlariusWeb.Components.AdsComponents do
  use Phoenix.Component

  attr :offer_id, :integer, required: true
  attr :amount, :any, required: true
  attr :id, :string, default: "slide-to-collect"

  def slide_to_collect(assigns) do
    ~H"""
    <style>
      @keyframes subtle-wiggle {
        0%, 100% { transform: translateX(0px) translateY(-50%); }
        25% { transform: translateX(1px) translateY(-50%); }
        75% { transform: translateX(-1px) translateY(-50%); }
      }
      @keyframes success-pulse {
        0%, 100% { transform: scale(1); }
        50% { transform: scale(1.05); }
      }
      #<%= @id %>-handle.wiggle {
        animation: subtle-wiggle 0.4s ease-in-out infinite;
      }
      #<%= @id %>-handle.disabled {
        animation: none;
        opacity: 0.5;
        cursor: not-allowed !important;
      }
      #<%= @id %>-slider.success {
        animation: success-pulse 0.5s ease-in-out;
      }
      #<%= @id %>-progress.success {
        display: none;
      }
      #<%= @id %>-handle.success {
        background-color: rgb(34 197 94) !important;
      }
      #<%= @id %>-handle-arrow {
        display: block;
      }
      #<%= @id %>-handle-arrow.success {
        display: none;
      }
      #<%= @id %>-handle-amount {
        display: none;
      }
      #<%= @id %>-handle-amount.success {
        display: flex;
      }
      #<%= @id %>-destination {
        display: block;
      }
      #<%= @id %>-destination.success {
        display: none;
      }
      #<%= @id %>-countdown.success {
        display: none;
      }
      #<%= @id %>-checkmark {
        display: none;
      }
      #<%= @id %>-checkmark.success {
        display: flex;
      }
    </style>
    <div class="mt-6 px-4">
      <div
        id={@id}
        phx-hook="SlideToCollect"
        data-offer-id={@offer_id}
        data-amount={@amount}
        class="relative max-w-xs mx-auto"
      >
        <div
          id={"#{@id}-slider"}
          class="relative h-24 bg-base-200 rounded-full overflow-hidden"
        >
          <%!-- Vertical countdown timer background - starts at 100% height, decreases to 0% --%>
          <div
            id={"#{@id}-progress"}
            class="absolute left-0 bottom-0 w-full bg-success/30 transition-all duration-1000 ease-linear"
            style="height: 100%"
          >
          </div>

          <%!-- Countdown timer in center --%>
          <div class="absolute inset-0 flex items-center justify-center pointer-events-none z-10">
            <span class="text-2xl font-bold text-base-content" id={"#{@id}-countdown"}>
              :07
            </span>
          </div>

          <%!-- Checkmark for success state --%>
          <div class="absolute inset-0 flex items-center justify-center pointer-events-none z-10" id={"#{@id}-checkmark"}>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-10 w-10 text-success"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="3"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M5 13l4 4L19 7"
              />
            </svg>
          </div>

          <%!-- Collection amount on right side with dotted circle destination --%>
          <div
            class="absolute right-2 top-1/2 -translate-y-1/2 pointer-events-none z-10"
            id={"#{@id}-destination"}
          >
            <div class="relative flex items-center justify-center w-20 h-20 rounded-full border-4 border-dashed border-primary/40">
              <span class="text-lg font-bold text-success">
                ${Decimal.round(@amount, 2)}
              </span>
            </div>
          </div>

          <%!-- Slider handle --%>
          <div
            id={"#{@id}-handle"}
            class="wiggle absolute left-2 top-1/2 h-20 w-20 bg-primary rounded-full flex items-center justify-center cursor-grab active:cursor-grabbing shadow-lg z-20"
            style="transform: translateX(0px) translateY(-50%)"
          >
            <%!-- Arrow icon (shown by default, hidden on success) --%>
            <svg
              id={"#{@id}-handle-arrow"}
              xmlns="http://www.w3.org/2000/svg"
              class="h-7 w-7 text-primary-content"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M9 5l7 7-7 7"
              />
            </svg>

            <%!-- Amount text (hidden by default, shown on success) --%>
            <span
              id={"#{@id}-handle-amount"}
              class="text-lg font-bold text-white"
            >
              ${Decimal.round(@amount, 2)}
            </span>
          </div>
        </div>

        <div class="text-center text-sm text-base-content/60 mt-3" id={"#{@id}-message"}>
          Slide to collect
        </div>
      </div>
    </div>
    """
  end

  attr :media_piece, :map, required: true
  attr :show_banner, :boolean, default: false

  def three_tap_ad(assigns) do
    ~H"""
    <div class="bg-base-200 dark:bg-base-900/20 rounded-lg overflow-hidden shadow-sm max-w-[340px]">
      <%= if @show_banner && @media_piece.banner_image do %>
        <div class="flex justify-center items-center bg-white">
          <img
            src={
              QlariusWeb.Uploaders.ThreeTapBanner.url(
                {@media_piece.banner_image, @media_piece},
                :original
              )
            }
            alt={@media_piece.title}
            class="w-full h-auto object-cover"
          />
        </div>
      <% end %>

      <div class="p-4">
        <div class="text-blue-600 dark:text-blue-300 mb-1 font-bold text-lg leading-tight">
          <a href={@media_piece.jump_url} target="_blank" class="hover:underline">
            {@media_piece.title}
          </a>
        </div>

        <%= if @media_piece.body_copy do %>
          <div class="text-base-content/70 text-sm mb-1" style="line-height: 1.1rem">
            {@media_piece.body_copy}
          </div>
        <% end %>

        <%= if @media_piece.display_url do %>
          <div class="text-green-500 text-xs mb-1">
            {@media_piece.display_url}
          </div>
        <% end %>

        <%= if @media_piece.jump_url do %>
          <div class="border-t border-base-300/30 mt-2 pt-2">
            <div class="text-xs text-base-content/50">
              <span class="font-semibold">LINK:</span>
              <a href={@media_piece.jump_url} target="_blank" class="link link-primary ml-1 truncate">
                {@media_piece.jump_url}
              </a>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
