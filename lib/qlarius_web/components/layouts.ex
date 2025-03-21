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

  import QlariusWeb.Money

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

  def sponster_bottom_bar(assigns) do
    ~H"""
    <div class="fixed bottom-0 left-0 right-0 z-40 flex items-center justify-between bg-white border-t border-gray-200 h-16 px-2">
      <.sponster_bottom_bar_link text="Home" href={~p"/"} icon_name="hero-home" />
      <.sponster_bottom_bar_link text="Ads" href={~p"/ads"} icon_name="hero-eye" />
      <.sponster_bottom_bar_link
        text="Wallet"
        href={~p"/wallet"}
        icon_name="hero-banknotes"
        badge={format_usd(@wallet_balance)}
      />
      <.sponster_bottom_bar_link text="MeFile" href={~p"/"} icon_name="hero-identification" />
      <button
        id="more"
        class="flex-1 flex flex-col items-center justify-center text-gray-600 h-full cursor-pointer"
      >
        <.icon name="hero-bars-3" class="h-6 w-6" />
        <span class="text-xs font-semibold mt-1">More</span>
      </button>
    </div>
    """
  end

  attr :text, :string, required: true
  attr :href, :string, required: true
  attr :icon_name, :string, required: true
  attr :badge, :string, default: nil

  def sponster_bottom_bar_link(assigns) do
    ~H"""
    <.link navigate={@href} class="flex-1 text-gray-600 flex justify-around">
      <div class="flex flex-col items-center justify-center relative h-full w-fit">
        <.icon name={@icon_name} class="h-6 w-6" />
        <span class="text-xs font-semibold mt-1">{@text}</span>

        <span
          :if={@badge}
          class="absolute -top-1 left-3/4 flex h-5 min-w-5 px-1 items-center justify-center rounded-full bg-green-600 text-white text-xs"
        >
          {@badge}
        </span>
      </div>
    </.link>
    """
  end
end
