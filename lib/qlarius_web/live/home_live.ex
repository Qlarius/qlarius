defmodule QlariusWeb.HomeLive do
  use QlariusWeb, :live_view

  import QlariusWeb.Money
  import QlariusWeb.PWAHelpers

  on_mount {QlariusWeb.DetectMobile, :detect_mobile}

  alias QlariusWeb.Layouts
  alias QlariusWeb.Components.StrongStartComponent
  alias Qlarius.Tiqit.Arcade.Arcade
  alias Qlarius.YouData.StrongStart

  def mount(_params, session, socket) do
    scope = socket.assigns.current_scope
    me_file = scope.user.me_file

    socket =
      socket
      |> assign(:current_path, "/home")
      |> assign(:title, "Home")
      |> init_pwa_assigns(session)
      |> assign_strong_start(me_file)
      |> assign_tiqit_counts(scope)

    {:ok, socket}
  end

  def handle_event("pwa_detected", params, socket) do
    handle_pwa_detection(socket, params)
  end

  def handle_event("referral_code_from_storage", _params, socket) do
    {:noreply, socket}
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

  defp assign_tiqit_counts(socket, scope) do
    socket
    |> assign(:active_tiqits_count, Arcade.count_active_tiqits(scope))
    |> assign(:expired_tiqits_count, Arcade.count_expired_tiqits(scope))
    |> assign(:total_tiqit_purchases, Arcade.count_total_purchases(scope))
  end

  defp assign_strong_start(socket, me_file) do
    if StrongStart.should_show?(me_file) do
      trait_count = socket.assigns.current_scope.trait_count
      progress = StrongStart.get_progress(me_file, trait_count)

      if progress.completed_count == progress.total_count do
        StrongStart.mark_all_complete(me_file)
        assign(socket, :show_strong_start, false)
      else
        starter_survey_id =
          Qlarius.System.get_global_variable_int("STRONG_START_SURVEY_ID", nil)

        socket
        |> assign(:show_strong_start, true)
        |> assign(:strong_start_progress, progress)
        |> assign(:starter_survey_id, starter_survey_id)
      end
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
          <StrongStartComponent.strong_start
            progress={@strong_start_progress}
            starter_survey_id={@starter_survey_id}
          />
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

            <div class="grid grid-cols-3 gap-4 mb-4">
              <div
                class="bg-tiqit-200 dark:bg-tiqit-900 text-base-content/80 rounded-lg border border-tiqit-300 dark:border-tiqit-600 p-3 flex flex-col items-center justify-center cursor-pointer transition-all duration-200 hover:bg-tiqit-300 dark:hover:bg-tiqit-800 hover:border-tiqit-400 dark:hover:border-tiqit-400"
                phx-click={JS.navigate("/tiqits?status=active")}
              >
                <div class="text-3xl font-bold leading-none">{@active_tiqits_count}</div>
                <div class="text-md font-medium text-base-content/60">active</div>
              </div>

              <div
                class="bg-tiqit-200 dark:bg-tiqit-900 text-base-content/80 rounded-lg border border-tiqit-300 dark:border-tiqit-600 p-3 flex flex-col items-center justify-center cursor-pointer transition-all duration-200 hover:bg-tiqit-300 dark:hover:bg-tiqit-800 hover:border-tiqit-400 dark:hover:border-tiqit-400"
                phx-click={JS.navigate("/tiqits?status=expired")}
              >
                <div class="text-3xl font-bold leading-none">{@expired_tiqits_count}</div>
                <div class="text-md font-medium text-base-content/60">expiring</div>
              </div>

              <div
                class="bg-tiqit-200 dark:bg-tiqit-900 text-base-content/80 rounded-lg border border-tiqit-300 dark:border-tiqit-600 p-3 flex flex-col items-center justify-center cursor-pointer transition-all duration-200 hover:bg-tiqit-300 dark:hover:bg-tiqit-800 hover:border-tiqit-400 dark:hover:border-tiqit-400"
                phx-click={JS.navigate("/tiqits")}
              >
                <div class="text-3xl font-bold leading-none">{@total_tiqit_purchases}</div>
                <div class="text-md font-medium text-base-content/60">total</div>
              </div>
            </div>
          </div>
        </div>
      </Layouts.mobile>
    </div>
    """
  end
end
