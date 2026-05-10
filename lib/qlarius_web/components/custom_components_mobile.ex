defmodule QlariusWeb.Components.CustomComponentsMobile do
  use QlariusWeb, :html

  import QlariusWeb.Money

  alias Qlarius.Accounts.Scope

  @doc """
  A styled toggle switch for Phoenix LiveView state.
  Uses primary color when OFF and success green when ON.
  Scaled up 1.25x from default for better mobile tap targets.
  State is controlled by the `checked` prop and clicks trigger `phx-click`.

  ## Examples

      <.toggle
        id="my-toggle"
        checked={@some_value}
        click="toggle_something"
      />
  """
  attr :id, :string, required: true
  attr :name, :string, default: nil
  attr :checked, :any, default: false
  attr :disabled, :boolean, default: false
  attr :click, :string, default: nil, doc: "phx-click event name"
  attr :rest, :global, include: ~w(phx-change value phx-value-hour)

  def toggle(assigns) do
    # Normalize checked to boolean - handle nil, strings, etc.
    is_checked = assigns.checked in [true, "true"]

    assigns = assign(assigns, :is_checked, is_checked)

    ~H"""
    <span
      id={@id}
      phx-click={@click}
      class={[
        "inline-flex items-center w-14 min-w-14 shrink-0 h-8 rounded-full cursor-pointer transition-colors duration-200 relative overflow-hidden",
        if(@is_checked, do: "bg-success", else: "bg-primary"),
        @disabled && "opacity-50 cursor-not-allowed"
      ]}
      role="switch"
      aria-checked={@is_checked}
    >
      <span class={[
        "absolute top-1 left-1 bg-white rounded-full h-6 w-6 shadow-md transition-transform duration-200",
        @is_checked && "translate-x-6"
      ]}>
      </span>
      <input
        type="checkbox"
        name={@name}
        checked={@is_checked}
        disabled={@disabled}
        class="sr-only"
        {@rest}
      />
    </span>
    """
  end

  @doc """
  A styled toggle switch for localStorage-based settings.
  State is managed client-side via JavaScript hook.
  Default state is ON (true) if not previously set.

  ## Examples

      <.local_toggle
        id="my-local-toggle"
        storage_key="my_setting_key"
      />
  """
  attr :id, :string, required: true

  attr :storage_key, :string,
    required: true,
    doc: "localStorage key (will be prefixed with 'qlarius_')"

  attr :default, :boolean, default: true, doc: "Default value if not set in localStorage"

  def local_toggle(assigns) do
    ~H"""
    <span
      id={@id}
      phx-hook="LocalStorageToggle"
      data-storage-key={@storage_key}
      data-default={@default}
      class="toggle-track inline-flex items-center w-14 min-w-14 shrink-0 h-8 rounded-full cursor-pointer transition-colors duration-200 relative overflow-hidden bg-primary"
      role="switch"
      aria-checked="false"
    >
      <span class="toggle-knob absolute top-1 left-1 bg-white rounded-full h-6 w-6 shadow-md transition-transform duration-200">
      </span>
    </span>
    """
  end

  attr :balance, :any, required: true
  attr :id, :string, default: "wallet-balance"
  attr :footer_label, :string, default: nil
  attr :value_text, :string, default: nil
  attr :anon_strobe?, :boolean, default: false
  attr :compact?, :boolean, default: false

  attr :anon_ready_ellipsis?, :boolean, default: false,
    doc:
      "When true with `value_text`, shows a loading-style animated ellipsis after the label " <>
        "(anon READY / waiting state)."

  def wallet_balance(assigns) do
    ~H"""
    <span
      id={@id}
      phx-hook="WalletPulse"
      class={[
        "inline-flex w-auto bg-sponster-200 dark:bg-sponster-800 text-base-content dark:text-sponster-100 rounded-md border border-sponster-300 dark:border-sponster-500",
        if(@compact?, do: "px-2 py-0.5", else: "px-3 py-1.5"),
        if(@footer_label,
          do: [
            "flex-col items-center justify-center gap-0.5",
            if(@compact?, do: "text-base", else: "text-lg")
          ],
          else: [if(@compact?, do: "items-center text-base", else: "items-center text-lg")]
        ),
        if(@anon_strobe?, do: "wallet-strip-anon-focus")
      ]}
    >
      <span class="font-bold leading-tight inline-flex flex-wrap items-center justify-center gap-0">
        <%= if @value_text not in [nil, ""] do %>
          <%= if @anon_ready_ellipsis? do %>
            <span class="whitespace-nowrap inline-flex items-baseline">
              {String.trim_trailing(@value_text, ".")}
              <span class="wallet-ready-ellipsis" aria-hidden="true">
                <span class="wallet-ready-ellipsis-dot">.</span>
                <span class="wallet-ready-ellipsis-dot">.</span>
                <span class="wallet-ready-ellipsis-dot">.</span>
              </span>
            </span>
          <% else %>
            {@value_text}
          <% end %>
        <% else %>
          {format_usd(@balance)}
        <% end %>
      </span>
      <%= if @footer_label not in [nil, ""] do %>
        <span
          class="text-base-content/40 font-medium"
          style="font-size: 8px; line-height: 10px; letter-spacing: 0.2px; margin-top: -4px;"
        >
          {@footer_label}
        </span>
      <% end %>
    </span>
    """
  end

  attr :count, :integer, required: true

  def tag_count(assigns) do
    ~H"""
    <span class="inline-flex items-center w-auto text-lg bg-youdata-200 dark:bg-youdata-900 text-base-content px-3 py-1 rounded-lg border border-youdata-300 dark:border-youdata-500">
      <span class="font-bold">{@count}&nbsp;tags</span>
    </span>
    """
  end

  attr :current_path, :string, required: true
  attr :current_scope, Scope, required: true

  def onboarding_tip(assigns) do
    assigns =
      assign(assigns, :tip_data, get_tip_data(assigns.current_path, assigns.current_scope))

    ~H"""
    <%= if @tip_data do %>
      <div
        id="onboarding-tip"
        class="fixed bottom-[90px] max-w-md mx-auto left-4 right-4 z-45 transform translate-y-full opacity-0"
        phx-mounted={
          JS.transition(
            {"ease-out duration-500", "translate-y-full opacity-0", "translate-y-0 opacity-100"},
            time: 300
          )
        }
      >
        <div class="shadow-xl bg-base-100 dark:bg-base-200 !border-2 !border-primary rounded-xl overflow-hidden">
          <%!-- Header banner with logo and close button --%>
          <div class="bg-base-200 dark:bg-base-300 px-4 py-3 flex items-center justify-center relative">
            <img src={@tip_data.logo} alt="" class="h-8 w-auto" />
            <button
              phx-click={
                JS.hide(
                  to: "#onboarding-tip",
                  transition:
                    {"ease-in duration-200", "translate-y-0 opacity-100",
                     "translate-y-full opacity-0"}
                )
              }
              class="absolute right-4 btn btn-default btn-xs btn-circle"
              aria-label="Close"
            >
              <.icon name="hero-x-mark" class="w-5 h-5 text-base-content" />
            </button>
          </div>

          <%!-- Content area --%>
          <div class="p-6">
            <%= if @tip_data.screen == :home do %>
              <div>
                <p class="text-lg leading-relaxed text-base-content dark:text-base-content/90">
                  <span class="block font-bold text-2xl">You're in!</span>
                  <span class="block mt-2">
                    Welcome to the Home screen - a great overview of all your Qadabra activities.
                  </span>
                  <span class="block mt-2">
                    Explore the app and look around.
                  </span>
                </p>
              </div>
            <% end %>

            <%= if @tip_data.screen == :wallet do %>
              <div>
                <p class="text-lg leading-relaxed text-base-content dark:text-base-content/90">
                  <span class="block">
                    This is your new attention wallet. It's empty now, but we'll soon fix that.
                  </span>
                  <span class="block mt-2">Add funds by selling your attention (Ads).</span>
                  <span class="block mt-2">
                    Spend funds on your media and to support your favorite creators.
                  </span>
                </p>
              </div>
            <% end %>

            <%= if @tip_data.screen == :me_file do %>
              <div>
                <p class="text-lg leading-relaxed text-base-content dark:text-base-content/90">
                  <span class="block">Build/manage your MeFile here.</span>
                  <span class="block mt-2">
                    You've already got {@current_scope.trait_count} "tags". Add more to optimize the sponsorships that fuel your wallet.
                  </span>
                </p>
              </div>
            <% end %>

            <%= if @tip_data.screen == :tagger do %>
              <div>
                <p class="text-lg leading-relaxed text-base-content dark:text-base-content/90">
                  <span class="block">
                    HINT: Don't spend too much time on this now. 5 minutes or so is plenty to get started.
                  </span>
                  <span class="block mt-2">
                    Start with the "ESSENTIALS" - a bucket of highest-value tags. You can always come back to add tags later and over time.
                  </span>
                </p>
              </div>
            <% end %>

            <%= if @tip_data.screen == :ads do %>
              <div>
                <p class="text-lg leading-relaxed text-base-content dark:text-base-content/90">
                  <span class="block">Sell your attention here.</span>
                  <span class="block mt-2">Funds go straight to your wallet.</span>
                  <span class="block mt-2">
                    The better your MeFile, the better your ads. Optimize to pull more of the right ads for you.
                  </span>
                </p>
              </div>
            <% end %>

            <%!-- Dismiss button --%>
            <div class="mt-6 flex justify-center">
              <button
                phx-click={
                  JS.hide(
                    to: "#onboarding-tip",
                    transition:
                      {"ease-in duration-200", "translate-y-0 opacity-100",
                       "translate-y-full opacity-0"}
                  )
                }
                class="btn btn-primary btn-wide rounded-full"
              >
                Dismiss
              </button>
            </div>
          </div>
          <%!-- End content area --%>
        </div>
      </div>
    <% end %>
    """
  end

  @doc """
  A 6-digit OTP verification code input using single-input pattern for reliability.
  Uses one real input with visual slots - handles paste, autofill, and keyboard naturally.

  ## Examples

      <.otp_input
        id="verification-otp"
        value={@verification_code}
        error={@verification_code_error}
        verify_event="verify_code"
        update_event="update_verification_code"
      />
  """
  attr :id, :string, required: true
  attr :value, :string, default: ""
  attr :error, :string, default: nil

  attr :verify_event, :string,
    required: true,
    doc: "Event name for auto-submit when 6 digits entered"

  attr :update_event, :string,
    required: true,
    doc: "Event name for updating verification_code assign"

  attr :resend_event, :string, default: nil, doc: "Event name for resending code (optional)"

  attr :widget_theme, :boolean,
    default: false,
    doc:
      "When true, OTP slot accents use the embedded widget palette (qlink / " <>
        "AuthSheet) instead of Daisy `primary`."

  def otp_input(assigns) do
    # Split value into individual characters for display
    chars = String.graphemes(assigns.value || "")
    slots = for i <- 0..5, do: Enum.at(chars, i)

    slot_active_class =
      if assigns.widget_theme,
        do: "border-widget-700 bg-base-100 dark:bg-base-200 animate-pulse",
        else: "border-primary bg-base-100 dark:bg-base-200 animate-pulse"

    assigns =
      assigns
      |> assign(:slots, slots)
      |> assign(:slot_active_class, slot_active_class)

    ~H"""
    <div class="form-control w-full">
      <%!-- Single-input OTP with visual slots --%>
      <div
        id={@id}
        phx-hook="OTPInput"
        data-value={@value}
        data-verify-event={@verify_event}
        data-update-event={@update_event}
        data-widget-theme={to_string(@widget_theme)}
        class="flex w-full flex-col gap-4"
      >
        <%!-- Visual slots container with real input layered on top --%>
        <div class="relative">
          <%!-- Real input - visible to browser/autofill but text hidden via letter-spacing trick --%>
          <input
            type="text"
            inputmode="numeric"
            autocomplete="one-time-code"
            name="verification-code"
            maxlength="6"
            pattern="[0-9]*"
            value={@value}
            data-form-type="other"
            data-1p-ignore="true"
            data-lpignore="true"
            data-bwignore="true"
            class={
              "otp-input absolute inset-0 w-full h-full z-10 #{if @error, do: ""} #{if @widget_theme, do: "[caret-color:var(--color-widget-700)]", else: "[caret-color:#3b82f6]"}"
            }
            style="font-size: 1px; color: transparent; background: transparent; border: none; outline: none; padding: 0; margin: 0;"
            aria-label="Enter 6-digit verification code"
          />

          <%!-- Visual slots that display the digits --%>
          <div class="flex justify-center gap-2 sm:gap-3">
            <%= for {char, i} <- Enum.with_index(@slots) do %>
              <div
                class={"otp-slot w-12 h-14 sm:w-14 sm:h-16 flex items-center justify-center text-2xl font-bold rounded-lg border-2 transition-all #{if @error, do: "border-error bg-error/10", else: if(i == 0 && is_nil(char), do: @slot_active_class, else: "border-base-300 bg-base-100 dark:bg-base-200")}"}
                data-index={i}
              >
                {char}
              </div>
            <% end %>
          </div>
        </div>

        <%!-- Status text --%>
        <div class="text-center text-sm h-6">
          <%= cond do %>
            <% @error -> %>
              <span class="text-error">{@error}</span>
            <% String.length(@value) == 6 -> %>
              <span class="text-base-content/60">
                <span class="loading loading-spinner loading-xs mr-1"></span> Verifying...
              </span>
            <% true -> %>
          <% end %>
        </div>
      </div>

      <%= if @resend_event do %>
        <label class="label justify-center">
          <button
            type="button"
            phx-click={@resend_event}
            class={
              if @widget_theme,
                do:
                  "label-text-alt text-base font-medium text-widget-800 hover:text-widget-900 hover:underline",
                else: "label-text-alt link link-primary text-base"
            }
          >
            Resend code
          </button>
        </label>
      <% end %>
    </div>
    """
  end

  @doc """
  A 3-field date input (MM/DD/YYYY) with auto-advance, validation, and backspace navigation.
  Validates first-digit rules and complete date validity.

  ## Examples

      <.date_input
        id="birthdate"
        month={@birthdate_month}
        day={@birthdate_day}
        year={@birthdate_year}
        error={@birthdate_error}
        valid={@birthdate_valid}
        calculated_age={@calculated_age}
        update_event="update_birthdate"
        min_age={16}
      />
  """
  attr :id, :string, required: true
  attr :month, :string, default: ""
  attr :day, :string, default: ""
  attr :year, :string, default: ""
  attr :error, :string, default: nil
  attr :valid, :boolean, default: false
  attr :calculated_age, :integer, default: nil
  attr :update_event, :string, required: true
  attr :min_age, :integer, default: 16

  attr :max_age, :integer,
    default: 120,
    doc: "Upper bound for plausible age; server validation should match."

  attr :widget_theme, :boolean,
    default: false,
    doc: "When true, age badge uses the widget palette (AuthSheet / qlink)."

  def date_input(assigns) do
    age_badge_class =
      if assigns.widget_theme,
        do: "badge-widget-soft badge-lg px-4 py-3 text-base",
        else: "badge badge-primary badge-lg p-4 text-base"

    assigns = assign(assigns, :age_badge_class, age_badge_class)

    ~H"""
    <div class="form-control w-full">
      <div
        id={@id}
        phx-hook="DateInput"
        data-update-event={@update_event}
        data-min-age={@min_age}
        data-max-age={@max_age}
        class="flex w-full flex-col gap-2"
      >
        <%!-- Field labels --%>
        <div class="flex gap-2">
          <div class="flex-1">
            <label class="label py-1">
              <span class="label-text text-sm dark:text-gray-400">MM</span>
            </label>
          </div>
          <div class="flex-1">
            <label class="label py-1">
              <span class="label-text text-sm dark:text-gray-400">DD</span>
            </label>
          </div>
          <div class="flex-[1.5]">
            <label class="label py-1">
              <span class="label-text text-sm dark:text-gray-400">YYYY</span>
            </label>
          </div>
        </div>

        <%!-- Input fields --%>
        <div class="flex gap-2">
          <input
            type="text"
            inputmode="numeric"
            name="month"
            maxlength="2"
            placeholder="##"
            value={@month}
            data-field="month"
            data-1p-ignore="true"
            data-lpignore="true"
            data-bwignore="true"
            data-form-type="other"
            class={"date-field input input-bordered flex-1 text-center text-xl font-medium tabular-nums tracking-wide dark:bg-base-100 dark:text-white md:text-2xl #{if @error, do: "input-error"}"}
          />
          <input
            type="text"
            inputmode="numeric"
            name="day"
            maxlength="2"
            placeholder="##"
            value={@day}
            data-field="day"
            data-1p-ignore="true"
            data-lpignore="true"
            data-bwignore="true"
            data-form-type="other"
            class={"date-field input input-bordered flex-1 text-center text-xl font-medium tabular-nums tracking-wide dark:bg-base-100 dark:text-white md:text-2xl #{if @error, do: "input-error"}"}
          />
          <input
            type="text"
            inputmode="numeric"
            name="year"
            maxlength="4"
            placeholder="####"
            value={@year}
            data-field="year"
            data-1p-ignore="true"
            data-lpignore="true"
            data-bwignore="true"
            data-form-type="other"
            class={"date-field input input-bordered flex-[1.5] text-center text-xl font-medium tabular-nums tracking-wide dark:bg-base-100 dark:text-white md:text-2xl #{if @error, do: "input-error"}"}
          />
        </div>

        <%!-- Status/error display --%>
        <%= cond do %>
          <% @error && @widget_theme -> %>
            <div class="mt-3 space-y-2" role="alert">
              <div class="flex gap-2 rounded-lg border border-error/40 bg-error/10 px-3 py-2 text-sm text-error">
                <.icon name="hero-exclamation-triangle" class="mt-0.5 h-5 w-5 shrink-0" />
                <span class="min-w-0 text-left leading-snug">{@error}</span>
              </div>
              <%= if @calculated_age do %>
                <div class="flex items-center justify-center gap-2 rounded-lg border border-error/50 bg-base-100 px-3 py-2 text-sm font-semibold text-error">
                  <.icon name="hero-calendar" class="h-5 w-5 shrink-0" />
                  <span>Age from this date: {@calculated_age}</span>
                </div>
              <% end %>
            </div>
          <% @error -> %>
            <div class="mt-1 text-center text-sm">
              <span class="text-error">{@error}</span>
            </div>
          <% @valid && @calculated_age -> %>
            <div class="mt-3">
              <div class={@age_badge_class}>
                <.icon name="hero-calendar" class="mr-2 h-5 w-5" /> Age: {@calculated_age}
              </div>
            </div>
          <% true -> %>
            <div class="h-6"></div>
        <% end %>
      </div>
    </div>
    """
  end

  defp get_tip_data(current_path, current_scope) do
    balance_zero? = Decimal.compare(current_scope.wallet_balance, Decimal.new(0)) == :eq
    few_tags? = current_scope.trait_count < 5

    case current_path do
      path when path in ["/", "/home"] and balance_zero? ->
        %{screen: :home, logo: "/images/qadabra_logo_squares_color.svg"}

      "/wallet" when balance_zero? ->
        %{screen: :wallet, logo: "/images/qadabra_logo_squares_color.svg"}

      "/me_file" when few_tags? ->
        %{screen: :me_file, logo: "/images/YouData_logo_color_horiz.svg"}

      "/me_file_builder" when few_tags? ->
        %{screen: :tagger, logo: "/images/YouData_logo_color_horiz.svg"}

      "/ads" when balance_zero? ->
        %{screen: :ads, logo: "/images/Sponster_logo_color_horiz.svg"}

      _ ->
        nil
    end
  end
end
