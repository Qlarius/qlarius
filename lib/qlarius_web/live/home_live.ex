defmodule QlariusWeb.HomeLive do
  use QlariusWeb, :live_view

  import QlariusWeb.Money
  import QlariusWeb.PWAHelpers

  alias QlariusWeb.Layouts
  alias QlariusWeb.Components.StrongStartComponent
  alias Qlarius.YouData.StrongStart

  def mount(_params, _session, socket) do
    me_file = socket.assigns.current_scope.user.me_file

    socket =
      socket
      |> assign(:current_path, "/home")
      |> assign(:title, "Home")
      |> assign(:is_pwa, false)
      |> assign(:device_type, :desktop)
      |> assign_strong_start(me_file)

    {:ok, socket}
  end

  def handle_event("pwa_detected", params, socket) do
    handle_pwa_detection(socket, params)
  end

  def handle_event("skip_strong_start", _params, socket) do
    me_file = socket.assigns.current_scope.user.me_file

    case StrongStart.skip_forever(me_file) do
      {:ok, _updated_me_file} ->
        {:noreply,
         socket
         |> put_flash(:info, "Strong Start checklist hidden")
         |> assign(:show_strong_start, false)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update preferences")}
    end
  end

  def handle_event("remind_later", _params, socket) do
    me_file = socket.assigns.current_scope.user.me_file

    case StrongStart.remind_later(me_file) do
      {:ok, _updated_me_file} ->
        {:noreply,
         socket
         |> put_flash(:info, "We'll remind you later")
         |> assign(:show_strong_start, false)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update preferences")}
    end
  end

  def handle_event("mark_notifications_done", _params, socket) do
    me_file = socket.assigns.current_scope.user.me_file

    case StrongStart.mark_step_complete(me_file, "notifications_configured") do
      {:ok, updated_me_file} ->
        {:noreply,
         socket
         |> put_flash(:info, "Notifications step marked complete")
         |> assign_strong_start(updated_me_file)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update progress")}
    end
  end

  def handle_event("mark_referral_done", _params, socket) do
    me_file = socket.assigns.current_scope.user.me_file

    case StrongStart.mark_step_complete(me_file, "referral_viewed") do
      {:ok, updated_me_file} ->
        {:noreply,
         socket
         |> put_flash(:info, "Referral step marked complete")
         |> assign_strong_start(updated_me_file)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update progress")}
    end
  end

  defp assign_strong_start(socket, me_file) do
    if StrongStart.should_show?(me_file) do
      trait_count = socket.assigns.current_scope.trait_count
      progress = StrongStart.get_progress(me_file, trait_count)
      starter_survey_id = Qlarius.System.get_global_variable_int("STRONG_START_SURVEY_ID", nil)

      socket
      |> assign(:show_strong_start, true)
      |> assign(:strong_start_progress, progress)
      |> assign(:starter_survey_id, starter_survey_id)
    else
      assign(socket, :show_strong_start, false)
    end
  end

  def render(assigns) do
    ~H"""
    <div id="home-pwa-detect" phx-hook="HiPagePWADetect">
      <Layouts.mobile {assigns}>
        <div class="flex flex-row flex-wrap justify-between items-center py-3 mb-6">
        <h2 class="text-xl font-bold">{@current_scope.user.alias}</h2>
        <p class="text-xl flex items-center gap-1">
          <.icon name="hero-map-pin-solid" class="h-5 w-5 text-gray-500" />
          {@current_scope.home_zip}
        </p>
      </div>

      <%!-- Strong Start Component --%>
      <%= if @show_strong_start do %>
        <StrongStartComponent.strong_start progress={@strong_start_progress} starter_survey_id={@starter_survey_id} />
      <% end %>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div class="bg-base-200 rounded-lg p-4">
          <div class="flex justify-between items-center mb-4">
            <h2 class="text-2xl font-bold tracking-tight text-base-content/50">
              Sell your attention.
            </h2>
            <img src="/images/Sponster_logo_color_horiz.svg" alt="Sponster" class="h-7 w-auto" />
          </div>

          <div class="grid grid-cols-2 gap-4 mb-4">
            <div
              class="bg-sponster-200 dark:bg-sponster-800 text-base-content/80 rounded-lg border border-sponster-300 dark:border-sponster-500 p-3 flex flex-col items-center justify-center cursor-pointer transition-all duration-200 hover:bg-sponster-300 dark:hover:bg-sponster-700 hover:border-sponster-400 dark:hover:border-sponster-400"
              phx-click={JS.navigate("/ads")}
            >
              <div class="text-3xl font-bold leading-none">{@current_scope.ads_count}</div>
              <div class="text-md font-medium text-base-content/60">ads</div>
            </div>

            <div
              class="bg-sponster-200 dark:bg-sponster-800 text-base-content/80 rounded-lg border border-sponster-300 dark:border-sponster-500 p-3 flex flex-col items-center justify-center cursor-pointer transition-all duration-200 hover:bg-sponster-300 dark:hover:bg-sponster-700 hover:border-sponster-400 dark:hover:border-sponster-400"
              phx-click={JS.navigate("/ads")}
            >
              <div class="text-3xl font-bold leading-none">
                {format_usd(@current_scope.offered_amount)}
              </div>
              <div class="text-md font-medium text-base-content/60">offered</div>
            </div>
          </div>

          <div
            class="bg-sponster-200 dark:bg-sponster-800 text-base-content/80 rounded-lg border border-sponster-300 dark:border-sponster-500 p-3 flex flex-col items-center justify-center cursor-pointer transition-all duration-200 hover:bg-sponster-300 dark:hover:bg-sponster-700 hover:border-sponster-400 dark:hover:border-sponster-400"
            phx-click={JS.navigate("/wallet")}
          >
            <div class="text-3xl font-bold leading-none">
              {format_usd(@current_scope.wallet_balance)}
            </div>
            <div class="text-md font-medium text-base-content/60">wallet balance</div>
          </div>
        </div>

        <div class="bg-base-200 rounded-lg p-4">
          <div class="flex justify-between items-center mb-4">
            <h2 class="text-2xl font-bold tracking-tight text-base-content/50">Own your data.</h2>
            <img src="/images/YouData_logo_color_horiz.svg" alt="YouData" class="h-7 w-auto" />
          </div>

          <.link navigate={~p"/me_file"}>
            <div class="bg-youdata-200 dark:bg-youdata-900 text-base-content/80 rounded-lg border border-youdata-300 dark:border-youdata-500 p-3 flex flex-col items-center justify-center cursor-pointer transition-all duration-200 hover:bg-youdata-300 dark:hover:bg-youdata-800 hover:border-youdata-400 dark:hover:border-youdata-400">
              <div class="text-3xl font-bold leading-none">
                {@current_scope.trait_count}
              </div>
              <div class="text-md font-medium text-base-content/60">tags</div>
            </div>
          </.link>
        </div>

        <div class="bg-base-200 rounded-lg p-4">
          <div class="flex justify-between items-center mb-4">
            <h2 class="text-2xl font-bold tracking-tight text-base-content/50">Buy your media.</h2>
            <img src="/images/Tiqit_logo_color_horiz.svg" alt="Tiqit" class="h-7 w-auto" />
          </div>

          <div class="grid grid-cols-2 gap-4">
            <div class="bg-tiqit-200 dark:bg-tiqit-900 text-base-content/80 rounded-lg border border-tiqit-300 dark:border-tiqit-600 p-3 flex flex-col items-center justify-center">
              <div class="text-3xl font-bold leading-none">0</div>
              <div class="text-md font-medium text-base-content/60">active tiqits</div>
            </div>

            <div class="bg-tiqit-200 dark:bg-tiqit-900 text-base-content/80 rounded-lg border border-tiqit-300 dark:border-tiqit-600 p-3 flex flex-col items-center justify-center">
              <div class="text-3xl font-bold leading-none">0</div>
              <div class="text-md font-medium text-base-content/60">expiring tiqits</div>
            </div>
          </div>

          <div class="mt-3 text-center text-sm text-base-content/30">
            Coming soon. Build up your wallet to be ready.
          </div>
        </div>
      </div>
      </Layouts.mobile>
    </div>
    """
  end
end
