defmodule QlariusWeb.UserSettingsLive do
  use QlariusWeb, :live_view

  import QlariusWeb.PWAHelpers

  def render(assigns) do
    ~H"""
    <div id="settings-pwa-detect" phx-hook="HiPagePWADetect">
      <Layouts.mobile {assigns}
        title="Settings"
        slide_over_active={@selected_setting != nil}
        slide_over_title={get_setting_title(@selected_setting)}
      >
        <:slide_over_content>
          <%= render_setting_content(assigns) %>
        </:slide_over_content>

        <%!-- Main content: Settings list --%>
        <div class="mx-auto max-w-2xl">

          <div class="mb-6">
            <h2 class="text-xl font-semibold text-base-content/70 mb-3">General</h2>
            <ul class="-mx-4 sm:mx-0 list bg-base-200 dark:!bg-base-200 sm:rounded-box shadow-md overflow-hidden">
              <li
                class="list-row cursor-pointer transition-all duration-200 !rounded-none hover:bg-base-300 dark:hover:!bg-base-100"
                phx-click="open_setting"
                phx-value-setting="notifications"
              >
                <div class="flex items-center mr-3">
                  <.icon name="hero-bell" class="h-6 w-6 text-base-content/70" />
                </div>
                <div class="list-col-grow">
                  <div class="text-xl font-medium text-base-content">Notifications</div>
                  <div class="text-base text-base-content/60">Manage notification preferences</div>
                </div>
                <div class="flex items-center">
                  <.icon name="hero-chevron-right" class="h-5 w-5 text-base-content/40" />
                </div>
              </li>

              <li
                class="list-row cursor-pointer transition-all duration-200 !rounded-none hover:bg-base-300 dark:hover:!bg-base-100"
                phx-click="open_setting"
                phx-value-setting="time_zone"
              >
                <div class="flex items-center mr-3">
                  <.icon name="hero-globe-alt" class="h-6 w-6 text-base-content/70" />
                </div>
                <div class="list-col-grow">
                  <div class="text-xl font-medium text-base-content">Time Zone</div>
                  <div class="text-base text-base-content/60">Set your time zone</div>
                </div>
                <div class="flex items-center">
                  <.icon name="hero-chevron-right" class="h-5 w-5 text-base-content/40" />
                </div>
              </li>
            </ul>
          </div>

          <%= if @current_scope.true_user.role == "admin" do %>
            <div>
              <h2 class="text-xl font-semibold text-base-content/70 mb-3">Admin</h2>
              <ul class="-mx-4 sm:mx-0 list bg-base-200 dark:!bg-base-200 sm:rounded-box shadow-md overflow-hidden">
                <li
                  class="list-row cursor-pointer transition-all duration-200 !rounded-none hover:bg-base-300 dark:hover:!bg-base-100"
                  phx-click="open_setting"
                  phx-value-setting="proxy_users"
                >
                  <div class="flex items-center mr-3">
                    <.icon name="hero-user-group" class="h-6 w-6 text-base-content/70" />
                  </div>
                  <div class="list-col-grow">
                    <div class="text-xl font-medium text-base-content">Manage Proxy Users</div>
                    <div class="text-base text-base-content/60">Add and switch between users</div>
                  </div>
                  <div class="flex items-center">
                    <.icon name="hero-chevron-right" class="h-5 w-5 text-base-content/40" />
                  </div>
                </li>
              </ul>
            </div>
          <% end %>
        </div>
      </Layouts.mobile>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:title, "Settings")
     |> assign(:current_path, "/settings")
     |> assign(:selected_setting, nil)
     |> assign(:is_pwa, false)
     |> assign(:device_type, :desktop)}
  end

  def handle_event("pwa_detected", params, socket) do
    handle_pwa_detection(socket, params)
  end

  def handle_event("open_setting", %{"setting" => "proxy_users"}, socket) do
    # Navigate to separate LiveView for proxy users (complex functionality)
    {:noreply, push_navigate(socket, to: ~p"/proxy_users")}
  end

  def handle_event("open_setting", %{"setting" => setting}, socket) do
    {:noreply, assign(socket, :selected_setting, setting)}
  end

  def handle_event("close_slide_over", _params, socket) do
    {:noreply, assign(socket, :selected_setting, nil)}
  end

  defp get_setting_title("notifications"), do: "Notifications"
  defp get_setting_title("time_zone"), do: "Time Zone"
  defp get_setting_title("proxy_users"), do: "Manage Proxy Users"
  defp get_setting_title(_), do: "Settings"

  defp render_setting_content(%{selected_setting: "notifications"} = assigns) do
    ~H"""
    <div class="flex items-center justify-center min-h-[50vh]">
      <div class="text-center">
        <p class="text-xl text-base-content/70 mb-2">Coming soon</p>
        <p class="text-base-content/50">Notification settings will be available here.</p>
      </div>
    </div>
    """
  end

  defp render_setting_content(%{selected_setting: "time_zone"} = assigns) do
    ~H"""
    <div class="flex items-center justify-center min-h-[50vh]">
      <div class="text-center">
        <p class="text-xl text-base-content/70 mb-2">Coming soon</p>
        <p class="text-base-content/50">Time zone settings will be available here.</p>
      </div>
    </div>
    """
  end

  defp render_setting_content(_assigns), do: nil
end
