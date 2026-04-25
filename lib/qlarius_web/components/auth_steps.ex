defmodule QlariusWeb.Components.AuthSteps do
  @moduledoc """
  Shared step-UI sub-components for the SMS-based auth/registration flow.

  Extracted from `QlariusWeb.RegistrationLive` so the same visuals can be reused
  by the new `AuthSheet` / `ProxyUserSheet` LiveComponents (plan §5.2) without
  forking the markup.

  ## Events emitted

  These are function components — all state lives in the parent
  LiveView/LiveComponent. Handlers must exist in the parent for:

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

  ## Using from a LiveComponent

  When rendering inside a `Phoenix.LiveComponent`, pass `target={@myself}` on
  each component invocation so events route to the component's `handle_event/3`
  rather than the root LiveView.
  """

  use Phoenix.Component

  import QlariusWeb.CoreComponents, only: [icon: 1]
  import QlariusWeb.Components.CustomComponentsMobile, only: [date_input: 1]

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
          No Name: Build Your Alias
        </h2>
        <p class="text-sm md:text-lg text-base-content/70 dark:text-base-content/60">
          We'd rather not know your name. Select a unique alias + number combo. This will be the 'username' for your account.
        </p>
      </div>

      <%!-- Reserve space always so later selections don't flash/shift layout --%>
      <div class="p-3 md:p-4 bg-base-200 dark:bg-base-100 rounded-lg border border-base-300">
        <div class="flex items-center justify-between gap-2">
          <div class="min-w-0">
            <p class="text-xs md:text-sm text-base-content/70 dark:text-base-content/60">Your full alias:</p>
            <p class={[
              "text-lg md:text-2xl font-bold mt-0.5 md:mt-1 truncate",
              if(@alias != "", do: "text-primary dark:text-primary", else: "text-base-content/30")
            ]}>
              <%= if @alias != "", do: @alias, else: "—" %>
            </p>
          </div>
          <%= if @alias != "" do %>
            <div class="badge badge-success badge-sm md:badge-lg gap-1 md:gap-2 flex-shrink-0">
              <.icon name="hero-check-circle" class="w-4 h-4 md:w-5 md:h-5" /> Available
            </div>
          <% else %>
            <div class="badge badge-warning badge-sm md:badge-lg gap-1 md:gap-2 flex-shrink-0">
              <.icon name="hero-ellipsis-horizontal-circle" class="w-4 h-4 md:w-5 md:h-5" /> Building
            </div>
          <% end %>
        </div>
      </div>

      <div class="space-y-2 md:space-y-3">
        <label class="label-text text-sm md:text-lg dark:text-gray-300 font-medium">
          Select an alias and number below:
        </label>

        <div class="grid grid-cols-3 gap-2 md:gap-4">
          <%!-- Left column: base names (2/3) --%>
          <div class="col-span-2 space-y-2">
            <div class="flex justify-end">
              <button
                type="button"
                phx-click="regenerate_base_names"
                phx-target={@target}
                class="btn btn-xs md:btn-sm btn-ghost gap-1"
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
                  "w-full px-2 py-2 md:p-3 rounded-lg text-left transition-all border-2",
                  if(@selected_base == base_name,
                    do: "bg-primary/20 border-primary dark:bg-primary/30 dark:border-primary",
                    else:
                      "bg-base-200 border-base-300 hover:bg-base-300 dark:bg-base-100 dark:border-base-200"
                  )
                ]}
              >
                <div class="flex items-center gap-1.5 md:gap-2 min-w-0">
                  <%= if @selected_base == base_name do %>
                    <.icon name="hero-check-circle-solid" class="w-4 h-4 md:w-5 md:h-5 text-primary flex-shrink-0" />
                  <% else %>
                    <.icon name="hero-circle" class="w-4 h-4 md:w-5 md:h-5 text-base-content/30 flex-shrink-0" />
                  <% end %>
                  <span class="font-medium text-sm md:text-base dark:text-white truncate">{base_name}</span>
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
                  class="btn btn-xs md:btn-sm btn-ghost gap-1"
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
              <div class="flex items-center justify-center min-h-[160px] md:min-h-[200px] bg-base-200 dark:bg-base-100 rounded-lg border-2 border-dashed border-base-300">
                <p class="text-base-content/50 text-center px-2 text-xs md:text-sm">
                  Pick a name first
                </p>
              </div>
            <% else %>
              <%= for number <- @available_numbers do %>
                <button
                  type="button"
                  phx-click="select_number"
                  phx-value-number={number}
                  phx-target={@target}
                  class={[
                    "w-full px-2 py-2 md:p-3 rounded-lg text-left transition-all border-2",
                    if(@selected_number == number,
                      do: "bg-primary/20 border-primary dark:bg-primary/30 dark:border-primary",
                      else:
                        "bg-base-200 border-base-300 hover:bg-base-300 dark:bg-base-100 dark:border-base-200"
                    )
                  ]}
                >
                  <div class="flex items-center gap-1.5 md:gap-2">
                    <%= if @selected_number == number do %>
                      <.icon name="hero-check-circle-solid" class="w-4 h-4 md:w-5 md:h-5 text-primary flex-shrink-0" />
                    <% else %>
                      <.icon name="hero-circle" class="w-4 h-4 md:w-5 md:h-5 text-base-content/30 flex-shrink-0" />
                    <% end %>
                        <span class="font-medium text-sm md:text-base dark:text-white">-{number}</span>
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
        <h2 class="text-2xl md:text-3xl font-bold mb-3 dark:text-white">Core MeFile Data</h2>
        <div class="alert alert-warning">
          <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
          <span class="text-base">
            <strong>Important:</strong>
            Birthdate and Sex data cannot be updated later. Please ensure accuracy.
          </span>
        </div>
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
          min_age={16}
        />
      </div>

      <.form for={%{}} phx-change="select_sex" phx-target={@target}>
        <div class="form-control w-full">
          <label class="label">
            <span class="label-text text-lg dark:text-gray-300">Sex (Biological/Assigned at Birth) *</span>
          </label>
          <select
            name="sex_id"
            class="select select-bordered select-lg w-full text-lg dark:bg-base-100 dark:text-white"
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
            class={"input input-bordered input-lg w-full text-lg dark:bg-base-100 dark:text-white #{if @zip_lookup_error, do: "input-error"}"}
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
              <div class="badge badge-primary badge-lg p-4 text-base">
                <.icon name="hero-map-pin" class="w-5 h-5 mr-2" />
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
  attr :can_complete, :boolean, default: false
  attr :target, :any, default: nil

  def confirm_step(assigns) do
    ~H"""
    <div class="space-y-4">
      <div>
        <h2 class="text-2xl md:text-3xl font-bold mb-3 dark:text-white">Confirm Your Information</h2>
        <%= if not @can_complete do %>
          <div class="alert alert-warning">
            <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
            <span class="text-sm">Please check the confirmation box to complete registration.</span>
          </div>
        <% end %>
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
            <span class="text-sm md:text-base font-medium text-success dark:text-success">
              <.icon name="hero-check-circle" class="w-4 h-4 inline mr-1" />
              {@referral_code}
            </span>
          </div>
        <% end %>
      </div>

      <div class="form-control mt-4">
        <label class="cursor-pointer flex items-start gap-3 p-3 bg-base-200 dark:bg-base-200 rounded-lg">
          <input
            type="checkbox"
            class="checkbox checkbox-primary flex-shrink-0 mt-0.5"
            checked={@confirmation_checked}
            phx-click="toggle_confirmation"
            phx-value-checked={to_string(!@confirmation_checked)}
            phx-target={@target}
          />
          <span class="text-sm md:text-base dark:text-gray-300">
            I confirm my birthdate and sex are correct and understand the data values cannot be updated later.
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
  Formats a 10-digit US mobile number as `XXX-XXX-XXXX`. Returns the input
  unchanged if it isn't 10 digits after stripping non-numeric characters.
  """
  def format_phone_number(phone_number) when is_binary(phone_number) do
    digits = String.replace(phone_number, ~r/\D/, "")

    case String.length(digits) do
      10 ->
        <<area::binary-size(3), prefix::binary-size(3), line::binary-size(4)>> = digits
        "#{area}-#{prefix}-#{line}"

      _ ->
        phone_number
    end
  end

  def format_phone_number(_), do: ""
end
