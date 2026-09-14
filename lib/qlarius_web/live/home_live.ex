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
    trait_count = scope.trait_count

    socket =
      socket
      |> assign(:current_path, "/home")
      |> assign(:title, "Home")
      |> init_pwa_assigns(session)
      |> assign(:show_strong_start, false)
      |> assign(:strong_start_progress, nil)
      |> assign(:starter_survey_id, nil)
      |> assign(:home_extras_loading, true)
      |> assign(:active_tiqits_count, nil)
      |> assign(:fleeting_tiqits_count, nil)
      |> assign(:fleeted_tiqits_count, nil)
      |> assign(:preserved_tiqits_count, nil)

    socket =
      if connected?(socket) do
        start_async(socket, :home_extras, fn ->
          load_home_extras(me_file, scope, trait_count)
        end)
      else
        socket
      end

    {:ok, socket}
  end

  def handle_async(:home_extras, {:ok, extras}, socket) do
    {:noreply, socket |> assign(extras) |> assign(:home_extras_loading, false)}
  end

  def handle_async(:home_extras, {:exit, _reason}, socket) do
    {:noreply,
     socket
     |> assign(:home_extras_loading, false)
     |> assign(:show_strong_start, false)
     |> assign(:active_tiqits_count, 0)
     |> assign(:fleeting_tiqits_count, 0)
     |> assign(:fleeted_tiqits_count, 0)
     |> assign(:preserved_tiqits_count, 0)}
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

  defp load_home_extras(me_file, scope, trait_count) do
    Map.merge(load_strong_start(me_file, trait_count), %{
      active_tiqits_count: Arcade.count_active_tiqits(scope),
      fleeting_tiqits_count: Arcade.count_fleeting_tiqits(scope),
      fleeted_tiqits_count: Arcade.count_fleeted_tiqits(scope),
      preserved_tiqits_count: Arcade.count_preserved_tiqits(scope)
    })
  end

  defp assign_strong_start(socket, me_file) do
    assign(socket, load_strong_start(me_file, socket.assigns.current_scope.trait_count))
  end

  defp load_strong_start(me_file, trait_count) do
    if StrongStart.should_show?(me_file) do
      progress = StrongStart.get_progress(me_file, trait_count)

      if progress.completed_count == progress.total_count do
        StrongStart.mark_all_complete(me_file)

        %{show_strong_start: false, strong_start_progress: nil, starter_survey_id: nil}
      else
        %{
          show_strong_start: true,
          strong_start_progress: progress,
          starter_survey_id: Qlarius.System.get_global_variable_int("STRONG_START_SURVEY_ID", nil)
        }
      end
    else
      %{show_strong_start: false, strong_start_progress: nil, starter_survey_id: nil}
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
                <.home_stat_value loading={@home_extras_loading} value={@active_tiqits_count} />
                <span class="home-stat__label">active</span>
              </div>

              <div
                class="home-stat home-stat--interactive"
                phx-click={JS.navigate("/tiqits?status=preserved")}
                role="link"
                tabindex="0"
              >
                <.home_stat_value loading={@home_extras_loading} value={@preserved_tiqits_count} />
                <span class="home-stat__label">kept</span>
              </div>

              <div
                class="home-stat home-stat--interactive"
                phx-click={JS.navigate("/tiqits?status=expired")}
                role="link"
                tabindex="0"
              >
                <.home_stat_value loading={@home_extras_loading} value={@fleeting_tiqits_count} />
                <span class="home-stat__label">fleeting</span>
              </div>

              <div
                class="home-stat home-stat--interactive"
                phx-click={JS.navigate("/tiqits?status=fleeted")}
                role="link"
                tabindex="0"
              >
                <.home_stat_value loading={@home_extras_loading} value={@fleeted_tiqits_count} />
                <span class="home-stat__label">fleeted</span>
              </div>
            </div>
          </.surface_panel>
        </div>
      </Layouts.mobile>
    </div>
    """
  end

  attr :loading, :boolean, required: true
  attr :value, :any, required: true

  defp home_stat_value(assigns) do
    ~H"""
    <span class="home-stat__value">
      <span :if={@loading} class="skeleton inline-block h-12 w-14 rounded-md align-middle"></span>
      <span :if={not @loading}>{@value}</span>
    </span>
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
