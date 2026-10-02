defmodule QlariusWeb.AudienceCard do
  use QlariusWeb, :html

  import QlariusWeb.Components.MarketerUI, only: [panel: 1, status_badge: 1]

  attr :creator, :map, required: true
  attr :content, :map, required: true
  attr :effective, :map, required: true
  attr :level, :atom, required: true
  attr :class, :any, default: "mt-4"

  def card(assigns) do
    ~H"""
    <.panel
      id="audience-card"
      title="Audience"
      description="Who sees this first, and who is allowed to access it."
      class={@class}
    >
      <:actions>
        <.link navigate={~p"/creators/#{@creator.id}/audiences"} class="btn btn-ghost btn-sm">
          <.icon name="hero-rectangle-stack" class="size-4" /> Library
        </.link>
      </:actions>

      <div class="@container">
        <div class="grid gap-4 @lg:grid-cols-2">
          <.setting_tile
            label="Relevance"
            icon="hero-sparkles"
            copy={boost_copy(@effective.boost)}
            tone={boost_tone(@effective.boost)}
            status={boost_status(@effective.boost)}
          >
            <.link
              navigate={attach_path(@creator, @level, @content, :boost)}
              class={["btn btn-sm", @effective.boost.state == :unset && "btn-primary"]}
            >
              {if @effective.boost.state == :unset, do: "Set audience", else: "Change"}
            </.link>
          </.setting_tile>

          <.setting_tile
            label="Restrictions"
            icon="hero-lock-closed"
            copy={gate_copy(@effective)}
            tone={gate_tone(@effective)}
            status={gate_status(@effective)}
          >
            <.link navigate={attach_path(@creator, @level, @content, :gate)} class="btn btn-sm">
              Set restriction
            </.link>
          </.setting_tile>
        </div>
      </div>
    </.panel>
    """
  end

  attr :label, :string, required: true
  attr :icon, :string, required: true
  attr :copy, :string, required: true
  attr :tone, :string, required: true
  attr :status, :string, required: true
  slot :inner_block, required: true

  defp setting_tile(assigns) do
    ~H"""
    <div class="flex flex-col gap-3 rounded-xl border border-base-300 bg-base-200/40 p-4">
      <div class="flex items-center justify-between gap-2">
        <span class="flex items-center gap-2 text-sm font-medium">
          <.icon name={@icon} class="size-4 text-base-content/50" /> {@label}
        </span>
        <.status_badge tone={@tone}>{@status}</.status_badge>
      </div>
      <p class="flex-1 text-sm text-base-content/70">{@copy}</p>
      <div>{render_slot(@inner_block)}</div>
    </div>
    """
  end

  defp boost_status(%{state: :unset}), do: "Not set"
  defp boost_status(%{state: :inheriting}), do: "Inherited"
  defp boost_status(%{state: :set_here}), do: "Set"

  defp boost_tone(%{state: :unset}), do: "neutral"
  defp boost_tone(%{state: :inheriting}), do: "info"
  defp boost_tone(%{state: :set_here}), do: "success"

  defp gate_status(%{gate: %{state: :set_here}}), do: "Restricted"
  defp gate_status(%{inherited_gates: [_ | _]}), do: "Inherited"
  defp gate_status(_), do: "Open"

  defp gate_tone(%{gate: %{state: :set_here}}), do: "warning"
  defp gate_tone(%{inherited_gates: [_ | _]}), do: "info"
  defp gate_tone(_), do: "neutral"

  defp boost_copy(%{state: :unset}), do: "No audience set. Shown to everyone in browse order."

  defp boost_copy(%{state: :inheriting, inherited: inherited}) do
    name = inherited && inherited.target && inherited.target.title
    "Inherited from #{inherited.level}#{if name, do: ": #{name}", else: ""}"
  end

  defp boost_copy(%{state: :set_here, attachment: a}) do
    "Set here: #{a.target && a.target.title}"
  end

  defp gate_copy(%{gate: %{state: :set_here, attachment: a}, inherited_gates: inherited}) do
    own = "Set here: #{a.target && a.target.title}"
    rest = Enum.map(inherited, fn g -> "#{g.level}: #{g.target.title}" end)
    Enum.join([own | rest], "; ")
  end

  defp gate_copy(%{gate: %{state: :unset}, inherited_gates: []}), do: "No restrictions."

  defp gate_copy(%{inherited_gates: inherited}) do
    inherited
    |> Enum.map(fn g -> "Inherited from #{g.level}: #{g.target.title}" end)
    |> Enum.join("; ")
    |> case do
      "" -> "No restrictions."
      other -> other
    end
  end

  defp attach_path(creator, level, content, _mode) do
    "/creators/#{creator.id}/audiences?attach=#{level}&attach_id=#{content.id}"
  end
end
