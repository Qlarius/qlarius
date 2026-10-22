defmodule QlariusWeb.Components.NudgeStrip do
  @moduledoc """
  Suggested next steps (`Qlarius.Nudges`) as small cards in one row that
  scrolls sideways. Renders nothing when there are none. Styles are the
  `.nudge-strip` and `.nudge-card` rules in app.css.
  """
  use Phoenix.Component
  import QlariusWeb.CoreComponents

  attr :id, :string, required: true
  attr :nudges, :list, required: true
  attr :title, :string, default: "Next steps"
  attr :on_tap, :string, default: "nudge_tap"
  attr :on_dismiss, :string, default: "nudge_dismiss"

  def nudge_strip(assigns) do
    ~H"""
    <section :if={@nudges != []} id={@id} class="nudge-strip" aria-labelledby={"#{@id}-title"}>
      <h2 id={"#{@id}-title"} class="nudge-strip__title">{@title}</h2>
      <ul class="nudge-strip__list">
        <li
          :for={nudge <- @nudges}
          id={"#{@id}-#{nudge.key}"}
          class={["nudge-card", "nudge-card--#{nudge.brand}"]}
        >
          <button
            type="button"
            class="nudge-card__open"
            phx-click={@on_tap}
            phx-value-key={nudge.key}
          >
            <.nudge_art nudge={nudge} />
            <span class="nudge-card__text">
              <span class="nudge-card__title">{nudge.title}</span>
              <span :if={nudge.meta} class="nudge-card__meta">{nudge.meta}</span>
            </span>
          </button>
          <span :if={nudge.progress} class="nudge-card__bar" aria-hidden="true">
            <span style={"width: #{progress_percent(nudge.progress)}%"}></span>
          </span>
          <button
            type="button"
            class="nudge-card__dismiss"
            phx-click={@on_dismiss}
            phx-value-key={nudge.key}
            aria-label={"Dismiss #{nudge.title}"}
          >
            <.icon name="hero-x-mark-micro" class="size-3.5" />
          </button>
        </li>
      </ul>
    </section>
    """
  end

  attr :nudge, :map, required: true

  defp nudge_art(%{nudge: %{graphic: graphic}} = assigns) when is_binary(graphic) do
    ~H"""
    <span class={["nudge-card__art", @nudge.graphic_dark && "nudge-card__art--paired"]} aria-hidden="true">
      <img src={@nudge.graphic} alt="" class="nudge-card__art-light" />
      <img :if={@nudge.graphic_dark} src={@nudge.graphic_dark} alt="" class="nudge-card__art-dark" />
    </span>
    """
  end

  defp nudge_art(assigns) do
    ~H"""
    <span class="nudge-card__chip" aria-hidden="true">
      <.icon name={@nudge.icon} class="size-5" />
    </span>
    """
  end

  defp progress_percent({current, goal}) when goal > 0,
    do: min(round(current / goal * 100), 100)

  defp progress_percent(_progress), do: 0
end
