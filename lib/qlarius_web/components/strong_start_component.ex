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
    <div class="bg-base-200 rounded-lg p-4 mb-4">
      <%!-- Header --%>
      <div class="flex justify-between items-center mb-2">
        <div class="flex items-center gap-2">
          <img src="/images/qadabra_logo_squares_color.svg" alt="Qadabra" class="w-5 h-5" />
          <h2 class="text-xl font-bold tracking-tight text-base-content/50">
            Do these first.
          </h2>
        </div>
        <div class="text-right">
          <div class="text-xl font-bold tracking-tight text-base-content/50">{@progress.completed_count}/{@progress.total_count}</div>
        </div>
      </div>
      <p class="text-sm text-base-content/60 mb-4">
        Complete the following steps for a great start.
      </p>

      <%!-- Progress Bar --%>
      <progress
        class="progress progress-primary w-full mb-4"
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
        <div class="carousel carousel-center w-full space-x-4 mb-2">
        <%!-- Step 1: Complete ESSENTIALS survey --%>
        <div id="step1" class="carousel-item w-[85%] md:w-[320px]">
          <div class={[
            "flex flex-col gap-3 p-4 rounded-lg transition-all border w-full",
            if(@progress.steps.essentials_survey_completed,
              do: "bg-success/5 border-success/20",
              else: "bg-base-100 border-base-300"
            )
          ]}>
            <div class="flex items-center gap-3">
              <div class="flex-shrink-0">
                <%= if @progress.steps.essentials_survey_completed do %>
                  <.icon name="hero-check-circle-solid" class="w-8 h-8 text-success" />
                <% else %>
                  <.icon name="hero-check-circle" class="w-8 h-8 text-base-content/30" />
                <% end %>
              </div>
              <div class="flex-grow">
                <div class="font-bold text-lg">Complete starter tags</div>
              </div>
            </div>
            <div class="text-sm text-base-content/60 min-h-[2.5rem]">
              <%= if @progress.steps.essentials_survey_completed do %>
                All essential information added
              <% else %>
                {@progress.survey_answered}/{@progress.survey_total} tags filled
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
                class="btn btn-sm btn-primary rounded-full w-full"
              >
                <%= if @progress.survey_answered == 0, do: "Start", else: "Continue" %>
              </.link>
            <% end %>
          </div>
        </div>

        <%!-- Step 2: Check your first ads --%>
        <div id="step2" class="carousel-item w-[85%] md:w-[320px]">
          <div class={[
            "flex flex-col gap-3 p-4 rounded-lg transition-all border w-full",
            if(@progress.steps.first_ad_interacted,
              do: "bg-success/5 border-success/20",
              else: "bg-base-100 border-base-300"
            )
          ]}>
            <div class="flex items-center gap-3">
              <div class="flex-shrink-0">
                <%= if @progress.steps.first_ad_interacted do %>
                  <.icon name="hero-check-circle-solid" class="w-8 h-8 text-success" />
                <% else %>
                  <.icon name="hero-check-circle" class="w-8 h-8 text-base-content/30" />
                <% end %>
              </div>
              <div class="flex-grow">
                <div class="font-bold text-lg">Check your first ads</div>
              </div>
            </div>
            <div class="text-sm text-base-content/60 min-h-[2.5rem]">
              View available advertising offers
            </div>
            <%= if !@progress.steps.first_ad_interacted do %>
              <.link navigate="/ads" class="btn btn-sm btn-primary rounded-full w-full">
                View Ads
              </.link>
            <% end %>
          </div>
        </div>

        <%!-- Step 3: Set up notifications --%>
        <div id="step3" class="carousel-item w-[85%] md:w-[320px]">
          <div class={[
            "flex flex-col gap-3 p-4 rounded-lg transition-all border w-full",
            if(@progress.steps.notifications_configured,
              do: "bg-success/5 border-success/20",
              else: "bg-base-100 border-base-300"
            )
          ]}>
            <div class="flex items-center gap-3">
              <div class="flex-shrink-0">
                <%= if @progress.steps.notifications_configured do %>
                  <.icon name="hero-check-circle-solid" class="w-8 h-8 text-success" />
                <% else %>
                  <.icon name="hero-check-circle" class="w-8 h-8 text-base-content/30" />
                <% end %>
              </div>
              <div class="flex-grow">
                <div class="font-bold text-lg">Set up notifications</div>
              </div>
            </div>
            <div class="text-sm text-base-content/60 min-h-[2.5rem]">
              Receive helpful alerts and notifications
            </div>
            <%= if !@progress.steps.notifications_configured do %>
              <button phx-click={@on_mark_notifications} class="btn btn-sm btn-outline rounded-full w-full">
                Mark Done
              </button>
            <% end %>
          </div>
        </div>

        <%!-- Step 4: Create 25 tags --%>
        <div id="step4" class="carousel-item w-[85%] md:w-[320px]">
          <div class={[
            "flex flex-col gap-3 p-4 rounded-lg transition-all border w-full",
            if(@progress.steps.tags_25_reached,
              do: "bg-success/5 border-success/20",
              else: "bg-base-100 border-base-300"
            )
          ]}>
            <div class="flex items-center gap-3">
              <div class="flex-shrink-0">
                <%= if @progress.steps.tags_25_reached do %>
                  <.icon name="hero-check-circle-solid" class="w-8 h-8 text-success" />
                <% else %>
                  <.icon name="hero-check-circle" class="w-8 h-8 text-base-content/30" />
                <% end %>
              </div>
              <div class="flex-grow">
                <div class="font-bold text-lg">Create {@progress.tag_goal} tags</div>
              </div>
            </div>
            <div class="text-sm text-base-content/60 min-h-[2.5rem]">
              Current: {@progress.tag_count}/{@progress.tag_goal} tags
            </div>
            <%= if !@progress.steps.tags_25_reached do %>
              <.link navigate="/me_file_builder" class="btn btn-sm btn-primary rounded-full w-full">
                Add Tags
              </.link>
            <% end %>
          </div>
        </div>

        <%!-- Step 5: View referral program --%>
        <div id="step5" class="carousel-item w-[85%] md:w-[320px]">
          <div class={[
            "flex flex-col gap-3 p-4 rounded-lg transition-all border w-full",
            if(@progress.steps.referral_viewed,
              do: "bg-success/5 border-success/20",
              else: "bg-base-100 border-base-300"
            )
          ]}>
            <div class="flex items-center gap-3">
              <div class="flex-shrink-0">
                <%= if @progress.steps.referral_viewed do %>
                  <.icon name="hero-check-circle-solid" class="w-8 h-8 text-success" />
                <% else %>
                  <.icon name="hero-check-circle" class="w-8 h-8 text-base-content/30" />
                <% end %>
              </div>
              <div class="flex-grow">
                <div class="font-bold text-lg">Referral program</div>
              </div>
            </div>
            <div class="text-sm text-base-content/60 min-h-[2.5rem]">
              Earn rewards by inviting friends
            </div>
            <%= if !@progress.steps.referral_viewed do %>
              <div class="flex gap-2">
                <.link navigate="/referrals" class="btn btn-sm btn-primary rounded-full flex-1">
                  View
                </.link>
                <button phx-click={@on_mark_referral} class="btn btn-sm btn-ghost rounded-full flex-1">
                  Skip
                </button>
              </div>
            <% end %>
          </div>
        </div>
        </div>

        <%!-- Carousel Indicators --%>
        <div class="flex justify-center gap-2 py-4">
          <a
            href="#step1"
            data-indicator="1"
            class="carousel-indicator w-3 h-3 rounded-full bg-base-content/30 hover:bg-base-content/50 transition-all duration-300"
          >
          </a>
          <a
            href="#step2"
            data-indicator="2"
            class="carousel-indicator w-3 h-3 rounded-full bg-base-content/30 hover:bg-base-content/50 transition-all duration-300"
          >
          </a>
          <a
            href="#step3"
            data-indicator="3"
            class="carousel-indicator w-3 h-3 rounded-full bg-base-content/30 hover:bg-base-content/50 transition-all duration-300"
          >
          </a>
          <a
            href="#step4"
            data-indicator="4"
            class="carousel-indicator w-3 h-3 rounded-full bg-base-content/30 hover:bg-base-content/50 transition-all duration-300"
          >
          </a>
          <a
            href="#step5"
            data-indicator="5"
            class="carousel-indicator w-3 h-3 rounded-full bg-base-content/30 hover:bg-base-content/50 transition-all duration-300"
          >
          </a>
        </div>
      </div>

      <%!-- Footer Actions --%>
      <div class="flex justify-between items-center mt-4 pt-4 border-t border-base-300">
        <button phx-click={@on_remind} class="btn btn-sm btn-ghost rounded-full">
          Remind me later
        </button>
        <button phx-click={@on_skip} class="btn btn-sm btn-ghost text-error rounded-full">
          Skip forever
        </button>
      </div>

      <%!-- Completion Message --%>
      <%= if @progress.completed_count == @progress.total_count do %>
        <div class="alert alert-success mt-4">
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
