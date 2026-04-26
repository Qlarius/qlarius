defmodule QlariusWeb.Components.ProxyUserSheet do
  @moduledoc """
  Admin-only LiveComponent for creating proxy users in place, without a
  page navigation away from the proxy-users management list.

  Mirrors the public-auth `AuthSheet` sign-up branch visually (same
  `alias → data → confirm` sub-components) so admins exercising the proxy
  creation path see the same UI a real new user will see. There is no
  phone / OTP step (the admin is already signed in; proxies are identified
  by alias only) and no socket-reconnect finalize (the admin's session is
  never replaced — the new proxy starts inactive in the list).

  See `docs/qlink_auth_refactor_plan.md` §5.1 / B4.

  ## State machine

      :alias → :data → :confirm → :creating → :complete
                                      ↓ (error)
                                  :confirm (with `signup_error`)

      :complete → :alias (via "Add another") | close modal

  ## Parent-facing API

      <.live_component
        module={QlariusWeb.Components.ProxyUserSheet}
        id="proxy-sheet"
        show={@show_add_modal}
        admin={@current_scope.true_user}
        on_cancel={JS.push("close_add_modal")}
      />

  On successful creation the component sends
  `{:proxy_user_created, %User{}}` to the parent LV via
  `send(self(), ...)` so the parent can refresh its proxy-users list and
  (optionally) flash + close the modal. The component itself transitions
  to an internal `:complete` state offering an "Add another" affordance;
  the parent controls whether the modal stays open.

  ## Required assigns

    * `:id` — DOM id for the sheet root
    * `:admin` — `%Qlarius.Accounts.User{}`; the admin whose
      `true_user_id` is stamped on the new `UserProxy` row and whose
      me_file `referral_code` is auto-inherited (generated if missing
      — see `Qlarius.Referrals.Context.from_admin/1`)

  ## Optional assigns

    * `:show` — boolean; parent decides when to open. Defaults `false`.
    * `:on_cancel` — `Phoenix.LiveView.JS` command forwarded on close
      (e.g. `JS.push("close_add_modal")`)

  ## Duplication note

  The alias/data/confirm event handlers and helpers below are deliberately
  parallel to the sign-up half of `AuthSheet` (select_base_name,
  select_number, regenerate_*, update_birthdate, lookup_zip_code,
  toggle_confirmation, signup_next/back, submit_signup). With only two
  consumers of the flow (AuthSheet + ProxyUserSheet) we're keeping them
  forked rather than prematurely extracting a shared state-machine helper
  module. If a third consumer appears, extract.
  """

  use QlariusWeb, :live_component

  alias Phoenix.LiveView.JS
  alias Qlarius.Accounts
  alias Qlarius.Accounts.AliasGenerator
  alias Qlarius.Auth.AuditLog
  alias Qlarius.Referrals.Context, as: ReferralContext
  alias Qlarius.YouData.MeFiles
  alias Qlarius.YouData.Traits
  alias QlariusWeb.Components.AuthSteps
  alias QlariusWeb.Live.Helpers.ZipCodeLookup

  @surface :admin_proxy_sheet

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:state, :alias)
     |> assign(:signup_error, nil)
     |> assign(:signup_initialized, false)
     |> assign(:created_user, nil)}
  end

  @impl true
  def update(%{admin: admin} = assigns, socket) do
    socket =
      socket
      |> assign(:id, assigns.id)
      |> assign(:show, Map.get(assigns, :show, false))
      |> assign(:admin, admin)
      |> assign(:on_cancel, Map.get(assigns, :on_cancel, %JS{}))
      # Compute once per LC lifetime; ReferralContext.from_admin/1 will
      # generate and persist a referral code on the admin's me_file if
      # it's missing — we don't want to repeat that work on every update.
      |> assign_new(:referral_context, fn -> ReferralContext.from_admin(admin) end)
      |> init_signup_assigns()

    {:ok, socket}
  end

  # --------------------------------------------------------------------
  # Alias step events
  # --------------------------------------------------------------------

  @impl true
  def handle_event("select_base_name", %{"base_name" => base_name}, socket) do
    available_numbers = AliasGenerator.generate_available_numbers(base_name, 5)

    {:noreply,
     socket
     |> assign(:selected_base, base_name)
     |> assign(:available_numbers, available_numbers)
     |> assign(:selected_number, nil)
     |> assign(:alias, "")
     |> assign(:alias_error, nil)}
  end

  def handle_event("select_number", %{"number" => number}, socket) do
    base_name = socket.assigns.selected_base
    full_alias = "#{base_name}-#{number}"

    {:noreply,
     socket
     |> assign(:selected_number, number)
     |> assign(:alias, full_alias)
     |> assign(:alias_error, nil)}
  end

  def handle_event("regenerate_base_names", _params, socket) do
    case Hammer.check_rate(regenerate_key("base", socket), 60_000, 10) do
      {:allow, _count} ->
        {:noreply,
         socket
         |> assign(:base_names, AliasGenerator.generate_base_names(5))
         |> assign(:selected_base, nil)
         |> assign(:available_numbers, [])
         |> assign(:selected_number, nil)
         |> assign(:alias, "")
         |> assign(:alias_error, nil)}

      {:deny, _limit} ->
        {:noreply, assign(socket, :alias_error, "Please wait before regenerating again.")}
    end
  end

  def handle_event("regenerate_numbers", _params, socket) do
    case socket.assigns.selected_base do
      nil ->
        {:noreply, socket}

      base_name ->
        case Hammer.check_rate(regenerate_key("numbers", socket), 60_000, 10) do
          {:allow, _count} ->
            {:noreply,
             socket
             |> assign(:available_numbers, AliasGenerator.generate_available_numbers(base_name, 5))
             |> assign(:selected_number, nil)
             |> assign(:alias, "")
             |> assign(:alias_error, nil)}

          {:deny, _limit} ->
            {:noreply, assign(socket, :alias_error, "Please wait before regenerating again.")}
        end
    end
  end

  # --------------------------------------------------------------------
  # Data step events
  # --------------------------------------------------------------------

  def handle_event("select_sex", %{"sex_id" => sex_id}, socket) do
    parsed =
      case sex_id do
        "" -> nil
        id when is_binary(id) -> String.to_integer(id)
        id when is_integer(id) -> id
      end

    {:noreply, assign(socket, :sex_trait_id, parsed)}
  end

  def handle_event("update_birthdate", params, socket) do
    year = Map.get(params, "year", socket.assigns.birthdate_year)
    month = Map.get(params, "month", socket.assigns.birthdate_month)
    day = Map.get(params, "day", socket.assigns.birthdate_day)

    {:noreply,
     socket
     |> assign(:birthdate_year, year)
     |> assign(:birthdate_month, month)
     |> assign(:birthdate_day, day)
     |> validate_birthdate()}
  end

  def handle_event("lookup_zip_code", %{"zip" => zip_code}, socket) do
    {:noreply, ZipCodeLookup.handle_zip_lookup(socket, zip_code)}
  end

  # --------------------------------------------------------------------
  # Confirm step events
  # --------------------------------------------------------------------

  def handle_event("toggle_confirmation", %{"checked" => checked}, socket) do
    {:noreply, assign(socket, :confirmation_checked, checked == "true")}
  end

  # --------------------------------------------------------------------
  # Step navigation + submit
  # --------------------------------------------------------------------

  def handle_event("signup_next", _params, socket) do
    {:noreply, advance(socket)}
  end

  def handle_event("signup_back", _params, socket) do
    {:noreply, retreat(socket)}
  end

  def handle_event("submit_signup", _params, socket) do
    if can_complete?(socket.assigns) do
      create_proxy_user(socket)
    else
      {:noreply, assign(socket, :signup_error, "Please complete all required fields.")}
    end
  end

  # "Add another" — reset to :alias with a fresh alias candidate set.
  def handle_event("add_another", _params, socket) do
    {:noreply,
     socket
     |> assign(:state, :alias)
     |> assign(:signup_initialized, false)
     |> assign(:signup_error, nil)
     |> assign(:created_user, nil)
     |> init_signup_assigns()}
  end

  # --------------------------------------------------------------------
  # State machine
  # --------------------------------------------------------------------

  defp advance(%{assigns: %{state: :alias}} = socket) do
    if alias_ready?(socket.assigns) do
      assign(socket, :state, :data)
    else
      assign(socket, :alias_error, "Pick a name and number to build your alias.")
    end
  end

  defp advance(%{assigns: %{state: :data}} = socket) do
    if data_step_ready?(socket.assigns) do
      assign(socket, :state, :confirm)
    else
      assign(socket, :signup_error, "Fill in birthdate, sex, and a valid zip code.")
    end
  end

  defp advance(socket), do: socket

  defp retreat(%{assigns: %{state: :data}} = socket), do: assign(socket, :state, :alias)
  defp retreat(%{assigns: %{state: :confirm}} = socket), do: assign(socket, :state, :data)
  defp retreat(socket), do: socket

  # --------------------------------------------------------------------
  # User creation — no phone, no finalize, new proxy starts inactive.
  # --------------------------------------------------------------------

  defp create_proxy_user(socket) do
    socket = assign(socket, :state, :creating)

    admin = socket.assigns.admin
    attrs = build_user_attrs(socket.assigns, admin)
    referral_code = ReferralContext.code(socket.assigns.referral_context)

    case Accounts.register_new_user(attrs, referral_code) do
      {:ok, %{user: user}} ->
        AuditLog.log(:"register_new_user.allowed", %{
          user_id: user.id,
          alias: user.alias,
          surface: @surface,
          admin_user_id: admin.id,
          referral_source: ReferralContext.source(socket.assigns.referral_context)
        })

        # Notify the parent LV so it can refresh the proxy list.
        # Inside a LiveComponent, `self()` is the parent LiveView process.
        send(self(), {:proxy_user_created, user})

        {:noreply,
         socket
         |> assign(:state, :complete)
         |> assign(:created_user, user)}

      {:error, failed_step, _failed_value, _changes_so_far} ->
        AuditLog.log(:"register_new_user.denied", %{
          surface: @surface,
          admin_user_id: admin.id,
          failed_step: failed_step
        })

        {:noreply,
         socket
         |> assign(:state, :confirm)
         |> assign(:signup_error,
           "We couldn't create the proxy user. Please double-check the details and try again."
         )}
    end
  end

  defp build_user_attrs(assigns, admin) do
    date =
      Date.new!(
        String.to_integer(assigns.birthdate_year),
        String.to_integer(assigns.birthdate_month),
        String.to_integer(assigns.birthdate_day)
      )

    %{
      alias: assigns.alias,
      # Proxy users have no phone — the admin's phone is the
      # auth-bearing one. Leaving `mobile_number: nil` keeps the
      # `mobile_number_hash IS NOT NULL` unique index out of the way.
      mobile_number: nil,
      role: "user",
      date_of_birth: date,
      sex_trait_id: assigns.sex_trait_id,
      age_trait_id: assigns.age_trait_id,
      zip_code_trait_id: if(assigns.zip_lookup_valid, do: assigns.zip_lookup_trait.id, else: nil),
      home_zip: if(assigns.zip_lookup_valid, do: assigns.zip_lookup_input, else: nil),
      # Sets the UserProxy row via `Accounts.register_new_user/2`'s
      # `maybe_insert_proxy_user/2`; starts `active: false`. Admin
      # explicitly toggles activation from the list.
      true_user_id: admin.id
    }
  end

  # --------------------------------------------------------------------
  # Assigns init
  # --------------------------------------------------------------------

  defp init_signup_assigns(%{assigns: %{signup_initialized: true}} = socket), do: socket

  defp init_signup_assigns(socket) do
    sex_options = load_sex_options()

    socket
    |> assign(:signup_initialized, true)
    |> assign(:base_names, AliasGenerator.generate_base_names(5))
    |> assign(:available_numbers, [])
    |> assign(:selected_base, nil)
    |> assign(:selected_number, nil)
    |> assign(:alias, "")
    |> assign(:alias_error, nil)
    |> assign(:sex_options, sex_options)
    |> assign(:sex_trait_id, nil)
    |> assign(:birthdate_year, "")
    |> assign(:birthdate_month, "")
    |> assign(:birthdate_day, "")
    |> assign(:birthdate_valid, false)
    |> assign(:birthdate_error, nil)
    |> assign(:calculated_age, nil)
    |> assign(:age_trait_id, nil)
    |> assign(:confirmation_checked, false)
    # ZipCodeLookup reads `trait_in_edit.id` as the parent trait id.
    # Trait 4 is the zip-code parent trait.
    |> assign(:trait_in_edit, %{id: 4})
    |> ZipCodeLookup.initialize_zip_lookup_assigns()
  end

  defp load_sex_options do
    case Traits.get_trait_with_full_survey_data!(1) do
      {:ok, trait} ->
        Enum.map(trait.child_traits, fn child ->
          %{id: child.id, name: child.trait_name}
        end)

      _ ->
        []
    end
  end

  # --------------------------------------------------------------------
  # Validation helpers
  # --------------------------------------------------------------------

  defp validate_birthdate(socket) do
    year = socket.assigns.birthdate_year
    month = socket.assigns.birthdate_month
    day = socket.assigns.birthdate_day

    all_digits_entered =
      String.length(month) == 2 and String.length(day) == 2 and String.length(year) == 4

    with true <- String.length(year) == 4,
         {year_int, ""} <- Integer.parse(year),
         true <- String.length(month) == 2,
         {month_int, ""} <- Integer.parse(month),
         true <- month_int in 1..12,
         true <- String.length(day) == 2,
         {day_int, ""} <- Integer.parse(day),
         true <- day_int in 1..31,
         {:ok, date} <- Date.new(year_int, month_int, day_int) do
      age = MeFiles.calculate_age(date)

      if age && age >= 16 do
        age_trait = MeFiles.get_age_trait_for_age(age)

        socket
        |> assign(:birthdate_valid, true)
        |> assign(:birthdate_error, nil)
        |> assign(:calculated_age, age)
        |> assign(:age_trait_id, if(age_trait, do: age_trait.id, else: nil))
      else
        socket
        |> assign(:birthdate_valid, false)
        |> assign(:birthdate_error, "Must be 16 or older")
        |> assign(:calculated_age, age)
        |> assign(:age_trait_id, nil)
      end
    else
      _ ->
        error = if all_digits_entered, do: "Date entered is invalid", else: nil

        socket
        |> assign(:birthdate_valid, false)
        |> assign(:birthdate_error, error)
        |> assign(:calculated_age, nil)
        |> assign(:age_trait_id, nil)
    end
  end

  defp alias_ready?(assigns) do
    assigns[:alias] not in [nil, ""] and is_nil(assigns[:alias_error])
  end

  defp data_step_ready?(assigns) do
    not is_nil(assigns[:sex_trait_id]) and assigns[:birthdate_valid] and
      not is_nil(assigns[:age_trait_id]) and assigns[:zip_lookup_valid]
  end

  defp can_complete?(assigns) do
    alias_ready?(assigns) and data_step_ready?(assigns) and assigns[:confirmation_checked]
  end

  # --------------------------------------------------------------------
  # Misc helpers
  # --------------------------------------------------------------------

  # Hammer bucket key — scope by admin so two admins regenerating in
  # parallel don't share a limit. Falls back to "anon" defensively.
  defp regenerate_key(kind, socket) do
    admin_id =
      case socket.assigns do
        %{admin: %{id: id}} -> id
        _ -> "anon"
      end

    "proxy_user_sheet:regenerate_#{kind}:#{admin_id}"
  end

  # --------------------------------------------------------------------
  # Render
  # --------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} data-proxy-user-sheet="true">
      <%= if @show do %>
        <div class="fixed inset-0 z-50 flex items-end md:items-center justify-center">
          <%!-- Backdrop --%>
          <div
            id={"#{@id}-backdrop"}
            class="absolute inset-0 bg-black/60 backdrop-blur-sm"
            phx-click={@on_cancel}
          />

          <%!--
            Bottom-sheet on narrow viewports, centered dialog on md+.
            `max-h-[90vh]` + inner overflow-y-auto keeps the card bounded
            while the content scrolls.
          --%>
          <div
            class="relative w-full md:max-w-lg bg-base-100 dark:bg-base-200 rounded-t-2xl md:rounded-2xl shadow-2xl border border-base-300 overflow-hidden flex flex-col max-h-[90vh]"
            phx-window-keydown={@on_cancel}
            phx-key="escape"
          >
            <button
              type="button"
              phx-click={@on_cancel}
              class="absolute top-3 right-3 btn btn-sm btn-circle btn-ghost z-10"
              aria-label="Close"
            >
              <.icon name="hero-x-mark" class="w-5 h-5" />
            </button>

            <div class="p-6 md:p-8 overflow-y-auto">
              {render_state(assigns)}
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_state(%{state: :alias} = assigns) do
    ~H"""
    <div class="space-y-5">
      <.sheet_header subtitle="Step 1 of 3 — Build the proxy's alias" />
      <.progress step={:alias} />

      <AuthSteps.alias_picker
        alias={@alias}
        alias_error={@alias_error}
        base_names={@base_names}
        available_numbers={@available_numbers}
        selected_base={@selected_base}
        selected_number={@selected_number}
        target={@myself}
      />

      <.nav_buttons
        target={@myself}
        back_label="Cancel"
        back_click={@on_cancel}
        next_disabled={not alias_ready?(assigns)}
      />
    </div>
    """
  end

  defp render_state(%{state: :data} = assigns) do
    ~H"""
    <div class="space-y-5">
      <.sheet_header subtitle="Step 2 of 3 — Core MeFile data" />
      <.progress step={:data} />

      <AuthSteps.data_step
        sex_trait_id={@sex_trait_id}
        sex_options={@sex_options}
        birthdate_year={@birthdate_year}
        birthdate_month={@birthdate_month}
        birthdate_day={@birthdate_day}
        birthdate_valid={@birthdate_valid}
        birthdate_error={@birthdate_error}
        calculated_age={@calculated_age}
        zip_lookup_input={@zip_lookup_input}
        zip_lookup_valid={@zip_lookup_valid}
        zip_lookup_error={@zip_lookup_error}
        zip_lookup_trait={@zip_lookup_trait}
        target={@myself}
      />

      <.nav_buttons
        target={@myself}
        back_label="Back"
        next_disabled={not data_step_ready?(assigns)}
      />
    </div>
    """
  end

  defp render_state(%{state: :confirm} = assigns) do
    ~H"""
    <div class="space-y-5">
      <.sheet_header subtitle="Step 3 of 3 — Confirm" />
      <.progress step={:confirm} />

      <%= if @signup_error do %>
        <div class="alert alert-error text-sm">
          <.icon name="hero-x-circle" class="w-5 h-5" />
          <span>{@signup_error}</span>
        </div>
      <% end %>

      <AuthSteps.confirm_step
        mobile_number=""
        alias={@alias}
        sex_trait_id={@sex_trait_id}
        sex_options={@sex_options}
        birthdate_year={@birthdate_year}
        birthdate_month={@birthdate_month}
        birthdate_day={@birthdate_day}
        calculated_age={@calculated_age}
        zip_lookup_trait={@zip_lookup_trait}
        referral_code={ReferralContext.code(@referral_context) || ""}
        show_referral_code={not is_nil(@referral_context)}
        confirmation_checked={@confirmation_checked}
        can_complete={can_complete?(assigns)}
        target={@myself}
      />

      <div class="flex gap-2 pt-2">
        <button
          type="button"
          phx-click="signup_back"
          phx-target={@myself}
          class="btn btn-ghost flex-1"
        >
          Back
        </button>
        <button
          type="button"
          phx-click="submit_signup"
          phx-target={@myself}
          class="btn btn-primary flex-1"
          disabled={not can_complete?(assigns)}
        >
          Create proxy user
        </button>
      </div>
    </div>
    """
  end

  defp render_state(%{state: :creating} = assigns) do
    ~H"""
    <div class="space-y-5 text-center py-6">
      <div class="flex justify-center">
        <span class="loading loading-spinner loading-lg text-primary"></span>
      </div>
      <div>
        <h2 class="text-xl md:text-2xl font-bold dark:text-white">Creating proxy user…</h2>
        <p class="mt-1 text-sm text-base-content/70">Setting up the MeFile and wallet.</p>
      </div>
    </div>
    """
  end

  defp render_state(%{state: :complete} = assigns) do
    ~H"""
    <div class="space-y-5 text-center py-4">
      <div class="flex justify-center">
        <div class="bg-success/20 dark:bg-success/30 rounded-full p-3">
          <.icon name="hero-check-circle-solid" class="w-12 h-12 text-success" />
        </div>
      </div>

      <div>
        <h2 class="text-xl md:text-2xl font-bold dark:text-white">Proxy user created</h2>
        <p class="mt-2 text-base-content/70">
          <span class="font-medium text-primary">{@created_user && @created_user.alias}</span>
          is now in your proxy list.
        </p>
        <p class="mt-1 text-sm text-base-content/60">
          They'll appear as inactive — use the list to switch into them.
        </p>
      </div>

      <div class="flex gap-2 pt-2">
        <button
          type="button"
          phx-click={@on_cancel}
          class="btn btn-ghost flex-1"
        >
          Close
        </button>
        <button
          type="button"
          phx-click="add_another"
          phx-target={@myself}
          class="btn btn-primary flex-1"
        >
          Add another
        </button>
      </div>
    </div>
    """
  end

  # --------------------------------------------------------------------
  # Sub-components
  # --------------------------------------------------------------------

  attr :subtitle, :string, required: true

  defp sheet_header(assigns) do
    ~H"""
    <div>
      <h2 class="text-2xl md:text-3xl font-bold dark:text-white">Add a proxy user</h2>
      <p class="mt-1 text-sm md:text-base text-base-content/70">{@subtitle}</p>
    </div>
    """
  end

  attr :step, :atom, required: true, values: [:alias, :data, :confirm]

  defp progress(assigns) do
    ~H"""
    <ul class="steps w-full text-xs">
      <li class={"step step-primary"}>Alias</li>
      <li class={"step #{if @step in [:data, :confirm], do: "step-primary"}"}>Data</li>
      <li class={"step #{if @step == :confirm, do: "step-primary"}"}>Confirm</li>
    </ul>
    """
  end

  attr :target, :any, required: true
  attr :back_label, :string, default: "Back"
  attr :back_click, :any, default: nil
  attr :next_disabled, :boolean, default: false

  defp nav_buttons(assigns) do
    ~H"""
    <div class="flex gap-2 pt-2">
      <button
        type="button"
        phx-click={@back_click || JS.push("signup_back", target: @target)}
        class="btn btn-ghost flex-1"
      >
        {@back_label}
      </button>
      <button
        type="button"
        phx-click="signup_next"
        phx-target={@target}
        class="btn btn-primary flex-1"
        disabled={@next_disabled}
      >
        Next
      </button>
    </div>
    """
  end
end
