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
  import QlariusWeb.Components.CustomComponentsMobile

  # import QlariusWeb.Money

  embed_templates "layouts/*"

  @sidebar_classes_on "translate-x-0"
  @sidebar_classes_off "-translate-x-full"
  @sidebar_bg_classes_off "opacity-0 pointer-events-none"

  # Set this at compile time based on the actual config
  @debug_enabled Application.compile_env(:qlarius, :debug_enabled, false)

  def toggle_sponster_sidebar(on) when on in [:on, :off] do
    if on == :on do
      JS.add_class(@sidebar_classes_on, to: "#sponster-sidebar")
      |> JS.remove_class(@sidebar_classes_off, to: "#sponster-sidebar")
      |> JS.remove_class(@sidebar_bg_classes_off, to: "#sponster-sidebar-bg")
    else
      JS.remove_class(@sidebar_classes_on, to: "#sponster-sidebar")
      |> JS.add_class(@sidebar_classes_off, to: "#sponster-sidebar")
      |> JS.add_class(@sidebar_bg_classes_off, to: "#sponster-sidebar-bg")
    end
  end

  def toggle_right_sidebar(:on) do
    %JS{}
    |> JS.add_class("translate-x-0", to: "#right-sidebar")
    |> JS.remove_class("translate-x-full", to: "#right-sidebar")
    |> JS.remove_class("opacity-0 pointer-events-none", to: "#right-sidebar-bg")
    |> JS.add_class("sidebar-scroll-lock", to: "body")
    |> JS.add_class("sidebar-scroll-lock", to: "html")
  end

  def toggle_right_sidebar(:off) do
    %JS{}
    |> JS.remove_class("translate-x-0", to: "#right-sidebar")
    |> JS.add_class("translate-x-full", to: "#right-sidebar")
    |> JS.add_class("opacity-0 pointer-events-none", to: "#right-sidebar-bg")
    |> JS.remove_class("sidebar-scroll-lock", to: "body")
    |> JS.remove_class("sidebar-scroll-lock", to: "html")
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
        <span class="mt-1 text-[10px]">{@text}</span>

        <span
          :if={@badge}
          class="absolute -top-1 left-3/4 flex h-5 min-w-5 px-1 items-center justify-center rounded-full bg-green-600 text-white text-[11px]"
        >
          {@badge}
        </span>
      </div>
    </.link>
    """
  end

  def app(assigns) do
    ~H"""
    <div class="min-h-screen mx-auto flex flex-col">
      <.flash_group flash={@flash} />
      <div class="flex-1">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  # attr :ads_count, :integer, required: true
  # attr :flash, :map, required: true
  # attr :current_scope, Scope, required: true
  # attr :wallet_balance, Decimal, required: true

  slot :inner_block, required: true

  attr :title, :string, required: true
  attr :flash, :map, required: true
  attr :current_scope, Scope, required: true
  attr :current_path, :string, default: nil

  def mobile(assigns) do
    ~H"""
    <.flash_group flash={@flash} />

    <div class="min-h-screen flex flex-col">
      <%= if (@is_mobile || (assigns[:conn] && Map.get(assigns.conn.assigns, :is_mobile))) do %>
        <div class="h-[env(safe-area-inset-top)] min-h-10 bg-base-50 flex-shrink-0"></div>
      <% end %>

      <div class="container mx-auto px-4 py-6 flex-1 flex flex-col">
        <div class="w-full mb-6 flex justify-between items-center flex-shrink-0">
          <div class="w-8">
            <button class="cursor-pointer" phx-click={toggle_sponster_sidebar(:on)}>
              <.icon name="hero-bars-3" class="h-8 w-8 text-content-base" />
            </button>
          </div>
          <div class="flex-1">
            <h1 class="text-3xl font-bold text-center flex-1">{@title}</h1>
          </div>
          <div class="min-w-8 overflow-x-visible">
            <.wallet_balance :if={assigns[:current_scope]} balance={@current_scope.wallet_balance} />
          </div>
        </div>
        <div class="flex-1 pb-15">
          {render_slot(@inner_block)}
        </div>
        <.debug_assigns {assigns} />
      </div>
    </div>

    <.mobile_sidebar {assigns} />
    <.right_sidebar_drawer {assigns} />

    <%!-- bottom dock with correct daisyUI structure and custom positioned indicators --%>
    <div class="dock z-40">
      <button class={[assigns[:current_path] == "/" && "dock-active"]} phx-click={JS.navigate(~p"/")}>
        <.icon name="hero-home" class="size-[1.5em]" />
        <span class="dock-label">Home</span>
      </button>

      <button
        class={[
          "indicator relative",
          assigns[:current_path] && String.starts_with?(assigns[:current_path], "/ads") &&
            "dock-active"
        ]}
        phx-click={JS.navigate(~p"/ads")}
      >
        <.icon name="hero-eye" class="size-[1.5em]" />
        <span class="dock-label">Ads</span>
        <span
          :if={@current_scope.ads_count > 0}
          class="absolute left-1/2 ml-[4px] top-0 badge badge-xs rounded-full px-1 py-2 text-white !bg-sponster-400"
        >
          {@current_scope.ads_count}
        </span>
      </button>

      <button
        class={[
          "indicator relative",
          assigns[:current_path] && String.starts_with?(assigns[:current_path], "/wallet") &&
            "dock-active"
        ]}
        phx-click={JS.navigate(~p"/wallet")}
      >
        <.icon name="hero-banknotes" class="size-[1.5em]" />
        <span class="dock-label">Wallet</span>
        <%!-- <span class="absolute left-1/2 ml-[4px] top-0 badge badge-xs rounded-full px-1 py-2 text-white !bg-sponster-400">
          {format_usd(@current_scope.wallet_balance)}
        </span> --%>
      </button>

      <%!-- TODO: Route not implemented - was ~p"/me_file" (route doesn't exist) --%>
      <button
        class={[
          assigns[:current_path] && String.starts_with?(assigns[:current_path], "/me_file") &&
            "dock-active"
        ]}
        phx-click={JS.navigate(~p"/me_file")}
      >
        <.icon name="hero-identification" class="size-[1.5em]" />
        <span class="dock-label">MeFile</span>
        <%!-- <span
          :if={@current_scope.ads_count > 0}
          class="absolute left-1/2 ml-[4px] top-0 badge badge-xs rounded-full px-1 py-2 text-white !bg-youdata-600"
        >
          {@current_scope.trait_count}
        </span> --%>
      </button>

      <button phx-click={toggle_sponster_sidebar(:on)}>
        <.icon name="hero-ellipsis-horizontal" class="size-[1.5em]" />
        <span class="dock-label">More</span>
      </button>
    </div>
    """
  end

  # attr :current_scope, Scope, required: true

  # def sponster_sidebar(assigns)

  # Call this plug in the layout to set the @current_path assign,
  # which must be present for the 'marketers' layout to work.
  def set_current_path(conn, _opts) do
    Plug.Conn.assign(conn, :current_path, conn.request_path)
  end

  def on_mount(:set_current_path, _params, _session, socket) do
    # Only set current_path if it's not already set
    socket =
      if Map.has_key?(socket.assigns, :current_path) do
        socket
      else
        assign(socket, :current_path, "/")
      end

    # Set up hook that preserves manually set paths
    socket =
      Phoenix.LiveView.attach_hook(socket, :set_current_path, :handle_params, fn _params,
                                                                                 uri,
                                                                                 socket ->
        # Only update current_path if it wasn't manually set in mount
        current_path =
          if socket.assigns[:current_path] in ["/", nil] do
            URI.parse(uri).path || "/"
          else
            socket.assigns.current_path
          end

        {:cont, assign(socket, :current_path, current_path)}
      end)

    {:cont, socket}
  end

  attr :flash, :map, required: true
  attr :current_scope, Scope, default: nil

  slot :inner_block

  def marketers(assigns) do
    ~H"""
    <div class="bg-white shadow-md">
      <div class="flex bg-green-500 text-white">
        <%!-- TODO: Route not implemented - was ~p"/trait_groups" (commented out in router lines 66-77) --%>
        <.marketer_navbar_link current_path={@current_path} path="#">
          <.icon name="hero-tag" class="mr-2" />
          <span>Traits</span>
        </.marketer_navbar_link>

        <%!-- TODO: Route not implemented - was ~p"/targets" (route commented out in router line 61) --%>
        <.marketer_navbar_link current_path={@current_path} path="#">
          <.icon name="hero-users" class="mr-2" />
          <span>Targets</span>
        </.marketer_navbar_link>

        <%!-- TODO: Route not implemented - was ~p"/campaigns" (route doesn't exist in router) --%>
        <.marketer_navbar_link current_path={@current_path} path="#">
          <.icon name="hero-speaker-wave" class="mr-2" />
          <span>Campaigns</span>
        </.marketer_navbar_link>

        <%!-- TODO: Route not implemented - was ~p"/media_sequences" (route commented out in router line 63) --%>
        <.marketer_navbar_link current_path={@current_path} path="#">
          <.icon name="hero-numbered-list" class="mr-2" />
          <span>Sequences</span>
        </.marketer_navbar_link>

        <%!-- Fixed route - media_pieces route is under /marketer namespace --%>
        <.marketer_navbar_link current_path={@current_path} path={~p"/marketer/media_pieces"}>
          <.icon name="hero-photo" class="mr-2" />
          <span>Media</span>
        </.marketer_navbar_link>
      </div>
    </div>

    <div class="container mx-auto px-4 py-8 flex-1">
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :current_path, :string, required: true
  attr :path, :string, required: true

  slot :inner_block

  defp marketer_navbar_link(assigns) do
    ~H"""
    <.link
      class={[
        "flex items-center px-4 py-2 border-r border-green-400",
        String.starts_with?(@current_path, @path) && "bg-green-600"
      ]}
      navigate={@path}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  attr :flash, :map, required: true
  attr :current_scope, Scope, default: nil
  attr :breadcrumbs, :list, default: []

  slot :inner_block, required: true

  def creators(assigns) do
    ~H"""
    <main class="p-4 sm:px-6 lg:px-8 mx-auto">
      <.breadcrumbs crumbs={@breadcrumbs} />

      <div class="py-20">
        <.flash_group flash={@flash} />
        {render_slot(@inner_block)}
      </div>
    </main>
    """
  end

  attr :text, :string, required: true
  attr :href, :string, required: true
  attr :method, :string, default: nil

  defp creators_navbar_link(assigns) do
    ~H"""
    <.link
      href={@href}
      class="text-[0.8125rem] leading-6 text-zinc-700 font-semibold hover:text-zinc-900"
      method={@method}
    >
      {@text}
    </.link>
    """
  end

  # def admin(assigns) do
  #   ~H"""
  #   <%= if Map.has_key?(assigns, :inner_content) do %>  # For controllers
  #     <%= @inner_content %>
  #   <% else %>  # For LiveViews
  #     <%= render_slot(@inner_block) %>
  #   <% end %>
  #   """
  # end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Hang in there while we get back on track")}
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light
   toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.

  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full cursor-pointer">
      <div class="absolute w-[33%] h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme-mode=light]_&]:left-[33%] [[data-theme-mode=dark]_&]:left-[66%] transition-[left]" />

      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "system"})}
        class="flex p-2 cursor-pointer"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "light"})}
        class="flex p-2 cursor-pointer"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "dark"})}
        class="flex p-2 cursor-pointer"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end

  def debug_assigns(assigns) do
    if @debug_enabled and System.get_env("DEBUG") == "true" do
      ~H"""
      <pre class="mt-8 p-4 bg-base-100 text-base-content rounded overflow-auto text-sm">
          <%= inspect(assigns, pretty: true) %>
        </pre>
      """
    else
      ~H""
    end
  end
end
