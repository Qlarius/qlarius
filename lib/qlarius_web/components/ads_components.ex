defmodule QlariusWeb.Components.AdsComponents do
  use Phoenix.Component
  import QlariusWeb.CoreComponents

  attr :selected_ad_type, :string, required: true
  attr :three_tap_ad_count, :integer, default: 0
  attr :video_ad_count, :integer, default: 0

  def ad_type_tabs(assigns) do
    ~H"""
    <div class="flex justify-center mt-2 mb-6">
      <div role="tablist" class="tabs tabs-boxed bg-base-200 p-1 rounded-lg gap-1">
        <a
          role="tab"
          class={
            if @selected_ad_type == "three_tap",
              do: "tab tab-active bg-base-100 rounded-md !border-1 !border-primary",
              else: "tab !border-1 !border-transparent"
          }
          phx-click="switch_ad_type"
          phx-value-type="three_tap"
        >
          3-Tap
          <%= if @three_tap_ad_count > 0 do %>
            <span class="badge badge-sm ml-2 !bg-sponster-500 !text-white rounded-full !border-0">
              {@three_tap_ad_count}
            </span>
          <% end %>
        </a>
        <a
          role="tab"
          class={
            if @selected_ad_type == "video",
              do: "tab tab-active bg-base-100 rounded-md !border-1 !border-primary",
              else: "tab !border-1 !border-transparent"
          }
          phx-click="switch_ad_type"
          phx-value-type="video"
        >
          Video
          <%= if @video_ad_count > 0 do %>
            <span class="badge badge-sm ml-2 !bg-sponster-500 !text-white rounded-full !border-0">
              {@video_ad_count}
            </span>
          <% end %>
        </a>
      </div>
    </div>
    """
  end

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

  attr :current_video_offer, :map, required: true
  attr :video_payment_collected, :boolean, required: true

  def video_player(assigns) do
    ~H"""
    <div class="mb-4">
      <video
        id="video-player"
        phx-hook="VideoPlayer"
        data-payment-collected={@video_payment_collected}
        class="w-full rounded-lg"
        controls
        poster={
          if @current_video_offer.media_run.media_piece.video_poster_image do
            QlariusWeb.Uploaders.VideoPoster.url(
              {@current_video_offer.media_run.media_piece.video_poster_image,
               @current_video_offer.media_run.media_piece},
              :original
            )
          end
        }
        src={
          QlariusWeb.Uploaders.AdVideo.url(
            {@current_video_offer.media_run.media_piece.video_file,
             @current_video_offer.media_run.media_piece},
            :original
          )
        }
      >
      </video>
    </div>

    <%= if !@video_payment_collected do %>
      <style>
        /* Hide video timeline/scrubber before payment collection */
        #video-player::-webkit-media-controls-timeline {
          display: none !important;
        }
        #video-player::-webkit-media-controls-current-time-display {
          display: none !important;
        }
        #video-player::-webkit-media-controls-time-remaining-display {
          display: none !important;
        }
      </style>
    <% end %>
    """
  end

  attr :current_video_offer, :map, required: true
  attr :show_collection_drawer, :boolean, required: true
  attr :video_payment_collected, :boolean, required: true
  attr :show_replay_button, :boolean, required: true
  attr :closing, :boolean, default: false

  def video_collection_drawer(assigns) do
    ~H"""
    <%= if @show_collection_drawer || @closing do %>
      <div class={[
        "fixed inset-x-0 bottom-0 z-30 flex justify-center",
        if(@closing, do: "animate-slide-down", else: "animate-slide-up")
      ]}>
        <div class="w-full max-w-md h-[320px] bg-base-100 dark:bg-base-200 rounded-t-2xl shadow-2xl border-t-4 border-primary px-6 pt-6 pb-28 pointer-events-auto overflow-hidden">
          <%= if @show_replay_button do %>
            <div class="text-center">
              <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-error/20 mb-4">
                <.icon name="hero-clock" class="w-10 h-10 text-error" />
              </div>
              <h3 class="text-xl font-bold mb-2">Time Expired</h3>
              <p class="text-base-content/70 text-sm mb-4">
                Watch the video again to collect your payment
              </p>
              <button class="btn btn-primary btn-lg w-full rounded-full" phx-click="replay_video">
                <.icon name="hero-arrow-path" class="w-5 h-5 mr-2" />
                Replay Video
              </button>
            </div>
          <% else %>
            <%= if @video_payment_collected do %>
              <div class="text-center mb-6">
                <p class="text-sm text-success font-semibold">
                  Collected to wallet
                </p>
              </div>
            <% else %>
              <div class="text-center mb-6">
                <p class="text-base font-semibold text-base-content">
                  Slide to Collect
                </p>
              </div>
            <% end %>

            <div phx-update="ignore" id="video-slider-container">
              <.slide_to_collect
                offer_id={@current_video_offer.id}
                amount={@current_video_offer.offer_amt}
              />
            </div>

            <%= if @video_payment_collected do %>
              <div class="mt-4">
                <button class="btn btn-outline btn-lg w-full rounded-full" phx-click="replay_video">
                  <.icon name="hero-arrow-path" class="w-5 h-5 mr-2" />
                  Watch Again (Unpaid)
                </button>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end

  attr :offer, :map, required: true
  attr :rate, :any, required: true
  attr :completed, :boolean, required: true

  def video_offer_list_item(assigns) do
    ~H"""
    <li
      class={[
        "list-row transition-all duration-200 !rounded-none",
        if(@completed,
          do: "bg-base-300 cursor-default select-none",
          else: "cursor-pointer hover:bg-base-300 dark:hover:!bg-base-100"
        )
      ]}
      phx-click={if !@completed, do: "open_video_ad"}
      phx-value-offer_id={@offer.id}
    >
      <%= if @completed do %>
        <%!-- Completed state --%>
        <div class="flex flex-col items-start justify-start mr-1">
          <span class="inline-flex items-center justify-center rounded-full w-8 h-8 !bg-green-200 dark:!bg-green-800">
            <.icon name="hero-check" class="h-5 w-5 text-green-600 dark:text-green-300" />
          </span>
        </div>
        <div class="list-col-grow">
          <div class="text-sm font-semibold text-base-content/70 mb-2">
            Attention Paid™
          </div>
          <div class="text-xs text-base-content/50">
            Collected: <span class="font-semibold">${Decimal.round(@offer.offer_amt || Decimal.new("0"), 2)}</span>
          </div>
        </div>
        <div class="flex items-center">
          <div class="text-base-content/30">
            <.icon name="hero-check-circle" class="w-6 h-6" />
          </div>
        </div>
      <% else %>
        <%!-- Available state --%>
        <div class="flex flex-col items-start justify-start mr-1">
          <span class="inline-flex items-center justify-center rounded-full w-8 h-8 !bg-sponster-200 dark:!bg-sponster-800">
            <.icon name="hero-play" class="h-5 w-5 text-base-content" />
          </span>
        </div>
        <div class="list-col-grow">
          <div class="text-2xl font-bold mb-2">
            ${Decimal.round(@offer.offer_amt || Decimal.new("0"), 2)}
          </div>
          <div class="mb-2 text-base-content/50 text-base">
            {@offer.media_run.media_piece.ad_category.ad_category_name}
          </div>
          <div class="flex items-center gap-2">
            <%= if @offer.matching_tags_snapshot && String.contains?(String.downcase(inspect(@offer.matching_tags_snapshot)), "zip code") do %>
              <div class="text-blue-400">
                <.icon name="hero-map-pin-solid" class="w-4 h-4" />
              </div>
            <% end %>
            <div class="text-base-content/50 text-sm">
              {@offer.media_run.media_piece.duration}s · ${Decimal.round(@rate, 3)}/sec
            </div>
          </div>
        </div>
        <div class="flex items-center">
          <div class="text-green-600">
            <.icon name="hero-chevron-double-right" class="w-6 h-6" />
          </div>
        </div>
      <% end %>
    </li>
    """
  end
end
