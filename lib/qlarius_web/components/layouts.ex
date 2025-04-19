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

  alias Qlarius.Accounts.Scope

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
      JS.add_class("translate-x-0", to: "#sponster-sidebar")
      |> JS.remove_class("-translate-x-full", to: "#sponster-sidebar")
      |> JS.remove_class("opacity-0", to: "#sponster-sidebar-bg")
      |> JS.remove_class("pointer-events-none", to: "#sponster-sidebar-bg")
    else
      JS.remove_class("translate-x-0", to: "#sponster-sidebar")
      |> JS.add_class("-translate-x-full", to: "#sponster-sidebar")
      |> JS.add_class("opacity-0", to: "#sponster-sidebar-bg")
      |> JS.add_class("pointer-events-none", to: "#sponster-sidebar-bg")
    end
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

  def app(assigns) do
    ~H"""
    <main class="px-4 py-20 sm:px-6 lg:px-8">
      <div class="mx-auto">
        <.flash_group flash={@flash} />
        {render_slot(@inner_block)}
      </div>
    </main>
    """
  end

  # attr :ads_count, :integer, required: true
  # attr :flash, :map, required: true
  # attr :current_scope, Scope, required: true
  # attr :wallet_balance, Decimal, required: true

  slot :inner_block, required: true

  def sponster(assigns) do
    ~H"""
    <.flash_group flash={@flash} />

    <div class="container mx-auto px-4 py-8">
      <div class="w-full mb-6">
        <button phx-click={toggle_sponster_sidebar(:on)}>
          <.icon name="hero-bars-3" class="h-8 w-8 text-gray-500" />
        </button>
      </div>
      {render_slot(@inner_block)}
    </div>

    <.sponster_sidebar {assigns} />

    <%!-- bottom bar --%>
    <div class="fixed bottom-0 left-0 right-0 z-40 flex items-center justify-between bg-white border-t border-gray-200 h-16 px-2">
      <.sponster_bottom_bar_link text="Home" href={~p"/"} icon_name="hero-home" />
      <.sponster_bottom_bar_link
        badge={@current_scope.ads_count}
        href={~p"/ads"}
        icon_name="hero-eye"
        text="Ads"
      />
      <.sponster_bottom_bar_link
        badge={format_usd(@current_scope.wallet_balance)}
        href={~p"/wallet"}
        icon_name="hero-banknotes"
        text="Wallet"
      />
      <.sponster_bottom_bar_link
        badge={@current_scope.trait_count}
        text="MeFile"
        href={~p"/me_file"}
        icon_name="hero-identification"
      />

      <button
        id="more"
        phx-click={toggle_sponster_sidebar(:on)}
        class="flex-1 flex flex-col items-center justify-center text-gray-600 h-full cursor-pointer"
      >
        <.icon name="hero-bars-3" class="h-6 w-6" />
        <span class="text-xs font-semibold mt-1">More</span>
      </button>
    </div>
    """
  end

  attr :current_scope, Scope, required: true

  def sponster_sidebar(assigns)

  attr :flash, :map, required: true
  attr :current_scope, Scope, required: true

  slot :inner_block, required: true

  def arcade(assigns) do
    ~H"""
    <main class="p-4 sm:px-6 lg:px-8 max-w-2xl mx-auto">
      <ul class="relative z-10 flex items-center gap-4 px-4 sm:px-6 lg:px-8 justify-end">
        <li class="text-[0.8125rem] leading-6 text-zinc-900">
          {@current_scope.user.email}
        </li>
        <%= for {text, href} <- [
          {"Admin", ~p"/admin/content"},
          {"Arcade", ~p"/arcade"}
        ] do %>
          <li>
            <.link
              href={href}
              class="text-[0.8125rem] leading-6 text-zinc-900 font-semibold hover:text-zinc-700"
            >
              {text}
            </.link>
          </li>
        <% end %>
        <li>
          <.link
            href={~p"/users/log_out"}
            class="text-[0.8125rem] leading-6 text-zinc-900 font-semibold hover:text-zinc-700"
            method="delete"
          >
            Log out
          </.link>
        </li>
      </ul>

      <div class="p-6 py-20">
        <.flash_group flash={@flash} />
        {render_slot(@inner_block)}
      </div>
    </main>
    """
  end
end
