defmodule QlariusWeb.Components.AdsComponents do
  @moduledoc """
  Components and helpers for ad display across the application.
  """
  use Phoenix.Component
  import QlariusWeb.CoreComponents
  import QlariusWeb.Money

  @doc """
  Determines whether to show ad type tabs and which ad type to select by default.

  Returns a tuple: `{show_tabs, selected_ad_type}`

  Logic:
  - Both ad types available: show tabs, default to "three_tap"
  - Only 3-tap available: no tabs, select "three_tap"
  - Only video available: no tabs, select "video"
  - Neither available: no tabs, select "three_tap"

  ## Examples

      iex> determine_ad_type_display(5, 3)
      {true, "three_tap"}

      iex> determine_ad_type_display(0, 3)
      {false, "video"}

      iex> determine_ad_type_display(5, 0)
      {false, "three_tap"}
  """
  def determine_ad_type_display(three_tap_count, video_count) do
    three_tap_count = three_tap_count || 0
    video_count = video_count || 0

    has_three_tap = three_tap_count > 0
    has_video = video_count > 0

    show_tabs = has_three_tap && has_video

    selected_ad_type =
      cond do
        has_three_tap -> "three_tap"
        has_video -> "video"
        true -> "three_tap"
      end

    {show_tabs, selected_ad_type}
  end

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
  # See docs/embedded_theming.md for force_light/pub_theme strategy
  attr :force_light, :boolean, default: false

  def three_tap_ad(assigns) do
    ~H"""
    <div class={[
      "bg-base-200 rounded-lg overflow-hidden shadow-sm max-w-[340px]",
      if(!@force_light, do: "dark:bg-base-900/20")
    ]}>
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
        <div class={[
          "text-blue-600 mb-1 font-bold text-lg leading-tight",
          if(!@force_light, do: "dark:text-blue-300")
        ]}>
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

  attr :show_replay_button, :boolean, default: false

  def video_player(assigns) do
    ~H"""
    <div class="mb-4">
      <video
        id="video-player"
        phx-hook="VideoPlayer"
        data-payment-collected={@video_payment_collected}
        data-is-replay={@show_replay_button || @video_payment_collected}
        class="w-full rounded-lg animate-fade-in"
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

    <%!-- Reserve space for replay buttons to prevent layout shift --%>
    <div class="text-center mb-4 min-h-[64px] flex items-center justify-center">
      <div
        class={[
          "w-full transition-opacity duration-500",
          if(@show_replay_button || @video_payment_collected, do: "opacity-100", else: "opacity-0 pointer-events-none")
        ]}
      >
        <%= if @show_replay_button do %>
          <button
            class="btn btn-primary btn-lg w-full rounded-full"
            phx-click="replay_video"
          >
            <.icon name="hero-arrow-path" class="w-5 h-5 mr-2" />
            Replay Video
          </button>
        <% else %>
          <button
            class="btn btn-outline btn-lg w-full rounded-full"
            phx-click="replay_video"
          >
            <.icon name="hero-arrow-path" class="w-5 h-5 mr-2" />
            Watch Again (Unpaid)
          </button>
        <% end %>
      </div>
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
  attr :has_bottom_dock, :boolean, default: true
  # See docs/embedded_theming.md for force_light/pub_theme strategy
  attr :force_light, :boolean, default: false

  def video_collection_drawer(assigns) do
    ~H"""
    <%= if @show_collection_drawer || @closing do %>
      <div class={[
        "fixed inset-x-0 bottom-0 z-[60] flex justify-center",
        if(@closing, do: "animate-slide-down", else: "animate-slide-up")
      ]}>
        <div
          data-theme={if @force_light, do: "light"}
          class={[
            "w-full max-w-md h-[240px] bg-base-100 rounded-t-2xl shadow-2xl border-t-4 border-primary px-6 pt-6 pointer-events-auto overflow-hidden",
            if(!@force_light, do: "dark:bg-base-200"),
            if(@has_bottom_dock, do: "pb-[50px]", else: "pb-4")
          ]}
        >
          <div class="relative">
            <%!-- Wrapper for drawer content with fade animation --%>
            <div class="transition-opacity duration-500 opacity-100">
              <%= if @show_replay_button do %>
                <%!-- Time Expired State --%>
                <div class="text-center">
                  <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-error/20 mb-4">
                    <.icon name="hero-clock" class="w-10 h-10 text-error" />
                  </div>
                  <h3 class="text-xl font-bold mb-2">Time Expired</h3>
                  <p class="text-base-content/70 text-sm mb-4">
                    Watch the video again to collect your payment
                  </p>
                </div>
              <% else %>
                <%!-- Collection Slider State --%>
                <div id="video-slider-section">
                  <%!-- Message text --%>
                  <div class="text-center mb-6">
                    <p
                      class={[
                        "text-base font-semibold",
                        if(@video_payment_collected, do: "text-success", else: "text-base-content")
                      ]}
                    >
                      <%= if @video_payment_collected do %>
                        Collected to Wallet
                      <% else %>
                        Slide to Collect
                      <% end %>
                    </p>
                  </div>

                  <%!-- Slider --%>
                  <div phx-update="ignore" id="video-slider-container">
                    <.slide_to_collect
                      offer_id={@current_video_offer.id}
                      amount={@current_video_offer.offer_amt}
                    />
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  attr :offer, :map, required: true
  attr :rate, :any, required: true
  attr :completed, :boolean, required: true
  attr :me_file_id, :integer, default: nil
  attr :recipient, :any, default: nil
  # See docs/embedded_theming.md for force_light/pub_theme strategy
  attr :force_light, :boolean, default: false

  def video_offer_list_item(assigns) do
    ~H"""
    <li
      class={[
        "list-row transition-all duration-200 !rounded-none h-[120px]",
        if(@completed,
          do: ["bg-base-300 cursor-default select-none", if(!@force_light, do: "dark:!bg-base-300")],
          else: ["bg-base-200 cursor-pointer hover:bg-base-300", if(!@force_light, do: "dark:!bg-base-200 dark:hover:!bg-base-100")]
        )
      ]}
      phx-click={if !@completed, do: "open_video_ad"}
      phx-value-offer_id={@offer.id}
    >
      <%= if @completed do %>
        <%!-- Completed state - matches 3-tap phase 3 layout --%>
        <div class="flex items-center gap-4 w-full px-2">
          <%!-- Checkmark on left --%>
          <div class="flex-shrink-0 text-green-500">
            <.icon name="hero-check" class="w-8 h-8" />
          </div>
          <%!-- Text content on right with fixed width for alignment --%>
          <div class="flex flex-col justify-center min-w-[160px]">
            <div class="font-semibold text-sm text-gray-400">
              Attention Paid™
            </div>
            <% # Get totals from Video context
            {me_file_collect_total, recipient_collect_total} =
              if @me_file_id do
                Qlarius.Sponster.Ads.Video.calculate_offer_totals(@offer.id, @me_file_id, @recipient)
              else
                {Decimal.new("0"), nil}
              end %>
            <div class="text-sm text-gray-400">
              Collected: <span class="font-semibold">{format_usd(me_file_collect_total)}</span>
            </div>
            <%= if @recipient && recipient_collect_total do %>
              <div class="text-sm text-gray-400">
                Given: <span class="font-semibold">{format_usd(recipient_collect_total)}</span>
              </div>
            <% end %>
          </div>
        </div>
      <% else %>
        <%!-- Available state --%>
        <div class="flex flex-col items-start justify-start mr-1">
          <span class={[
            "inline-flex items-center justify-center rounded-full w-8 h-8 !bg-sponster-200",
            if(!@force_light, do: "dark:!bg-sponster-800")
          ]}>
            <.icon name="hero-film" class="h-5 w-5 text-base-content" />
          </span>
        </div>
        <div class="list-col-grow flex flex-col justify-center">
          <div class="text-2xl font-bold mb-1">
            ${Decimal.round(@offer.offer_amt || Decimal.new("0"), 2)}
          </div>
          <div class="mb-1 text-base-content/50 text-base">
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
