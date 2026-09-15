defmodule QlariusWeb.AudienceCard do
  use QlariusWeb, :html

  attr :creator, :map, required: true
  attr :content, :map, required: true
  attr :effective, :map, required: true
  attr :level, :atom, required: true

  def card(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-lg mt-4">
      <div class="card-body space-y-4">
        <div class="flex items-center justify-between">
          <h3 class="text-lg font-semibold">Audience</h3>
          <.link navigate={~p"/creators/#{@creator.id}/audiences"} class="link text-sm">
            Library
          </.link>
        </div>

        <div>
          <p class="text-sm font-medium text-base-content/60">Relevance</p>
          <p class="text-sm">{boost_copy(@effective.boost)}</p>
          <.link
            navigate={attach_path(@creator, @level, @content, :boost)}
            class="btn btn-xs btn-primary mt-2"
          >
            {if @effective.boost.state == :unset, do: "Set audience", else: "Change"}
          </.link>
        </div>

        <div>
          <p class="text-sm font-medium text-base-content/60">Restrictions</p>
          <p class="text-sm">{gate_copy(@effective)}</p>
          <.link
            navigate={attach_path(@creator, @level, @content, :gate)}
            class="btn btn-xs btn-outline mt-2"
          >
            Set restriction
          </.link>
        </div>
      </div>
    </div>
    """
  end

  defp boost_copy(%{state: :unset}), do: "No audience set. Shown to everyone in browse order."

  defp boost_copy(%{state: :inheriting, inherited: inherited}) do
    name = inherited && inherited.target && inherited.target.title
    "Inherited from #{inherited.level}#{if name, do: " — #{name}", else: ""}"
  end

  defp boost_copy(%{state: :set_here, attachment: a}) do
    "Set here — #{a.target && a.target.title}"
  end

  defp gate_copy(%{gate: %{state: :set_here, attachment: a}, inherited_gates: inherited}) do
    own = "Set here — #{a.target && a.target.title}"
    rest = Enum.map(inherited, fn g -> "#{g.level}: #{g.target.title}" end)
    Enum.join([own | rest], "; ")
  end

  defp gate_copy(%{gate: %{state: :unset}, inherited_gates: []}), do: "No restrictions."

  defp gate_copy(%{inherited_gates: inherited}) do
    inherited
    |> Enum.map(fn g -> "Inherited from #{g.level} — #{g.target.title}" end)
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
