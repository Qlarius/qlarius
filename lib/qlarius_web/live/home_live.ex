defmodule QlariusWeb.HomeLive do
  use QlariusWeb, :live_view

  import QlariusWeb.Money
  import QlariusWeb.PWAHelpers

  on_mount {QlariusWeb.DetectMobile, :detect_mobile}

  alias QlariusWeb.Layouts
  alias QlariusWeb.Components.StrongStartComponent
  alias QlariusWeb.Components.LedgerEntriesList
  alias Qlarius.Repo
  alias Qlarius.Tiqit.Arcade.Arcade
  alias Qlarius.Wallets
  alias Qlarius.Wallets.LedgerHeader
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
      |> assign(:home_wallet_summary, nil)
      |> assign(:recent_entries, [])

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
     |> assign(:preserved_tiqits_count, 0)
     |> assign(:recent_entries, [])}
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
      preserved_tiqits_count: Arcade.count_preserved_tiqits(scope),
      home_wallet_summary: Wallets.consumer_wallet_summary(me_file),
      recent_entries: recent_entries(me_file)
    })
  end

  @recent_entry_count 3

  defp recent_entries(me_file) do
    case Repo.get_by(LedgerHeader, me_file_id: me_file.id) do
      nil -> []
      header -> Wallets.list_ledger_entries(header.id, 1, @recent_entry_count).entries
    end
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
        <%!-- Phone: one column. Content area 56rem+ (desktop beside the docked menu):
             hero in one row, setup steps as tiles, products in three columns. --%>
        <div class="@container">
          <div class="home-page">
            <section class="home-hero" aria-label="Wallet">
              <div class="min-w-0">
                <p class="home-hero__label">Spendable balance</p>
                <p class="home-hero__amount">{format_usd(@current_scope.wallet_balance)}</p>
                <.link navigate={~p"/wallet"} class="home-hero__split">
                  <%= if @home_wallet_summary do %>
                    <span>
                      <span class="tabular-amount">
                        {format_usd(@home_wallet_summary.activity_balance)}
                      </span>
                      activity ·
                      <span class="tabular-amount">
                        {format_usd(@home_wallet_summary.credit_allowance)}
                      </span>
                      credit
                    </span>
                  <% else %>
                    <span class="skeleton inline-block h-4 w-40 rounded align-middle"></span>
                  <% end %>
                  <.icon name="hero-chevron-right" class="h-3.5 w-3.5 shrink-0" />
                </.link>
              </div>

              <.link
                :if={(@current_scope.ads_count || 0) > 0}
                navigate={~p"/ads"}
                class="home-hero__cta btn btn-primary btn-lg rounded-full"
              >
                <.icon name="hero-eye" class="h-5 w-5" />
                <span>
                  Collect
                  <span class="tabular-amount">{format_usd(@current_scope.offered_amount)}</span>
                </span>
                <span class="home-hero__cta-tag">
                  {@current_scope.ads_count} {if @current_scope.ads_count == 1, do: "ad", else: "ads"}
                </span>
              </.link>
              <.link
                :if={(@current_scope.ads_count || 0) == 0}
                navigate={~p"/me_file_builder"}
                class="home-hero__cta btn btn-outline btn-lg rounded-full"
              >
                <.icon name="hero-tag" class="h-5 w-5" /> Add tags for more offers
              </.link>
            </section>

            <StrongStartComponent.strong_start
              :if={@show_strong_start}
              progress={@strong_start_progress}
              starter_survey_id={@starter_survey_id}
            />

            <div>
              <div class="home-section-head">
                <h2 id="home-overview-title">Overview</h2>
              </div>
              <section class="home-products" aria-labelledby="home-overview-title">
                <.home_product
                  navigate={~p"/me_file"}
                  brand="youdata"
                  icon="hero-identification"
                  title="MeFile"
                  tagline="Own your data."
                  logo="/images/YouData_logo_color_horiz.svg"
                  logo_alt="YouData"
                >
                  <:value>
                    <span class="home-product__v">{@current_scope.trait_count}</span>
                    <span class="home-product__l">tags</span>
                  </:value>
                  <:stats>
                    <div class="home-stat">
                      <span class="home-stat__value">{@current_scope.trait_count}</span>
                      <span class="home-stat__label">tags</span>
                    </div>
                  </:stats>
                </.home_product>

                <.home_product
                  navigate={~p"/ads"}
                  brand="sponster"
                  icon="hero-play"
                  title="Ads"
                  tagline="Sell your attention."
                  logo="/images/Sponster_logo_color_horiz.svg"
                  logo_alt="Sponster"
                >
                  <:value>
                    <span class="home-product__v">{format_usd(@current_scope.offered_amount)}</span>
                    <span class="home-product__l">{@current_scope.ads_count || 0} offers</span>
                  </:value>
                  <:stats>
                    <div class="home-stat-grid--2">
                      <div class="home-stat">
                        <span class="home-stat__value">{@current_scope.ads_count || 0}</span>
                        <span class="home-stat__label">ads</span>
                      </div>
                      <div class="home-stat">
                        <span class="home-stat__value">
                          {format_usd(@current_scope.offered_amount)}
                        </span>
                        <span class="home-stat__label">offered</span>
                      </div>
                    </div>
                  </:stats>
                </.home_product>

                <.home_product
                  navigate={~p"/tiqits"}
                  brand="tiqit"
                  icon="hero-ticket"
                  title="Stash"
                  tagline="Buy your media."
                  logo="/images/Tiqit_logo_color_horiz.svg"
                  logo_alt="Tiqit"
                >
                  <:value>
                    <span class="home-product__v">
                      <.home_stat_value loading={@home_extras_loading} value={@active_tiqits_count} />
                    </span>
                    <span class="home-product__l">active</span>
                  </:value>
                  <:stats>
                    <div class="home-stat-grid--4">
                      <.link
                        :for={
                          {label, status, value} <- [
                            {"active", "active", @active_tiqits_count},
                            {"kept", "preserved", @preserved_tiqits_count},
                            {"fleeting", "expired", @fleeting_tiqits_count},
                            {"fleeted", "fleeted", @fleeted_tiqits_count}
                          ]
                        }
                        navigate={"/tiqits?status=#{status}"}
                        class="home-stat home-stat--interactive home-product__inner-link"
                      >
                        <span class="home-stat__value">
                          <.home_stat_value loading={@home_extras_loading} value={value} />
                        </span>
                        <span class="home-stat__label">{label}</span>
                      </.link>
                    </div>
                  </:stats>
                </.home_product>
              </section>
            </div>

            <section
              :if={@recent_entries != []}
              class="home-activity"
              aria-labelledby="home-activity-title"
            >
              <div class="home-section-head">
                <h2 id="home-activity-title">Recent activity</h2>
                <.link navigate={~p"/wallet"}>See all</.link>
              </div>
              <ul class="home-activity__list surface-panel">
                <li :for={entry <- @recent_entries} class="home-activity__row">
                  <span class="home-activity__icon">
                    <.icon name={LedgerEntriesList.icon_for_entry(entry)} class="h-4 w-4" />
                  </span>
                  <div class="min-w-0 flex-1">
                    <p class="home-activity__title">{entry.description}</p>
                    <p class="home-activity__meta">
                      {activity_meta(entry, @current_scope)}
                    </p>
                  </div>
                  <span class={[
                    "home-activity__amt",
                    Decimal.compare(entry.amt, 0) == :gt && "is-credit"
                  ]}>
                    {signed_usd(entry.amt)}
                  </span>
                </li>
              </ul>
            </section>
          </div>
        </div>
      </Layouts.mobile>
    </div>
    """
  end

  attr :navigate, :string, required: true
  attr :brand, :string, required: true
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :tagline, :string, required: true
  attr :logo, :string, required: true
  attr :logo_alt, :string, required: true
  slot :value, required: true
  slot :stats, required: true

  # A phone row (chip, name, one figure) that becomes a card with full stats in
  # the three-column wide layout. The title link stretches over the whole block;
  # inner links (Stash filters) sit above it.
  defp home_product(assigns) do
    ~H"""
    <div class={["home-product", "home-product--#{@brand}"]}>
      <div class="home-product__head">
        <span class="home-product__chip"><.icon name={@icon} class="h-5 w-5" /></span>
        <div class="min-w-0 flex-1">
          <.link navigate={@navigate} class="home-product__link">{@title}</.link>
          <p class="home-product__tagline">{@tagline}</p>
        </div>
        <img src={@logo} alt={@logo_alt} class="home-product__logo" />
        <div class="home-product__value">{render_slot(@value)}</div>
        <span class="home-product__chev"><.icon name="hero-chevron-right" class="h-4 w-4" /></span>
      </div>
      <div class="home-product__stats">{render_slot(@stats)}</div>
    </div>
    """
  end

  attr :loading, :boolean, required: true
  attr :value, :any, required: true

  defp home_stat_value(assigns) do
    ~H"""
    <span :if={@loading} class="skeleton inline-block h-[0.8em] w-[1.2em] rounded-md align-middle">
    </span>
    <span :if={not @loading}>{@value}</span>
    """
  end

  defp activity_meta(entry, scope) do
    date = Qlarius.DateTime.format_for_user(entry.created_at, scope.user, :month_day)
    Enum.join(Enum.reject([entry.meta_1, date], &is_nil/1), " · ")
  end

  defp signed_usd(amt) do
    sign = if Decimal.compare(amt, 0) == :lt, do: "−", else: "+"
    sign <> format_usd(Decimal.abs(amt))
  end
end
