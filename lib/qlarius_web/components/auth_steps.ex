defmodule QlariusWeb.Components.AuthSteps do
  @moduledoc """
  Shared step-UI sub-components for the SMS-based auth/registration flow.

  Extracted from `QlariusWeb.RegistrationLive` so the same visuals can be reused
  by the new `AuthSheet` / `ProxyUserSheet` LiveComponents (plan §5.2) without
  forking the markup.

  ## Events emitted

  These are function components — all state lives in the parent
  LiveView/LiveComponent. Handlers must exist in the parent for:

    * `phone_carrier_blocked_panel/1`
      - `back_to_phone`

    * `signup_intro_panel/1`
      - `signup_intro_continue`

    * `alias_picker/1`
      - `select_base_name` (params: `base_name`)
      - `select_number` (params: `number`)
      - `regenerate_base_names`
      - `regenerate_numbers`

    * `data_step/1`
      - `update_birthdate` (params: `year`, `month`, `day`)
      - `select_sex` (params: `sex_id`)
      - `lookup_zip_code` (params: `zip`)

    * `confirm_step/1`
      - `toggle_confirmation` (params: `checked`)
      - `toggle_legal_confirmation` (params: `checked`)

  ## Using from a LiveComponent

  When rendering inside a `Phoenix.LiveComponent`, pass `target={@myself}` on
  each component invocation so events route to the component's `handle_event/3`
  rather than the root LiveView.
  """

  use Phoenix.Component

  import QlariusWeb.CoreComponents, only: [icon: 1]
  import QlariusWeb.Components.CustomComponentsMobile, only: [date_input: 1]

  @doc """
  Step line for the sign-up (`Alias` / `Data` / `Confirm`) shared by
  `AuthSheet`, `ProxyUserSheet`, and `RegistrationLive`: "Step N of 3 · Label"
  over a thin three-part line, on the neutral widget ramp.
  """
  attr :step, :atom, required: true, values: [:alias, :data, :confirm]

  def signup_progress_bar(assigns) do
    {n, label} =
      case assigns.step do
        :alias -> {1, "Alias"}
        :data -> {2, "Data"}
        :confirm -> {3, "Confirm"}
      end

    assigns = assign(assigns, n: n, label: label)

    ~H"""
    <div class="auth-progress" role="navigation" aria-label="Registration steps">
      <p class="auth-progress__label" aria-current="step">
        Step {@n} of 3 · <b>{@label}</b>
      </p>
      <div class="auth-progress__track" aria-hidden="true">
        <span :for={i <- 1..3} class={["auth-progress__seg", i <= @n && "is-on"]}></span>
      </div>
    </div>
    """
  end

  @doc """
  Shown when the carrier gate rejects the number (send path or replay while blocked).

  The parent must handle `back_to_phone`.
  """
  attr :message, :string, required: true
  attr :mobile_number, :string, required: true
  attr :target, :any, required: true

  def phone_carrier_blocked_panel(assigns) do
    ~H"""
    <div class="space-y-5">
      <div class="flex flex-col items-center gap-3 text-center">
        <img
          src="/images/qadabra_logo_squares_color.svg"
          alt="Qadabra"
          class="h-14 w-14 rounded-xl object-contain md:h-16 md:w-16"
        />
        <h2 class="text-2xl font-bold text-widget-900 md:text-3xl dark:text-white">
          This number is not eligible yet
        </h2>
        <p class="text-sm text-base-content/70 md:text-base">
          We could not send a verification code to{" "}
          <span class="font-semibold text-widget-900 dark:text-white">
            {format_phone_number(@mobile_number)}
          </span>
          .
        </p>
      </div>

      <div
        class="rounded-xl border border-error/30 bg-error/10 p-4 text-left text-sm leading-relaxed text-base-content/90 md:text-base"
        role="alert"
      >
        {@message}
      </div>

      <button
        type="button"
        phx-click="back_to_phone"
        phx-target={@target}
        class="auth-cta w-full"
      >
        Try a different number
      </button>
    </div>
    """
  end

  @doc """
  Shown when SMS verification succeeds but the phone is not on file: sets
  expectations for new-account + wallet creation and continued sign-in with
  this number.

  The parent must handle `signup_intro_continue`.
  """
  attr :mobile_number, :string, required: true
  attr :target, :any, required: true

  def signup_intro_panel(assigns) do
    ~H"""
    <div class="space-y-5">
      <div class="flex flex-col items-center gap-3 text-center">
        <img
          src="/images/qadabra_full_gray_opt.svg"
          alt="Qadabra"
          class="h-10 w-auto max-w-[min(20rem,88vw)] object-contain object-center md:h-12"
        />
        <h1 class="text-2xl font-bold text-widget-900 md:text-3xl dark:text-white">
          Welcome
        </h1>
      </div>

      <div class="mx-auto max-w-lg space-y-2 text-center" role="status">
        <h2 class="text-xl font-bold leading-snug text-widget-900 md:text-2xl dark:text-white">
          <span class="whitespace-nowrap">{format_phone_number(@mobile_number)}</span> is new here!
        </h2>
        <p class="text-[15px] leading-snug text-base-content/70 md:text-base">
          Let's set you up and fund your wallet.
        </p>
        <p class="text-[15px] leading-snug text-base-content/70 md:text-base">
          Going forward, your mobile number is all you need to connect to the entire Qadabra suite.
        </p>
      </div>

      <div class="pt-4">
        <div
          class="mx-auto flex w-fit max-w-full flex-wrap items-center justify-center gap-5 md:gap-6"
          aria-label="Qadabra includes Sponster, Tiqit, Qlink, and YouData"
        >
          <div class="flex h-14 w-14 shrink-0 items-center justify-center md:h-[4.25rem] md:w-[4.25rem]">
            <img
              src="/images/sponster_gray_square.svg"
              alt="Sponster"
              class="max-h-full max-w-full object-contain"
            />
          </div>
          <div class="flex h-14 w-14 shrink-0 items-center justify-center md:h-[4.25rem] md:w-[4.25rem]">
            <img
              src="/images/tiqit_gray_square.svg"
              alt="Tiqit"
              class="max-h-full max-w-full object-contain"
            />
          </div>
          <div class="flex h-14 w-14 shrink-0 items-center justify-center md:h-[4.25rem] md:w-[4.25rem]">
            <img
              src="/images/qlink_gray_square.svg"
              alt="Qlink"
              class="max-h-full max-w-full object-contain"
            />
          </div>
          <div class="flex h-14 w-14 shrink-0 items-center justify-center md:h-[4.25rem] md:w-[4.25rem]">
            <img
              src="/images/youdata_gray_square.svg"
              alt="YouData"
              class="max-h-full max-w-full object-contain"
            />
          </div>
        </div>
      </div>

      <div class="pt-2">
        <button
          type="button"
          phx-click="signup_intro_continue"
          phx-target={@target}
          class="auth-cta w-full"
        >
          Let's do this...
        </button>
      </div>
    </div>
    """
  end

  # --- alias_picker (was step_two) -----------------------------------------

  attr :alias, :string, required: true
  attr :alias_error, :string, default: nil
  attr :base_names, :list, required: true
  attr :available_numbers, :list, required: true
  attr :selected_base, :string, default: nil
  attr :selected_number, :string, default: nil
  attr :target, :any, default: nil

  def alias_picker(assigns) do
    ~H"""
    <div class="space-y-5">
      <div>
        <h2 class="auth-title">Build your alias</h2>
        <p class="auth-lede">
          No real names here. Build a unique alias to serve as the 'username' for your account.
        </p>
      </div>

      <%!-- Reserve space always so later selections don't flash/shift layout --%>
      <div class="auth-alias">
        <div class="min-w-0">
          <p class="text-[13px] text-base-content/60">Your full alias</p>
          <p class={[
            "mt-0.5 flex min-h-[1.75rem] items-center break-words text-xl font-bold leading-tight tracking-tight",
            if(@alias != "", do: "text-widget-900", else: "text-widget-800/85")
          ]}>
            <%= if @alias != "" do %>
              {@alias}
            <% else %>
              <span class="inline-flex items-center gap-2" role="status" aria-live="polite">
                <span class="loading loading-dots loading-md shrink-0 text-widget-700"></span>
                <span class="sr-only">
                  Your full alias will appear here as you pick a name and number.
                </span>
              </span>
            <% end %>
          </p>
        </div>
        <%= if @alias != "" do %>
          <span class="badge-widget inline-flex shrink-0 items-center gap-1.5 rounded-full px-2.5 py-1.5 text-xs font-semibold">
            <.icon name="hero-check-circle" class="h-4 w-4 shrink-0" /> Available
          </span>
        <% else %>
          <span class="badge-widget-soft inline-flex shrink-0 items-center gap-1.5 rounded-full px-2.5 py-1.5 text-xs font-semibold">
            <.icon name="hero-ellipsis-horizontal-circle" class="h-4 w-4 shrink-0" /> Building
          </span>
        <% end %>
      </div>

      <p :if={@alias_error} class="auth-entry__error" role="alert">
        <.icon name="hero-exclamation-circle" class="h-4 w-4 shrink-0" />
        {@alias_error}
      </p>

      <div>
        <p class="auth-label">Select an alias and then number below:</p>

        <div class="grid grid-cols-3 gap-2">
          <%!-- Left column: base names (2/3) --%>
          <div class="col-span-2 space-y-2">
            <div class="flex h-8 items-center justify-end">
              <button
                type="button"
                phx-click="regenerate_base_names"
                phx-target={@target}
                class="auth-link min-h-8 gap-1 px-2 text-xs"
                title="Generate new names"
              >
                <.icon name="hero-arrow-path" class="h-3.5 w-3.5" /> New names
              </button>
            </div>

            <%= for base_name <- @base_names do %>
              <button
                type="button"
                phx-click="select_base_name"
                phx-value-base_name={base_name}
                phx-target={@target}
                class={["auth-option", @selected_base == base_name && "is-selected"]}
                aria-pressed={to_string(@selected_base == base_name)}
              >
                <.icon
                  :if={@selected_base == base_name}
                  name="hero-check-circle-solid"
                  class="auth-option__mark"
                />
                <%!-- Heroicons has no plain circle; a drawn ring marks the unselected choice --%>
                <span :if={@selected_base != base_name} class="auth-option__ring" aria-hidden="true">
                </span>
                <span class="truncate">{base_name}</span>
              </button>
            <% end %>
          </div>

          <%!-- Right column: numbers (1/3) --%>
          <div class="col-span-1 space-y-2">
            <div class="flex h-8 items-center justify-end">
              <button
                :if={@selected_base}
                type="button"
                phx-click="regenerate_numbers"
                phx-target={@target}
                class="auth-link min-h-8 gap-1 px-2 text-xs"
                title="Generate new numbers"
              >
                <.icon name="hero-arrow-path" class="h-3.5 w-3.5" /> New #s
              </button>
            </div>

            <%= if is_nil(@selected_base) do %>
              <div
                :for={_ <- @base_names}
                class="auth-option auth-option--placeholder"
                aria-hidden="true"
              >
              </div>
            <% else %>
              <%= for number <- @available_numbers do %>
                <button
                  type="button"
                  phx-click="select_number"
                  phx-value-number={number}
                  phx-target={@target}
                  class={["auth-option", @selected_number == number && "is-selected"]}
                  aria-pressed={to_string(@selected_number == number)}
                >
                  <.icon
                    :if={@selected_number == number}
                    name="hero-check-circle-solid"
                    class="auth-option__mark"
                  />
                  <%!-- Heroicons has no plain circle; a drawn ring marks the unselected choice --%>
                  <span :if={@selected_number != number} class="auth-option__ring" aria-hidden="true">
                  </span>
                  <span class="tabular-nums">-{number}</span>
                </button>
              <% end %>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # --- data_step (was step_three) ------------------------------------------

  attr :sex_trait_id, :integer, default: nil
  attr :sex_options, :list, required: true
  attr :birthdate_year, :string, required: true
  attr :birthdate_month, :string, required: true
  attr :birthdate_day, :string, required: true
  attr :birthdate_valid, :boolean, required: true
  attr :birthdate_error, :string, default: nil
  attr :calculated_age, :integer, default: nil
  attr :zip_lookup_input, :string, default: ""
  attr :zip_lookup_valid, :boolean, default: false
  attr :zip_lookup_error, :string, default: nil
  attr :zip_lookup_trait, :any, default: nil
  attr :target, :any, default: nil

  def data_step(assigns) do
    ~H"""
    <div class="space-y-5">
      <h2 class="auth-title">Basic data</h2>

      <div class="w-full">
        <p class="auth-label">Birthdate *</p>
        <.date_input
          id="birthdate-input"
          month={@birthdate_month}
          day={@birthdate_day}
          year={@birthdate_year}
          error={@birthdate_error}
          valid={@birthdate_valid}
          calculated_age={@calculated_age}
          update_event="update_birthdate"
          min_age={QlariusWeb.BirthdateRules.min_age()}
          max_age={QlariusWeb.BirthdateRules.max_age()}
          widget_theme={true}
        />
      </div>

      <.form for={%{}} phx-change="select_sex" phx-target={@target}>
        <label for="auth-sex-select" class="auth-label">Sex (genetic) *</label>
        <select
          id="auth-sex-select"
          name="sex_id"
          class="select auth-select"
        >
          <option value="" selected={is_nil(@sex_trait_id)}>Select...</option>
          <%= for option <- @sex_options do %>
            <option value={option.id} selected={@sex_trait_id == option.id}>{option.name}</option>
          <% end %>
        </select>
      </.form>

      <.form for={%{}} phx-change="lookup_zip_code" phx-debounce="500" phx-target={@target}>
        <label for="zip-code-input" class="auth-label">Home zip code *</label>
        <div class={[
          "auth-entry__field",
          @zip_lookup_valid && @zip_lookup_trait && "is-valid",
          @zip_lookup_error && "is-error"
        ]}>
          <.icon name="hero-map-pin" class="auth-entry__icon" />
          <input
            id="zip-code-input"
            name="zip"
            type="text"
            inputmode="numeric"
            pattern="[0-9]*"
            autocomplete="postal-code"
            placeholder="00000"
            maxlength="5"
            class="auth-entry__input"
            value={@zip_lookup_input}
            aria-invalid={to_string(@zip_lookup_error != nil)}
          />
          <.icon
            :if={@zip_lookup_valid && @zip_lookup_trait}
            name="hero-check-circle-solid"
            class="auth-entry__ok"
          />
        </div>
        <p :if={@zip_lookup_valid && @zip_lookup_trait} class="auth-entry__note">
          {@zip_lookup_trait.meta_1}
        </p>
        <p :if={@zip_lookup_error} class="auth-entry__error">
          <.icon name="hero-exclamation-circle" class="h-4 w-4 shrink-0" />
          {@zip_lookup_error}
        </p>
      </.form>
    </div>
    """
  end

  # --- confirm_step (was step_four) ----------------------------------------

  attr :mobile_number, :string, default: ""
  attr :alias, :string, required: true
  attr :sex_trait_id, :integer, default: nil
  attr :sex_options, :list, required: true
  attr :birthdate_year, :string, required: true
  attr :birthdate_month, :string, required: true
  attr :birthdate_day, :string, required: true
  attr :calculated_age, :integer, default: nil
  attr :zip_lookup_trait, :any, default: nil
  attr :referral_code, :string, default: ""
  attr :show_referral_code, :boolean, default: true
  attr :confirmation_checked, :boolean, default: false
  attr :legal_confirmation_checked, :boolean, default: false
  attr :can_complete, :boolean, default: false
  attr :target, :any, default: nil

  def confirm_step(assigns) do
    ~H"""
    <div class="space-y-5">
      <h2 class="auth-title">Confirm your information</h2>

      <dl class="auth-rows">
        <div :if={@mobile_number != ""}>
          <dt>Mobile number</dt>
          <dd>{format_phone_number(@mobile_number)}</dd>
        </div>
        <div>
          <dt>Alias</dt>
          <dd>{@alias}</dd>
        </div>
        <div>
          <dt>Sex</dt>
          <dd>{sex_label(@sex_options, @sex_trait_id)}</dd>
        </div>
        <div>
          <dt>Birthdate</dt>
          <dd>{@birthdate_month}/{@birthdate_day}/{@birthdate_year}</dd>
        </div>
        <div>
          <dt>Age</dt>
          <dd>{@calculated_age}</dd>
        </div>
        <div :if={@zip_lookup_trait}>
          <dt>Home zip code</dt>
          <dd>{@zip_lookup_trait.trait_name} - {@zip_lookup_trait.meta_1}</dd>
        </div>
        <div :if={@show_referral_code and @referral_code != ""}>
          <dt>Referral code</dt>
          <dd class="text-widget-800">
            <.icon name="hero-check-circle" class="mr-1 inline h-4 w-4" />{@referral_code}
          </dd>
        </div>
      </dl>

      <div class="space-y-3">
        <label class="auth-check">
          <input
            type="checkbox"
            class="checkbox mt-0.5 shrink-0 checked:text-base-100 checked:[--input-color:var(--color-widget-700)]"
            checked={@confirmation_checked}
            phx-click="toggle_confirmation"
            phx-value-checked={to_string(!@confirmation_checked)}
            phx-target={@target}
          />
          <span>
            I confirm my birthdate and sex are correct as entered and understand the values cannot be updated later.
          </span>
        </label>

        <label class="auth-check">
          <input
            type="checkbox"
            class="checkbox mt-0.5 shrink-0 checked:text-base-100 checked:[--input-color:var(--color-widget-700)]"
            checked={@legal_confirmation_checked}
            phx-click="toggle_legal_confirmation"
            phx-value-checked={to_string(!@legal_confirmation_checked)}
            phx-target={@target}
          />
          <%!-- No-format keeps the link text tight, so the underline stops at the words --%>
          <span phx-no-format>I agree to the <a href="https://qadabra.co/app/privacy" target="_blank" rel="noopener noreferrer" class="font-semibold text-widget-800 underline decoration-widget-400 underline-offset-2 hover:text-widget-900">Privacy Policy</a> and <a href="https://qadabra.co/app/terms" target="_blank" rel="noopener noreferrer" class="font-semibold text-widget-800 underline decoration-widget-400 underline-offset-2 hover:text-widget-900">Terms of Service</a>.</span>
        </label>
      </div>
    </div>
    """
  end

  # --- helpers -------------------------------------------------------------

  defp sex_label(options, sex_trait_id) do
    case Enum.find(options, fn opt -> opt.id == sex_trait_id end) do
      nil -> ""
      %{name: name} -> name
    end
  end

  @doc """
  Formats US mobile input for display as `###-###-####`.

  Strips non-digits, keeps at most 10 digits, and inserts dashes while typing
  (partial forms such as `555`, `555-123`, `555-123-45` until complete).
  """
  def format_phone_number(phone_number) when is_binary(phone_number) do
    d = phone_number |> String.replace(~r/\D/, "") |> String.slice(0, 10)
    len = byte_size(d)

    cond do
      len == 0 ->
        ""

      len <= 3 ->
        d

      len <= 6 ->
        String.slice(d, 0, 3) <> "-" <> String.slice(d, 3, len - 3)

      true ->
        String.slice(d, 0, 3) <>
          "-" <>
          String.slice(d, 3, 3) <>
          "-" <>
          String.slice(d, 6, len - 6)
    end
  end

  def format_phone_number(_), do: ""
end
