defmodule QlariusWeb.Components.StrongStartComponent do
  @moduledoc """
  "Finish setting up" checklist on Home (Strong Start).

  Phone: one row (progress ring, title, next step) that opens the checklist:
  all five steps, the next step's action, and Remind me later / Don't show
  again. Wide containers (56rem+, beside the docked menu) keep it open with the
  steps as a row of tiles; see the `.setup-card` styles in app.css.
  """
  use Phoenix.Component
  import QlariusWeb.CoreComponents

  alias Phoenix.LiveView.JS

  attr :progress, :map, required: true
  attr :starter_survey_id, :integer, default: nil
  attr :on_skip, :string, default: "skip_strong_start"
  attr :on_remind, :string, default: "remind_later"
  attr :on_mark_notifications, :string, default: "mark_notifications_done"
  attr :on_mark_referral, :string, default: "mark_referral_done"

  def strong_start(assigns) do
    steps = steps(assigns)
    next = Enum.find(steps, &(not &1.done))

    assigns =
      assigns
      |> assign(:steps, steps)
      |> assign(:next, next)
      |> assign(
        :pct,
        round(assigns.progress.completed_count / assigns.progress.total_count * 100)
      )

    ~H"""
    <section id="strong-start" class="setup-card surface-panel" aria-labelledby="strong-start-title">
      <%!-- One row: ring, title, next step. Tapping opens the checklist (phone);
           wide containers always show it. --%>
      <button
        type="button"
        class="setup-card__summary"
        aria-expanded="false"
        aria-controls="strong-start-details"
        phx-click={
          JS.toggle_class("is-open", to: "#strong-start")
          |> JS.toggle_attribute({"aria-expanded", "true", "false"})
        }
      >
        <span class="setup-ring" aria-hidden="true">
          <svg viewBox="0 0 44 44">
            <circle class="setup-ring__track" cx="22" cy="22" r="18" />
            <circle
              :if={@pct > 0}
              class="setup-ring__fill"
              cx="22"
              cy="22"
              r="18"
              pathLength="100"
              stroke-dasharray={"#{@pct} 100"}
              transform="rotate(-90 22 22)"
            />
          </svg>
          <span class="setup-ring__label">{@progress.completed_count}/{@progress.total_count}</span>
        </span>
        <span class="min-w-0 flex-1">
          <span id="strong-start-title" class="setup-card__title">Finish setting up</span>
          <span :if={@next} class="setup-card__next">
            Next: {@next.title}{if @next.meta, do: " · #{@next.meta}"}
          </span>
        </span>
        <span class="setup-card__chev"><.icon name="hero-chevron-right" class="h-5 w-5" /></span>
      </button>

      <div id="strong-start-details" class="setup-card__details">
        <ol class="setup-steps">
          <li
            :for={{step, index} <- Enum.with_index(@steps, 1)}
            class={[
              "setup-step",
              step.done && "is-done",
              @next && step.key == @next.key && "is-next"
            ]}
          >
            <.link navigate={step.href} class="setup-step__link">
              <span class="setup-step__mark">
                <.icon :if={step.done} name="hero-check" class="h-3.5 w-3.5" />
                <span :if={not step.done}>{index}</span>
              </span>
              <span class="setup-step__title">{step.title}</span>
              <span :if={step.meta} class="setup-step__meta">{step.meta}</span>
            </.link>
          </li>
        </ol>

        <div :if={@next} class="setup-next">
          <span class="setup-next__icon"><.icon name={@next.icon} class="h-5 w-5" /></span>
          <div class="min-w-0 flex-1">
            <p class="setup-next__title">{@next.title}</p>
            <p class="setup-next__desc">{@next.desc}</p>
          </div>
          <div class="setup-next__actions">
            <.link navigate={@next.href} class="btn btn-primary btn-sm rounded-full px-5">
              {@next.cta}
            </.link>
            <button
              :if={@next.skip}
              type="button"
              phx-click={@next.skip}
              class="btn btn-ghost btn-sm rounded-full"
            >
              Skip
            </button>
          </div>
        </div>

        <div class="setup-card__footer">
          <button type="button" phx-click={@on_remind}>Remind me later</button>
          <button type="button" phx-click={@on_skip}>Don't show again</button>
        </div>
      </div>
    </section>
    """
  end

  defp steps(%{progress: progress, starter_survey_id: survey_id} = assigns) do
    %{steps: done} = progress
    answered = progress.survey_answered
    survey_total = progress.survey_total

    [
      %{
        key: :essentials,
        icon: "hero-identification",
        title: "Tag your Essentials",
        desc:
          if(answered == 0,
            do: "Add the #{survey_total} tags sponsors value most.",
            else: "#{answered} of #{survey_total} tagged. Keep going."
          ),
        meta: "#{answered}/#{survey_total}",
        cta: if(answered == 0, do: "Start", else: "Continue"),
        href: if(survey_id, do: "/me_file_builder?survey_id=#{survey_id}", else: "/me_file"),
        skip: nil,
        done: done.essentials_survey_completed
      },
      %{
        key: :ads,
        icon: "hero-eye",
        title: "Check your ads",
        desc: "Collect from your sponsors to fill your wallet.",
        meta: nil,
        cta: "View ads",
        href: "/ads",
        skip: nil,
        done: done.first_ad_interacted
      },
      %{
        key: :notifications,
        icon: "hero-bell",
        title: "Turn on notifications",
        desc: "Get an alert when new ads arrive.",
        meta: nil,
        cta: "Set up",
        href: "/settings?setting=notifications",
        skip: assigns.on_mark_notifications,
        done: done.notifications_configured
      },
      %{
        key: :tags,
        icon: "hero-tag",
        title: "Reach #{progress.tag_goal} tags",
        desc: "#{progress.tag_count} of #{progress.tag_goal}. More tags bring better offers.",
        meta: "#{min(progress.tag_count || 0, progress.tag_goal)}/#{progress.tag_goal}",
        cta: "Add tags",
        href: "/me_file_builder",
        skip: nil,
        done: done.tags_25_reached
      },
      %{
        key: :referral,
        icon: "hero-user-group",
        title: "Invite friends",
        desc: "Earn $0.01 for every ad your friends complete.",
        meta: nil,
        cta: "Invite",
        href: "/referrals",
        skip: assigns.on_mark_referral,
        done: done.referral_viewed
      }
    ]
  end
end
