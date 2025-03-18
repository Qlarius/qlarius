defmodule QlariusWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use QlariusWeb, :controller` and
  `use QlariusWeb, :live_view`.
  """
  use QlariusWeb, :html

  embed_templates "layouts/*"

  attr :current_path, :string, required: true
  attr :path, :string, required: true

  slot :inner_block

  def marketer_navbar_link(assigns) do
    ~H"""
    <.link
      class={[
        "flex items-center px-4 py-2 border-r border-green-400",
        @current_path == @path && "bg-green-600"
      ]}
      navigate={@path}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  def toggle_sponster_sidebar(on) when on in [:on, :off] do
    if on == :on do
      JS.show(to: "#sponster-sidebar") |> JS.show(to: "#sponster-sidebar-bg")
    else
      JS.hide(to: "#sponster-sidebar") |> JS.hide(to: "#sponster-sidebar-bg")
    end
  end
end
