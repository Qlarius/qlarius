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
  Widget-themed step indicator (`Alias` / `Data` / `Confirm`) shared by
  `AuthSheet`, `ProxyUserSheet`, and `RegistrationLive` surfaces.
  """
  attr :step, :atom, required: true, values: [:alias, :data, :confirm]

  def signup_progress_bar(assigns) do
    ~H"""
    <div
      class="mb-2 flex w-full items-start justify-center gap-0 px-4 sm:px-6"
      role="navigation"
      aria-label="Registration steps"
    >
      <div class="flex shrink-0 flex-col items-center gap-1 text-center">
        <.signup_progress_circle n={1} flow_step={@step} />
        <.signup_progress_label label="Alias" n={1} flow_step={@step} />
      </div>
      <div
        class="flex h-9 min-w-[0.5rem] flex-1 items-center px-0.5 sm:min-w-[0.75rem] sm:px-1"
        aria-hidden="true"
      >
        <div class="h-0.5 w-full rounded-full bg-widget-300"></div>
      </div>
      <div class="flex shrink-0 flex-col items-center gap-1 text-center">
        <.signup_progress_circle n={2} flow_step={@step} />
        <.signup_progress_label label="Data" n={2} flow_step={@step} />
      </div>
      <div
        class="flex h-9 min-w-[0.5rem] flex-1 items-center px-0.5 sm:min-w-[0.75rem] sm:px-1"
        aria-hidden="true"
      >
        <div class="h-0.5 w-full rounded-full bg-widget-300"></div>
      </div>
      <div class="flex shrink-0 flex-col items-center gap-1 text-center">
        <.signup_progress_circle n={3} flow_step={@step} />
        <.signup_progress_label label="Confirm" n={3} flow_step={@step} />
      </div>
    </div>
    """
  end

  attr :n, :integer, required: true
  attr :flow_step, :atom, required: true

  defp signup_progress_circle(assigns) do
    status = signup_step_status(assigns.n, assigns.flow_step)

    circle =
      case status do
        :done ->
          "border-widget-700 bg-widget-700 text-white shadow-sm"

        :current ->
          "border-widget-700 bg-widget-100 text-widget-900 shadow-sm ring-2 ring-widget-200"

        :upcoming ->
          "border-widget-200 bg-base-200 text-base-content/40"
      end

    assigns = assign(assigns, :circle_class, circle)

    ~H"""
    <div class={"flex h-9 w-9 items-center justify-center rounded-full border-2 text-sm font-bold transition-colors #{@circle_class}"}>
      {@n}
    </div>
    """
  end

  attr :label, :string, required: true
  attr :n, :integer, required: true
  attr :flow_step, :atom, required: true

  defp signup_progress_label(assigns) do
    status = signup_step_status(assigns.n, assigns.flow_step)

    label_class =
      if status == :upcoming,
        do: "text-base-content/50",
        else: "text-widget-900"

    assigns = assign(assigns, :label_class, label_class)

    ~H"""
    <span class={"text-[10px] font-semibold uppercase tracking-wide sm:text-xs #{@label_class}"}>
      {@label}
    </span>
    """
  end

  defp signup_step_status(1, step) when step in [:data, :confirm], do: :done
  defp signup_step_status(1, :alias), do: :current
  defp signup_step_status(1, _), do: :upcoming

  defp signup_step_status(2, :confirm), do: :done
  defp signup_step_status(2, :data), do: :current
  defp signup_step_status(2, _), do: :upcoming

  defp signup_step_status(3, :confirm), do: :current
  defp signup_step_status(3, _), do: :upcoming

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
          <span class="font-semibold text-widget-900 dark:text-white tabular-nums">
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
        class="btn-widget btn-lg btn-block min-h-14 rounded-full border border-widget-300 bg-base-100 py-3.5 text-base text-widget-900 hover:bg-base-200 dark:border-widget-600 dark:bg-base-200 dark:hover:bg-base-300"
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

      <div
        class="rounded-xl border border-widget-300 bg-widget-100 p-4 text-center"
        role="status"
      >
        <div class="mx-auto min-w-0 max-w-lg space-y-2">
          <h2 class="text-xl font-bold leading-snug text-widget-900 md:text-2xl dark:text-white">
            <span class="font-semibold text-widget-900 dark:text-white">
              {format_phone_number(@mobile_number)}
            </span>
            {" "}is new here!
          </h2>
          <p class="text-sm leading-relaxed text-base-content/80 md:text-base">
            Let's set you up and fund your wallet.
          </p>
          <p class="text-sm leading-relaxed text-base-content/80 md:text-base">
            Going forward, your mobile number is all you need to connect to the entire Qadabra suite.
          </p>
        </div>
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
          class="btn-widget btn-widget-emphasis btn-lg btn-block min-h-14 w-full rounded-full py-3.5 text-base"
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
    <div class="space-y-4 md:space-y-6">
      <div>
        <h2 class="text-xl md:text-3xl font-bold mb-2 md:mb-3 dark:text-white">
          Build Your Alias
        </h2>
        <p class="text-sm md:text-lg text-base-content/70 dark:text-base-content/60">
          No real names here. Build a unique alias to serve as the 'username' for your account.
        </p>
      </div>

      <%!-- Reserve space always so later selections don't flash/shift layout --%>
      <div class="rounded-lg border border-widget-300 bg-widget-100 p-3 md:p-4">
        <div class="flex items-center justify-between gap-2">
          <div class="min-w-0">
            <p class="text-xs text-widget-800/80 md:text-sm">Your full alias:</p>
            <p class={[
              "mt-0.5 flex min-h-[1.75rem] items-center truncate text-lg font-bold md:mt-1 md:min-h-[2.5rem] md:text-2xl",
              if(@alias != "", do: "text-widget-900", else: "text-widget-800/85")
            ]}>
              <%= if @alias != "" do %>
                {@alias}
              <% else %>
                <span class="inline-flex items-center gap-2" role="status" aria-live="polite">
                  <span class="loading loading-dots loading-md shrink-0 text-widget-700 md:loading-lg">
                  </span>
                  <span class="sr-only">
                    Your full alias will appear here as you pick a name and number.
                  </span>
                </span>
              <% end %>
            </p>
          </div>
          <%= if @alias != "" do %>
            <div class="badge-widget inline-flex shrink-0 items-center justify-center gap-1.5 rounded-lg px-2 py-2.5 text-xs font-semibold leading-none md:gap-2 md:px-2.5 md:py-3 md:text-sm">
              <.icon name="hero-check-circle" class="h-4 w-4 shrink-0 md:h-5 md:w-5" /> Available
            </div>
          <% else %>
            <div class="badge-widget-soft inline-flex shrink-0 items-center justify-center gap-1.5 rounded-lg px-2 py-2.5 text-xs font-semibold leading-none md:gap-2 md:px-2.5 md:py-3 md:text-sm">
              <.icon name="hero-ellipsis-horizontal-circle" class="h-4 w-4 shrink-0 md:h-5 md:w-5" />
              Building
            </div>
          <% end %>
        </div>
      </div>

      <div class="space-y-2 md:space-y-3">
        <label class="label-text text-sm font-medium text-widget-900 md:text-lg">
          Select an alias and then number below:
        </label>

        <div class="grid grid-cols-3 gap-2 md:gap-4">
          <%!-- Left column: base names (2/3) --%>
          <div class="col-span-2 space-y-2">
            <div class="flex justify-end">
              <button
                type="button"
                phx-click="regenerate_base_names"
                phx-target={@target}
                class="btn-widget-ghost btn-xs gap-1 md:btn-sm"
                title="Generate new names"
              >
                <.icon name="hero-arrow-path" class="w-3.5 h-3.5 md:w-4 md:h-4" />
                <span class="hidden sm:inline text-xs md:text-sm">New names</span>
              </button>
            </div>

            <%= for base_name <- @base_names do %>
              <button
                type="button"
                phx-click="select_base_name"
                phx-value-base_name={base_name}
                phx-target={@target}
                class={[
                  "group btn btn-block flex h-auto min-h-12 w-full cursor-pointer justify-start rounded-full border-solid px-3 py-2 text-left text-sm font-medium !shadow-none transition-[color,background-color,border-color,transform] md:min-h-14 md:px-4 md:py-2.5 md:text-base",
                  "focus:outline-none focus-visible:ring-2 focus-visible:ring-widget-400 focus-visible:ring-offset-2 focus-visible:ring-offset-base-100 active:scale-[0.995]",
                  if(@selected_base == base_name,
                    do:
                      "border-[3px] border-widget-900 bg-widget-100 text-widget-900 hover:border-widget-900 hover:bg-widget-100 hover:!shadow-none",
                    else:
                      "border-2 border-widget-300 bg-widget-100 text-widget-900 hover:border-widget-700 hover:bg-widget-800 hover:text-white hover:!shadow-none"
                  )
                ]}
              >
                <div class="flex min-w-0 items-center gap-1.5 md:gap-2">
                  <%= if @selected_base == base_name do %>
                    <.icon
                      name="hero-check-circle-solid"
                      class="h-4 w-4 shrink-0 text-widget-800 md:h-5 md:w-5"
                    />
                  <% else %>
                    <.icon
                      name="hero-circle"
                      class="h-4 w-4 shrink-0 text-widget-800/35 group-hover:text-white/70 md:h-5 md:w-5"
                    />
                  <% end %>
                  <span class="truncate text-sm font-medium text-inherit md:text-base">
                    {base_name}
                  </span>
                </div>
              </button>
            <% end %>
          </div>

          <%!-- Right column: numbers (1/3) --%>
          <div class="col-span-1 space-y-2">
            <div class="flex justify-end">
              <%= if @selected_base do %>
                <button
                  type="button"
                  phx-click="regenerate_numbers"
                  phx-target={@target}
                  class="btn-widget-ghost btn-xs gap-1 md:btn-sm"
                  title="Generate new numbers"
                >
                  <.icon name="hero-arrow-path" class="w-3.5 h-3.5 md:w-4 md:h-4" />
                  <span class="hidden md:inline text-xs md:text-sm">New #s</span>
                </button>
              <% else %>
                <%!-- keep row heights aligned with names column --%>
                <div class="h-6 md:h-8"></div>
              <% end %>
            </div>

            <%= if is_nil(@selected_base) do %>
              <%= for _ <- @base_names do %>
                <div
                  class="flex min-h-12 w-full shrink-0 cursor-not-allowed items-center rounded-full border-2 border-dashed border-widget-300 bg-base-200 md:min-h-14"
                  aria-hidden="true"
                >
                </div>
              <% end %>
            <% else %>
              <%= for number <- @available_numbers do %>
                <button
                  type="button"
                  phx-click="select_number"
                  phx-value-number={number}
                  phx-target={@target}
                  class={[
                    "group btn btn-block flex h-auto min-h-12 w-full cursor-pointer justify-start rounded-full border-solid px-3 py-2 text-left text-sm font-medium transition-[color,background-color,border-color,box-shadow,transform] md:min-h-14 md:px-4 md:py-2.5 md:text-base",
                    "focus:outline-none focus-visible:ring-2 focus-visible:ring-widget-400 focus-visible:ring-offset-2 focus-visible:ring-offset-base-100 active:scale-[0.995]",
                    if(@selected_number == number,
                      do:
                        "border-[3px] border-widget-900 bg-widget-100 text-widget-900 shadow-md hover:border-widget-900 hover:bg-widget-100 hover:shadow-md",
                      else:
                        "border-2 border-widget-300 bg-widget-100 text-widget-900 shadow-none hover:border-widget-700 hover:bg-widget-800 hover:text-white hover:shadow-none"
                    )
                  ]}
                >
                  <div class="flex items-center gap-1.5 md:gap-2">
                    <%= if @selected_number == number do %>
                      <.icon
                        name="hero-check-circle-solid"
                        class="h-4 w-4 shrink-0 text-widget-800 md:h-5 md:w-5"
                      />
                    <% else %>
                      <.icon
                        name="hero-circle"
                        class="h-4 w-4 shrink-0 text-widget-800/35 group-hover:text-white/70 md:h-5 md:w-5"
                      />
                    <% end %>
                    <span class="text-sm font-medium text-inherit md:text-base">-{number}</span>
                  </div>
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
    <div class="space-y-6">
      <div>
        <h2 class="text-2xl md:text-3xl font-bold mb-3 dark:text-white">Basic Data</h2>
      </div>

      <div class="form-control w-full">
        <label class="label">
          <span class="label-text text-lg dark:text-gray-300">Birthdate *</span>
        </label>
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
        <div class="form-control w-full">
          <label class="label">
            <span class="label-text text-lg dark:text-gray-300">Sex (Genetic) *</span>
          </label>
          <select
            name="sex_id"
            class="select select-bordered select-lg w-full border-widget-300 text-lg focus:border-widget-700 focus:outline-none focus:ring-2 focus:ring-widget-200"
          >
            <option value="" selected={is_nil(@sex_trait_id)}>Select...</option>
            <%= for option <- @sex_options do %>
              <option value={option.id} selected={@sex_trait_id == option.id}>{option.name}</option>
            <% end %>
          </select>
        </div>
      </.form>

      <.form for={%{}} phx-change="lookup_zip_code" phx-debounce="500" phx-target={@target}>
        <div class="form-control w-full">
          <label class="label">
            <span class="label-text text-lg dark:text-gray-300">
              Home Zip Code *
            </span>
          </label>
          <input
            id="zip-code-input"
            name="zip"
            type="text"
            placeholder="Enter 5-digit zip code"
            maxlength="5"
            class={"input input-bordered w-full border-widget-300 text-xl font-medium tabular-nums tracking-wide focus:border-widget-700 focus:outline-none focus:ring-2 focus:ring-widget-200 md:text-2xl #{if @zip_lookup_error, do: "input-error"}"}
            value={@zip_lookup_input}
          />
          <%= if @zip_lookup_error do %>
            <div class="mt-3">
              <div class="alert alert-error text-sm">
                <.icon name="hero-x-circle" class="w-5 h-5 shrink-0" />
                <span>{@zip_lookup_error}</span>
              </div>
            </div>
          <% end %>
          <%= if @zip_lookup_valid and @zip_lookup_trait do %>
            <div class="mt-3">
              <div class="badge-widget-soft badge-lg px-4 py-3 text-base">
                <.icon name="hero-map-pin" class="mr-2 h-5 w-5" />
                {@zip_lookup_trait.meta_1}
              </div>
            </div>
          <% end %>
        </div>
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
    <div class="space-y-4">
      <div>
        <h2 class="text-2xl md:text-3xl font-bold mb-3 dark:text-white">Confirm Your Information</h2>
      </div>

      <div class="space-y-1">
        <%= if @mobile_number != "" do %>
          <div class="flex justify-between items-center py-2 border-b border-base-300 dark:border-base-content/20">
            <span class="text-sm md:text-base text-base-content/70 dark:text-base-content/60">
              Mobile Number:
            </span>
            <span class="text-sm md:text-base font-medium dark:text-white">
              {format_phone_number(@mobile_number)}
            </span>
          </div>
        <% end %>

        <div class="flex justify-between items-center py-2 border-b border-base-300 dark:border-base-content/20">
          <span class="text-sm md:text-base text-base-content/70 dark:text-base-content/60">
            Alias:
          </span>
          <span class="text-sm md:text-base font-medium dark:text-white">{@alias}</span>
        </div>

        <div class="flex justify-between items-center py-2 border-b border-base-300 dark:border-base-content/20">
          <span class="text-sm md:text-base text-base-content/70 dark:text-base-content/60">
            Sex:
          </span>
          <span class="text-sm md:text-base font-medium dark:text-white">
            {sex_label(@sex_options, @sex_trait_id)}
          </span>
        </div>

        <div class="flex justify-between items-center py-2 border-b border-base-300 dark:border-base-content/20">
          <span class="text-sm md:text-base text-base-content/70 dark:text-base-content/60">
            Birthdate:
          </span>
          <span class="text-sm md:text-base font-medium dark:text-white">
            {@birthdate_month}/{@birthdate_day}/{@birthdate_year}
          </span>
        </div>

        <div class="flex justify-between items-center py-2 border-b border-base-300 dark:border-base-content/20">
          <span class="text-sm md:text-base text-base-content/70 dark:text-base-content/60">
            Age:
          </span>
          <span class="text-sm md:text-base font-medium dark:text-white">{@calculated_age}</span>
        </div>

        <%= if @zip_lookup_trait do %>
          <div class="flex justify-between items-center py-2 border-b border-base-300 dark:border-base-content/20">
            <span class="text-sm md:text-base text-base-content/70 dark:text-base-content/60">
              Home Zip Code:
            </span>
            <span class="text-sm md:text-base font-medium dark:text-white">
              {@zip_lookup_trait.trait_name} - {@zip_lookup_trait.meta_1}
            </span>
          </div>
        <% end %>

        <%= if @show_referral_code and @referral_code != "" do %>
          <div class="flex justify-between items-center py-2 border-b border-base-300 dark:border-base-content/20">
            <span class="text-sm md:text-base text-base-content/70 dark:text-base-content/60">
              Referral Code:
            </span>
            <span class="text-sm font-medium text-widget-800 md:text-base">
              <.icon name="hero-check-circle" class="mr-1 inline h-4 w-4" />
              {@referral_code}
            </span>
          </div>
        <% end %>
      </div>

      <div class="form-control mt-4 space-y-3">
        <label class="flex cursor-pointer items-start gap-3 rounded-lg border border-widget-200 bg-widget-100 p-3">
          <input
            type="checkbox"
            class="checkbox mt-0.5 shrink-0 border-2 border-widget-300 checked:border-widget-700 checked:bg-widget-700 checked:text-white"
            checked={@confirmation_checked}
            phx-click="toggle_confirmation"
            phx-value-checked={to_string(!@confirmation_checked)}
            phx-target={@target}
          />
          <span class="text-sm md:text-base dark:text-gray-300">
            I confirm my birthdate and sex are correct as entered and understand the values cannot be updated later.
          </span>
        </label>

        <label class="flex cursor-pointer items-start gap-3 rounded-lg border border-widget-200 bg-widget-100 p-3">
          <input
            type="checkbox"
            class="checkbox mt-0.5 shrink-0 border-2 border-widget-300 checked:border-widget-700 checked:bg-widget-700 checked:text-white"
            checked={@legal_confirmation_checked}
            phx-click="toggle_legal_confirmation"
            phx-value-checked={to_string(!@legal_confirmation_checked)}
            phx-target={@target}
          />
          <span class="text-sm md:text-base dark:text-gray-300">
            I agree to the
            <a
              href="https://qadabra.co/app/privacy"
              target="_blank"
              rel="noopener noreferrer"
              class="font-semibold text-widget-800 underline decoration-widget-400 underline-offset-2 hover:text-widget-900"
            >
              Privacy Policy
            </a>
            {" "}and{" "}
            <a
              href="https://qadabra.co/app/terms"
              target="_blank"
              rel="noopener noreferrer"
              class="font-semibold text-widget-800 underline decoration-widget-400 underline-offset-2 hover:text-widget-900"
            >
              Terms of Service
            </a>
            .
          </span>
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
