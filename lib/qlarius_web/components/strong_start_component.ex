defmodule QlariusWeb.Components.StrongStartComponent do
  use Phoenix.Component
  import QlariusWeb.CoreComponents

  attr :progress, :map, required: true
  attr :starter_survey_id, :integer, default: nil
  attr :on_skip, :string, default: "skip_strong_start"
  attr :on_remind, :string, default: "remind_later"
  attr :on_mark_notifications, :string, default: "mark_notifications_done"
  attr :on_mark_referral, :string, default: "mark_referral_done"

  def strong_start(assigns) do
    ~H"""
    <div class="surface-panel surface-panel--padded mb-4">
      <%!-- Header --%>
      <div class="flex justify-between items-center gap-3 mb-2">
        <h2 class="text-lg font-bold tracking-tight text-base-content/50 min-w-0">
          Do these first.
        </h2>
        <div class="flex items-center gap-2 shrink-0">
          <span class="text-sm font-semibold tracking-tight text-base-content/50">
            {@progress.completed_count}/{@progress.total_count}
          </span>
          <img
            src="/images/qadabra_logo_squares_color.svg"
            alt="Qadabra"
            class="w-6 h-6"
          />
        </div>
      </div>
      <p class="text-sm text-base-content/60 mb-3">
        Complete these tasks for a great start.
      </p>

      <%!-- Progress Bar --%>
      <progress
        class="progress progress-primary w-full mb-3 h-2"
        value={@progress.percentage}
        max="100"
      >
      </progress>

      <%!-- Steps Carousel --%>
      <div
        phx-hook="CarouselIndicators"
        id="strong-start-carousel"
        class="w-full flex flex-col items-center justify-center"
      >
        <div class="carousel carousel-center w-full space-x-3 mb-1">
          <%!-- Step 1: Complete ESSENTIALS survey --%>
          <div id="step1" class="carousel-item w-[78%] md:w-[248px]">
            <div class={[
              "flex flex-col gap-2 p-3 rounded-lg transition-all border w-full",
              if(@progress.steps.essentials_survey_completed,
                do: "bg-success/5 border-success/20",
                else: "bg-base-100 border-primary"
              )
            ]}>
              <div class="flex items-center gap-2">
                <div class="flex-shrink-0">
                  <%= if @progress.steps.essentials_survey_completed do %>
                    <.icon name="hero-check-circle-solid" class="w-7 h-7 text-success" />
                  <% else %>
                    <.icon name="hero-check-circle" class="w-7 h-7 text-base-content/30" />
                  <% end %>
                </div>
                <div class="flex-grow min-w-0">
                  <div class="font-bold text-base leading-tight">Tag your "Essentials"</div>
                </div>
              </div>
              <div class="text-sm text-base-content/60 min-h-[2.5rem] leading-snug">
                <%= if @progress.steps.essentials_survey_completed do %>
                  All essential tags added
                <% else %>
                  Add these <span class="font-bold text-primary">{@progress.survey_total}</span>
                  most valuable tags to your MeFile.
                  <span class="font-bold text-primary">{@progress.survey_answered}</span>
                  already tagged.
                <% end %>
              </div>
              <%= if !@progress.steps.essentials_survey_completed do %>
                <.link
                  navigate={
                    if @starter_survey_id do
                      "/me_file_builder?survey_id=#{@starter_survey_id}"
                    else
                      "/me_file"
                    end
                  }
                  class="btn btn-sm btn-primary rounded-full w-full min-h-9 h-9 text-sm"
                >
                  {if @progress.survey_answered == 0, do: "Start", else: "Continue"}
                </.link>
              <% end %>
            </div>
          </div>

          <%!-- Step 2: Check your first ads --%>
          <div id="step2" class="carousel-item w-[78%] md:w-[248px]">
            <div class={[
              "flex flex-col gap-2 p-3 rounded-lg transition-all border w-full",
              if(@progress.steps.first_ad_interacted,
                do: "bg-success/5 border-success/20",
                else: "bg-base-100 border-primary"
              )
            ]}>
              <div class="flex items-center gap-2">
                <div class="flex-shrink-0">
                  <%= if @progress.steps.first_ad_interacted do %>
                    <.icon name="hero-check-circle-solid" class="w-7 h-7 text-success" />
                  <% else %>
                    <.icon name="hero-check-circle" class="w-7 h-7 text-base-content/30" />
                  <% end %>
                </div>
                <div class="flex-grow min-w-0">
                  <div class="font-bold text-base leading-tight">Check your ads</div>
                </div>
              </div>
              <div class="text-sm text-base-content/60 min-h-[2.5rem] leading-snug">
                Sell your attention to your personal sponsors. Fuel your wallet.
              </div>
              <%= if !@progress.steps.first_ad_interacted do %>
                <.link navigate="/ads" class="btn btn-sm btn-primary rounded-full w-full min-h-9 h-9 text-sm">
                  View Ads
                </.link>
              <% end %>
            </div>
          </div>

          <%!-- Step 3: Set up notifications --%>
          <div id="step3" class="carousel-item w-[78%] md:w-[248px]">
            <div class={[
              "flex flex-col gap-2 p-3 rounded-lg transition-all border w-full",
              if(@progress.steps.notifications_configured,
                do: "bg-success/5 border-success/20",
                else: "bg-base-100 border-primary"
              )
            ]}>
              <div class="flex items-center gap-2">
                <div class="flex-shrink-0">
                  <%= if @progress.steps.notifications_configured do %>
                    <.icon name="hero-check-circle-solid" class="w-7 h-7 text-success" />
                  <% else %>
                    <.icon name="hero-check-circle" class="w-7 h-7 text-base-content/30" />
                  <% end %>
                </div>
                <div class="flex-grow min-w-0">
                  <div class="font-bold text-base leading-tight">Set up notifications</div>
                </div>
              </div>
              <div class="text-sm text-base-content/60 min-h-[2.5rem] leading-snug">
                Set up alerts for when you have ads and want to see them.
              </div>
              <%= if !@progress.steps.notifications_configured do %>
                <div class="flex gap-2">
                  <.link
                    navigate="/settings?setting=notifications"
                    class="btn btn-sm btn-primary rounded-full flex-1 min-h-9 h-9 text-sm"
                  >
                    View
                  </.link>
                  <button
                    phx-click={@on_mark_notifications}
                    class="btn btn-sm btn-ghost rounded-full flex-1 min-h-9 h-9 text-sm"
                  >
                    Skip
                  </button>
                </div>
              <% end %>
            </div>
          </div>

          <%!-- Step 4: Create 25 tags --%>
          <div id="step4" class="carousel-item w-[78%] md:w-[248px]">
            <div class={[
              "flex flex-col gap-2 p-3 rounded-lg transition-all border w-full",
              if(@progress.steps.tags_25_reached,
                do: "bg-success/5 border-success/20",
                else: "bg-base-100 border-primary"
              )
            ]}>
              <div class="flex items-center gap-2">
                <div class="flex-shrink-0">
                  <%= if @progress.steps.tags_25_reached do %>
                    <.icon name="hero-check-circle-solid" class="w-7 h-7 text-success" />
                  <% else %>
                    <.icon name="hero-check-circle" class="w-7 h-7 text-base-content/30" />
                  <% end %>
                </div>
                <div class="flex-grow min-w-0">
                  <div class="font-bold text-base leading-tight">Get to {@progress.tag_goal} tags</div>
                </div>
              </div>
              <div class="text-sm text-base-content/60 min-h-[2.5rem] leading-snug">
                Optimize your MeFile by adding more tags. Current: {@progress.tag_count}/{@progress.tag_goal} tags
              </div>
              <%= if !@progress.steps.tags_25_reached do %>
                <.link
                  navigate="/me_file_builder"
                  class="btn btn-sm btn-primary rounded-full w-full min-h-9 h-9 text-sm"
                >
                  Add Tags
                </.link>
              <% end %>
            </div>
          </div>

          <%!-- Step 5: View referral program --%>
          <div id="step5" class="carousel-item w-[78%] md:w-[248px]">
            <div class={[
              "flex flex-col gap-2 p-3 rounded-lg transition-all border w-full",
              if(@progress.steps.referral_viewed,
                do: "bg-success/5 border-success/20",
                else: "bg-base-100 border-primary"
              )
            ]}>
              <div class="flex items-center gap-2">
                <div class="flex-shrink-0">
                  <%= if @progress.steps.referral_viewed do %>
                    <.icon name="hero-check-circle-solid" class="w-7 h-7 text-success" />
                  <% else %>
                    <.icon name="hero-check-circle" class="w-7 h-7 text-base-content/30" />
                  <% end %>
                </div>
                <div class="flex-grow min-w-0">
                  <div class="font-bold text-base leading-tight">Invite some friends</div>
                </div>
              </div>
              <div class="text-sm text-base-content/60 min-h-[2.5rem] leading-snug">
                Spread the word via referrals and feed your wallet.
              </div>
              <%= if !@progress.steps.referral_viewed do %>
                <div class="flex gap-2">
                  <.link
                    navigate="/referrals"
                    class="btn btn-sm btn-primary rounded-full flex-1 min-h-9 h-9 text-sm"
                  >
                    View
                  </.link>
                  <button
                    phx-click={@on_mark_referral}
                    class="btn btn-sm btn-ghost rounded-full flex-1 min-h-9 h-9 text-sm"
                  >
                    Skip
                  </button>
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <%!-- Carousel Indicators --%>
        <div class="flex justify-center gap-1.5 py-2">
          <a
            href="#step1"
            data-indicator="1"
            class="carousel-indicator w-2 h-2 rounded-full bg-base-content/30 hover:bg-base-content/50 transition-all duration-300"
          >
          </a>
          <a
            href="#step2"
            data-indicator="2"
            class="carousel-indicator w-2 h-2 rounded-full bg-base-content/30 hover:bg-base-content/50 transition-all duration-300"
          >
          </a>
          <a
            href="#step3"
            data-indicator="3"
            class="carousel-indicator w-2 h-2 rounded-full bg-base-content/30 hover:bg-base-content/50 transition-all duration-300"
          >
          </a>
          <a
            href="#step4"
            data-indicator="4"
            class="carousel-indicator w-2 h-2 rounded-full bg-base-content/30 hover:bg-base-content/50 transition-all duration-300"
          >
          </a>
          <a
            href="#step5"
            data-indicator="5"
            class="carousel-indicator w-2 h-2 rounded-full bg-base-content/30 hover:bg-base-content/50 transition-all duration-300"
          >
          </a>
        </div>
      </div>

      <%!-- Footer Actions --%>
      <div class="flex justify-between items-center mt-3 pt-3 border-t border-base-300">
        <button
          phx-click={@on_skip}
          class="btn btn-sm btn-ghost !text-base-content/20 hover:!text-error rounded-full text-sm min-h-9 h-9"
        >
          Dismiss forever
        </button>
        <button
          phx-click={@on_remind}
          class="btn btn-sm btn-ghost rounded-full text-sm min-h-9 h-9"
        >
          Remind me later
        </button>
      </div>

      <%!-- Completion Message --%>
      <%= if @progress.completed_count == @progress.total_count do %>
        <div class="alert alert-success mt-3 text-sm">
          <.icon name="hero-check-badge-solid" class="w-6 h-6" />
          <span>
            🎉 Congratulations! You've completed your Strong Start setup.
          </span>
        </div>
      <% end %>
    </div>
    """
  end
end
