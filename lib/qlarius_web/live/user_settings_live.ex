defmodule QlariusWeb.UserSettingsLive do
  use QlariusWeb, :live_view

  import QlariusWeb.PWAHelpers
  alias Qlarius.Notifications
  alias Qlarius.Accounts
  alias Qlarius.Timezones

  on_mount {QlariusWeb.DetectMobile, :detect_mobile}

  def render(assigns) do
    ~H"""
    <div id="settings-pwa-detect" phx-hook="HiPagePWADetect">
      <Layouts.mobile
        {assigns}
        title="Settings"
        slide_over_active={@selected_setting != nil}
        slide_over_title={get_setting_title(@selected_setting)}
      >
        <:slide_over_content>
          {render_setting_content(assigns)}
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
                    <div class="text-xl font-medium text-base-content">Proxy Users</div>
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

  def mount(_params, session, socket) do
    user_id = socket.assigns.current_scope.user.id
    Notifications.ensure_default_preferences(user_id)

    {:ok,
     socket
     |> assign(:title, "Settings")
     |> assign(:current_path, "/settings")
     |> assign(:selected_setting, nil)
     |> init_pwa_assigns(session)
     |> assign(:notification_preference, nil)
     |> assign(:current_device_subscribed, false)
     |> assign(:device_subscription_supported, true)
     |> assign(:total_devices_subscribed, 0)}
  end

  def handle_event("pwa_detected", params, socket) do
    handle_pwa_detection(socket, params)
  end

  def handle_event("open_setting", %{"setting" => "proxy_users"}, socket) do
    # Navigate to separate LiveView for proxy users (complex functionality)
    {:noreply, push_navigate(socket, to: ~p"/proxy_users")}
  end

  def handle_event("open_setting", %{"setting" => "notifications"}, socket) do
    user_id = socket.assigns.current_scope.user.id
    preference = Notifications.get_preference(user_id, "web_push", "ad_count")
    subscriptions = Notifications.get_active_subscriptions(user_id)

    {:noreply,
     socket
     |> assign(:selected_setting, "notifications")
     |> assign(:notification_preference, preference)
     |> assign(:total_devices_subscribed, length(subscriptions))}
  end

  def handle_event("open_setting", %{"setting" => "time_zone"}, socket) do
    timezone = socket.assigns.current_scope.user.timezone || Timezones.default()
    current_time = Qlarius.DateTime.current_time_in_timezone(timezone)

    {:noreply,
     socket
     |> assign(:selected_setting, "time_zone")
     |> assign(:current_timezone, timezone)
     |> assign(:current_time, current_time)}
  end

  def handle_event("open_setting", %{"setting" => setting}, socket) do
    {:noreply, assign(socket, :selected_setting, setting)}
  end

  def handle_event("close_slide_over", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected_setting, nil)
     |> assign(:notification_preference, nil)}
  end

  def handle_event("toggle_enabled", _params, socket) do
    currently_subscribed = socket.assigns.current_device_subscribed

    if !currently_subscribed do
      # Toggling ON - request subscription
      {:noreply, push_event(socket, "request-push-permission", %{})}
    else
      # Toggling OFF - request unsubscription
      {:noreply, push_event(socket, "request-push-unsubscribe", %{})}
    end
  end

  def handle_event("device_subscribed", _params, socket) do
    user_id = socket.assigns.current_scope.user.id
    subscriptions = Notifications.get_active_subscriptions(user_id)

    {:noreply,
     socket
     |> assign(:current_device_subscribed, true)
     |> assign(:total_devices_subscribed, length(subscriptions))
     |> put_flash(:info, "This device is subscribed to push notifications")}
  end

  def handle_event("device_not_subscribed", %{"supported" => false}, socket) do
    user_id = socket.assigns.current_scope.user.id
    subscriptions = Notifications.get_active_subscriptions(user_id)

    {:noreply,
     socket
     |> assign(:current_device_subscribed, false)
     |> assign(:device_subscription_supported, false)
     |> assign(:total_devices_subscribed, length(subscriptions))}
  end

  def handle_event("device_not_subscribed", _params, socket) do
    user_id = socket.assigns.current_scope.user.id
    subscriptions = Notifications.get_active_subscriptions(user_id)

    {:noreply,
     socket
     |> assign(:current_device_subscribed, false)
     |> assign(:total_devices_subscribed, length(subscriptions))}
  end

  def handle_event("permission_granted", _params, socket) do
    # Don't mark as subscribed yet - wait for actual device_subscribed event
    # after the subscription is successfully saved to server
    {:noreply, socket}
  end

  def handle_event("permission_denied", _params, socket) do
    {:noreply,
     socket
     |> assign(:current_device_subscribed, false)
     |> put_flash(
       :error,
       "❌ Push notifications were denied. Please enable them in your browser settings."
     )}
  end

  def handle_event("device_unsubscribed", %{"endpoint" => endpoint}, socket) do
    require Logger
    Logger.info("🔔 device_unsubscribed event received with endpoint: #{String.slice(endpoint, 0..50)}...")
    user_id = socket.assigns.current_scope.user.id

    case Notifications.unsubscribe_by_endpoint(user_id, endpoint) do
      {:ok, _} ->
        subscriptions = Notifications.get_active_subscriptions(user_id)
        Logger.info("✅ Successfully unsubscribed. Active subscriptions: #{length(subscriptions)}")

        {:noreply,
         socket
         |> assign(:current_device_subscribed, false)
         |> assign(:total_devices_subscribed, length(subscriptions))
         |> put_flash(:info, "This device has been unsubscribed from push notifications")}

      {:error, reason} ->
        Logger.error("❌ Failed to unsubscribe: #{inspect(reason)}")
        {:noreply, put_flash(socket, :error, "Failed to unsubscribe device")}
    end
  end

  def handle_event("unsubscribe_failed", %{"error" => error}, socket) do
    {:noreply, put_flash(socket, :error, "❌ Failed to unsubscribe: #{error}")}
  end

  def handle_event("subscription_failed", %{"error" => error}, socket) do
    {:noreply,
     socket
     |> assign(:current_device_subscribed, false)
     |> put_flash(:error, "❌ Failed to subscribe: #{error}")}
  end

  def handle_event("toggle_hour", %{"hour" => hour_str}, socket) do
    hour = String.to_integer(hour_str)
    user_id = socket.assigns.current_scope.user.id
    current_hours = socket.assigns.notification_preference.preferred_hours

    new_hours =
      if hour in current_hours do
        List.delete(current_hours, hour)
      else
        [hour | current_hours] |> Enum.sort()
      end

    {:ok, updated_pref} =
      Notifications.update_preference(
        user_id,
        "web_push",
        "ad_count",
        %{preferred_hours: new_hours}
      )

    {:noreply, assign(socket, :notification_preference, updated_pref)}
  end

  def handle_event("preset", %{"preset" => preset}, socket) do
    user_id = socket.assigns.current_scope.user.id

    new_hours =
      case preset do
        "morning" -> [6, 7, 8, 9, 10]
        "evening" -> [20, 21, 22, 23]
        "worker" -> [9, 12, 18]
        "clear" -> []
      end

    {:ok, updated_pref} =
      Notifications.update_preference(
        user_id,
        "web_push",
        "ad_count",
        %{preferred_hours: new_hours}
      )

    {:noreply, assign(socket, :notification_preference, updated_pref)}
  end

  def handle_event("update_quiet_start", %{"hour" => hour_str}, socket) do
    hour = String.to_integer(hour_str)
    user_id = socket.assigns.current_scope.user.id

    {:ok, updated_pref} =
      Notifications.update_preference(
        user_id,
        "web_push",
        "ad_count",
        %{quiet_hours_start: Time.new!(hour, 0, 0)}
      )

    {:noreply, assign(socket, :notification_preference, updated_pref)}
  end

  def handle_event("update_quiet_end", %{"hour" => hour_str}, socket) do
    hour = String.to_integer(hour_str)
    user_id = socket.assigns.current_scope.user.id

    {:ok, updated_pref} =
      Notifications.update_preference(
        user_id,
        "web_push",
        "ad_count",
        %{quiet_hours_end: Time.new!(hour, 0, 0)}
      )

    {:noreply, assign(socket, :notification_preference, updated_pref)}
  end

  def handle_event("update_timezone", %{"timezone" => timezone}, socket) do
    require Logger
    Logger.info("🕐 Timezone update requested: #{timezone}")

    user = socket.assigns.current_scope.user

    case Accounts.update_user(user, %{timezone: timezone}) do
      {:ok, updated_user} ->
        current_time = Qlarius.DateTime.current_time_in_timezone(timezone)
        Logger.info("✅ Timezone updated to #{timezone}, current time: #{current_time}")

        {:noreply,
         socket
         |> put_flash(:info, "Time zone updated successfully")
         |> assign(:current_scope, %{socket.assigns.current_scope | user: updated_user})
         |> assign(:current_timezone, timezone)
         |> assign(:current_time, current_time)}

      {:error, changeset} ->
        Logger.error("❌ Failed to update timezone: #{inspect(changeset)}")
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update time zone")}
    end
  end

  def handle_event("timezone_detected", %{"timezone" => detected_tz}, socket) do
    user = socket.assigns.current_scope.user

    # Only auto-set if user doesn't have a timezone set yet
    if is_nil(user.timezone) || user.timezone == Timezones.default() do
      mapped_tz = Timezones.detect_from_browser(detected_tz)
      Accounts.update_user(user, %{timezone: mapped_tz})

      {:noreply,
       socket
       |> assign(:current_scope, %{
         socket.assigns.current_scope
         | user: %{user | timezone: mapped_tz}
       })}
    else
      {:noreply, socket}
    end
  end

  defp get_setting_title("notifications"), do: "Notifications"
  defp get_setting_title("time_zone"), do: "Time Zone"
  defp get_setting_title("proxy_users"), do: "Manage Proxy Users"
  defp get_setting_title(_), do: "Settings"

  defp render_setting_content(
         %{selected_setting: "notifications", notification_preference: pref} = assigns
       )
       when not is_nil(pref) do
    ~H"""
    <div class="pb-8 space-y-4" id="push-notifications-container" phx-hook="PushNotifications">
      <%!-- Card 1: Enable/Disable Toggle --%>
      <div class="card bg-base-200 shadow-md">
        <div class="card-body">
          <h2 class="card-title text-xl mb-4">
            <.icon name="hero-megaphone" class="w-5 h-5" /> Push Notifications
          </h2>

          <div class="form-control">
            <div class="flex items-start justify-start gap-5 my-3">
              <span class="text-lg font-semibold text-base-content/70">OFF</span>
              <input
                id="push-notification-toggle"
                type="checkbox"
                class="toggle toggle-xl toggle-success checked:bg-success checked:border-success"
                checked={@current_device_subscribed}
                phx-click="toggle_enabled"
                disabled={!@device_subscription_supported}
              />
              <span class="text-lg font-semibold text-base-content/70">ON</span>
            </div>

            <%!-- Device Status Messages --%>
            <div class="mt-5 space-y-1">
              <p :if={!@device_subscription_supported} class="text-sm text-error">
                Push notifications not supported on this browser/device
              </p>

              <p
                :if={@device_subscription_supported and @current_device_subscribed}
                class="text-sm text-success"
              >
                This device is subscribed to notifications. Adjust your preferences below to customize your notifications.
              </p>

              <p
                :if={@device_subscription_supported and !@current_device_subscribed}
                class="text-sm text-warning"
              >
                Turn on notifications to receive alerts and optimize your experience (and revenue).
              </p>

              <%!-- <p :if={@device_subscription_supported} class="text-sm text-base-content/60">
                📱 Total devices with notifications: {@total_devices_subscribed}
              </p> --%>
            </div>
          </div>
        </div>
      </div>

      <%= if @notification_preference.enabled do %>
        <%!-- Card 2: Ad Offer Notification Times --%>
        <div class="card bg-base-200 shadow-md">
          <div class="card-body">
            <h2 class="card-title text-xl mb-4">
              <.icon name="hero-clock" class="w-5 h-5" /> Ad Offer Notification Times
            </h2>
            <p class="text-sm text-base-content/60 mb-4">
              Select the hours you'd like to be notified about available ads. Think about when your attention is available and alerts won't be annoying.
            </p>

            <div class="grid grid-cols-2 gap-4">
              <%!-- AM Column --%>
              <div>
                <h4 class="font-medium text-center mb-2 text-base-content/70">AM</h4>
                <div class="space-y-1">
                  <%= for hour <- 0..11 do %>
                    <label class="flex items-center p-3 hover:bg-base-300 rounded cursor-pointer">
                      <input
                        type="checkbox"
                        class="checkbox checkbox-primary w-7 h-7 mr-4"
                        checked={hour in @notification_preference.preferred_hours}
                        phx-click="toggle_hour"
                        phx-value-hour={hour}
                      />
                      <span class="text-lg">{format_hour(hour)}</span>
                    </label>
                  <% end %>
                </div>
              </div>

              <%!-- PM Column --%>
              <div>
                <h4 class="font-medium text-center mb-2 text-base-content/70">PM</h4>
                <div class="space-y-1">
                  <%= for hour <- 12..23 do %>
                    <label class="flex items-center p-3 hover:bg-base-300 rounded cursor-pointer">
                      <input
                        type="checkbox"
                        class="checkbox checkbox-primary w-7 h-7 mr-4"
                        checked={hour in @notification_preference.preferred_hours}
                        phx-click="toggle_hour"
                        phx-value-hour={hour}
                      />
                      <span class="text-lg">{format_hour(hour)}</span>
                    </label>
                  <% end %>
                </div>
              </div>
            </div>

            <%!-- Quick Presets --%>
            <div class="mt-4 flex flex-wrap gap-2">
              <p class="w-full text-sm font-medium text-base-content/70 mb-1">Quick presets:</p>
              <button class="btn btn-sm btn-outline" phx-click="preset" phx-value-preset="morning">
                Morning Person
              </button>
              <button class="btn btn-sm btn-outline" phx-click="preset" phx-value-preset="evening">
                Night Owl
              </button>
              <button class="btn btn-sm btn-outline" phx-click="preset" phx-value-preset="worker">
                9-to-5 Worker
              </button>
              <button class="btn btn-sm btn-outline" phx-click="preset" phx-value-preset="clear">
                Clear All
              </button>
            </div>
          </div>
        </div>

        <%!-- Card 3: Quiet Hours --%>
        <div class="card bg-base-200 shadow-md">
          <div class="card-body">
            <h2 class="card-title text-xl mb-4">
              <.icon name="hero-moon" class="w-5 h-5" /> Quiet Hours
            </h2>
            <p class="text-sm text-base-content/60 mb-4">
              Block all notifications during these hours
            </p>

            <div class="grid grid-cols-2 gap-4">
              <form phx-change="update_quiet_start">
                <div class="form-control">
                  <label class="label">
                    <span class="label-text">From</span>
                  </label>
                  <select name="hour" class="select select-bordered w-full">
                    <%= for hour <- 0..23 do %>
                      <option
                        value={hour}
                        selected={hour == time_to_hour(@notification_preference.quiet_hours_start)}
                      >
                        {format_hour(hour)}
                      </option>
                    <% end %>
                  </select>
                </div>
              </form>

              <form phx-change="update_quiet_end">
                <div class="form-control">
                  <label class="label">
                    <span class="label-text">Until</span>
                  </label>
                  <select name="hour" class="select select-bordered w-full">
                    <%= for hour <- 0..23 do %>
                      <option
                        value={hour}
                        selected={hour == time_to_hour(@notification_preference.quiet_hours_end)}
                      >
                        {format_hour(hour)}
                      </option>
                    <% end %>
                  </select>
                </div>
              </form>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_setting_content(%{selected_setting: "time_zone"} = assigns) do
    timezones = Timezones.list()

    # Use assigns if already set, otherwise calculate from user
    current_timezone = Map.get(assigns, :current_timezone) || assigns.current_scope.user.timezone || Timezones.default()
    current_time = Map.get(assigns, :current_time) || Qlarius.DateTime.current_time_in_timezone(current_timezone)

    assigns = assign(assigns, :timezones, timezones)
    assigns = assign(assigns, :current_timezone, current_timezone)
    assigns = assign(assigns, :current_time, current_time)

    ~H"""
    <div class="pb-8" id="timezone-settings" phx-hook="TimezoneDetector">
      <div class="card bg-base-200 shadow-md">
        <div class="card-body">
          <h2 class="card-title text-xl mb-4">
            <.icon name="hero-globe-alt" class="w-5 h-5" /> Time Zone
          </h2>

          <p class="text-sm text-base-content/60 mb-4">
            Your time zone affects when you receive notifications and how dates are displayed throughout the app.
            All notification hours are in your local time.
          </p>

          <form phx-change="update_timezone">
            <div class="form-control">
              <label class="label">
                <span class="label-text text-lg">Select your time zone</span>
              </label>
              <select
                name="timezone"
                class="select select-bordered w-full text-lg"
              >
                <%= for {label, iana} <- @timezones do %>
                  <option value={iana} selected={iana == @current_timezone}>
                    {label}
                  </option>
                <% end %>
              </select>
            </div>
          </form>

          <div class="mt-4 p-4 bg-base-300 rounded-lg">
            <p class="text-sm text-base-content/70 mb-1">Current time in your timezone:</p>
            <p class="text-2xl font-semibold text-primary">{@current_time}</p>
          </div>

          <div class="alert alert-info mt-4">
            <.icon name="hero-information-circle" class="w-5 h-5" />
            <span class="text-sm">
              Changing your timezone will update when notifications are sent and how all dates are displayed.
            </span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_setting_content(_assigns), do: nil

  defp format_hour(hour) do
    case hour do
      0 -> "12:00 AM"
      h when h < 12 -> "#{h}:00 AM"
      12 -> "12:00 PM"
      h -> "#{h - 12}:00 PM"
    end
  end

  defp time_to_hour(nil), do: 0
  defp time_to_hour(time), do: time.hour
end
