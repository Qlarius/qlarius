defmodule QlariusWeb.Components.SurfaceComponents do
  @moduledoc """
  Page canvas and elevated section panels for consumer mobile screens.

  See `docs/ui-surfaces.md` for vocabulary, when to use each primitive, and examples.
  """
  use Phoenix.Component

  @doc """
  Elevated section panel: high-contrast card on the page canvas with a top accent border.

  Use for feature groupings (Home sections, Strong Start, MeFile category shells).
  Inner metric tiles and list rows are styled separately.
  """
  attr :class, :string, default: ""
  attr :padding, :boolean, default: true
  slot :inner_block, required: true

  def surface_panel(assigns) do
    ~H"""
    <div class={[
      "surface-panel",
      @padding && "surface-panel--padded",
      @class
    ]}>
      {render_slot(@inner_block)}
    </div>
    """
  end
end
