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
    |> assign(:fleeting_tiqits_count, Arcade.count_fleeting_tiqits(scope))
    |> assign(:fleeted_tiqits_count, Arcade.count_fleeted_tiqits(scope))
    |> assign(:preserved_tiqits_count, Arcade.count_preserved_tiqits(scope))
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

        <div class="flex flex-col gap-4">
          <.surface_panel class="home-stat-card home-stat-card--youdata">
            <.home_stat_card_header
              title="Own your data."
              logo_src="/images/YouData_logo_color_horiz.svg"
              logo_alt="YouData"
            />

            <.link navigate={~p"/me_file"} class="home-stat home-stat--interactive">
              <span class="home-stat__value">{@current_scope.trait_count}</span>
              <span class="home-stat__label">tags</span>
            </.link>
          </.surface_panel>

          <.surface_panel class="home-stat-card home-stat-card--sponster">
            <.home_stat_card_header
              title="Sell your attention."
              logo_src="/images/Sponster_logo_color_horiz.svg"
              logo_alt="Sponster"
            />

            <div class="home-stat-grid--2">
              <div
                class="home-stat home-stat--interactive"
                phx-click={JS.navigate("/ads")}
                role="link"
                tabindex="0"
              >
                <span class="home-stat__value">{@current_scope.ads_count}</span>
                <span class="home-stat__label">ads</span>
              </div>

              <div
                class="home-stat home-stat--interactive"
                phx-click={JS.navigate("/ads")}
                role="link"
                tabindex="0"
              >
                <span class="home-stat__value">{format_usd(@current_scope.offered_amount)}</span>
                <span class="home-stat__label">offered</span>
              </div>
            </div>
          </.surface_panel>

          <.surface_panel class="home-stat-card home-stat-card--tiqit">
            <.home_stat_card_header
              title="Buy your media."
              logo_src="/images/Tiqit_logo_color_horiz.svg"
              logo_alt="Tiqit"
            />

            <div class="home-stat-grid--4">
              <div
                class="home-stat home-stat--interactive"
                phx-click={JS.navigate("/tiqits?status=active")}
                role="link"
                tabindex="0"
              >
                <span class="home-stat__value">{@active_tiqits_count}</span>
                <span class="home-stat__label">active</span>
              </div>

              <div
                class="home-stat home-stat--interactive"
                phx-click={JS.navigate("/tiqits?status=preserved")}
                role="link"
                tabindex="0"
              >
                <span class="home-stat__value">{@preserved_tiqits_count}</span>
                <span class="home-stat__label">marked</span>
              </div>

              <div
                class="home-stat home-stat--interactive"
                phx-click={JS.navigate("/tiqits?status=expired")}
                role="link"
                tabindex="0"
              >
                <span class="home-stat__value">{@fleeting_tiqits_count}</span>
                <span class="home-stat__label">fleeting</span>
              </div>

              <div
                class="home-stat home-stat--interactive"
                phx-click={JS.navigate("/tiqits?status=fleeted")}
                role="link"
                tabindex="0"
              >
                <span class="home-stat__value">{@fleeted_tiqits_count}</span>
                <span class="home-stat__label">fleeted</span>
              </div>
            </div>
          </.surface_panel>
        </div>
      </Layouts.mobile>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :logo_src, :string, required: true
  attr :logo_alt, :string, required: true

  defp home_stat_card_header(assigns) do
    ~H"""
    <div class="flex items-start justify-between gap-3 mb-6">
      <h2 class="text-xl font-bold tracking-tight text-base-content/50">{@title}</h2>
      <img src={@logo_src} alt={@logo_alt} class="h-6 w-auto shrink-0" />
    </div>
    """
  end

end
