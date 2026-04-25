defmodule QlariusWeb.Components.AuthSheet do
  @moduledoc """
  Public-auth LiveComponent. Handles both **sign-in** (B2) and
  **sign-up** (B3) for anonymous visitors on a Qlink/qadabra-family
  surface, completing authentication *in place* (no page navigation)
  via the `FinalizeToken` exchange + `AuthFinalize` JS hook.

  ## State machine

      :phone            # mobile number entry
        ↓ send_code
      :code             # OTP entry (also branch back on finalize error)
        ↓ verify_code (→ carrier validation)
        ↓
        ┌─── known phone ─────── :finalizing ─── (socket reconnect) → done
        └─── unknown phone ──── :alias → :data → :confirm → :creating
                                                              ↓
                                                          :finalizing → done

  An `:iframe_hint`-driven interstitial (`render_state/1` `in_iframe:
  true`) short-circuits the whole flow and directs visitors to open
  Qadabra in a new tab, since cross-origin cookie constraints make
  in-place auth unreliable there.

  See `docs/qlink_auth_refactor_plan.md` §5.1, §5.2, §5.9.

  ## Parent-facing API

      <.live_component
        module={QlariusWeb.Components.AuthSheet}
        id="auth-sheet"
        show={@show_auth_sheet}
        surface={:on_qlink_page}
        referral_context={@referral_context}
        resume={"tip:\#{@jar_id}"}
        on_cancel={JS.push("close_auth_sheet")}
        iframe_hint={false}
      />

  The parent toggles `show` to open/close the sheet. When the user
  completes auth the browser socket reconnects and the re-mounted parent
  LV will re-render with `@current_scope.user` populated — at which point
  it should set `show={false}` (or simply stop rendering the component
  entirely) so the sheet disappears.

  ## Required assigns

    * `:id` — DOM id, used as `phx-hook` attachment point
    * `:show` — boolean; parent decides when to open

  ## Optional assigns

    * `:surface` — atom tag for telemetry (e.g. `:on_qlink_page`)
    * `:referral_context` — `%Qlarius.Referrals.Context{}` or `nil`;
      applied as the `referral_code` when a new user is created in the
      sign-up branch
    * `:resume` — opaque resume intent string (e.g. `"tip:42"`), stashed
      in session on finalize for the post-reconnect handler
    * `:iframe_hint` — server-side best-guess of iframe context; the JS
      hook corrects this on first mount
    * `:on_cancel` — `Phoenix.LiveView.JS` command forwarded on close
    * `:client_ip` — best-effort client IP string (from the parent LV's
      `GetUserIP` on_mount hook); used as the per-IP bucket key for
      `send_code` rate limiting. Defaults to `"0.0.0.0"` when the
      parent can't resolve an IP, in which case the per-IP gate is
      skipped (see `Qlarius.Auth.RateLimit`).
  """

  use QlariusWeb, :live_component

  alias Phoenix.LiveView.JS
  alias Qlarius.Accounts
  alias Qlarius.Accounts.AliasGenerator
  alias Qlarius.Auth, as: AuthCtx
  alias Qlarius.Auth.RateLimit
  alias Qlarius.Referrals.Context, as: ReferralContext
  alias Qlarius.Services.Twilio
  alias Qlarius.YouData.MeFiles
  alias Qlarius.YouData.Traits
  alias QlariusWeb.Auth.FinalizeToken
  alias QlariusWeb.Components.AuthSteps
  alias QlariusWeb.Live.Helpers.ZipCodeLookup

  require Logger

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:state, :phone)
     |> assign(:mobile_number, "")
     |> assign(:mobile_number_error, nil)
     |> assign(:verification_code, "")
     |> assign(:verification_code_error, nil)
     |> assign(:finalize_error, nil)
     |> assign(:signup_error, nil)
     |> assign(:in_iframe, false)
     |> assign(:signup_initialized, false)
     |> assign(:carrier_info, nil)}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(:id, assigns.id)
      |> assign(:show, Map.get(assigns, :show, false))
      |> assign(:surface, Map.get(assigns, :surface))
      |> assign(:referral_context, Map.get(assigns, :referral_context))
      |> assign(:resume, Map.get(assigns, :resume))
      |> assign(:on_cancel, Map.get(assigns, :on_cancel, %JS{}))
      |> assign(:client_ip, Map.get(assigns, :client_ip, "0.0.0.0"))
      |> maybe_apply_iframe_hint(Map.get(assigns, :iframe_hint))

    {:ok, socket}
  end

  # Apply the server-side iframe heuristic once, before the JS hook has
  # had a chance to confirm. We don't want to overwrite a later JS
  # confirmation, so only apply on the very first `update/2`.
  defp maybe_apply_iframe_hint(%{assigns: %{iframe_hint_applied: true}} = socket, _hint),
    do: socket

  defp maybe_apply_iframe_hint(socket, hint) when is_boolean(hint) do
    socket
    |> assign(:in_iframe, hint)
    |> assign(:iframe_hint_applied, true)
  end

  defp maybe_apply_iframe_hint(socket, _hint),
    do: assign(socket, :iframe_hint_applied, true)

  # --------------------------------------------------------------------
  # Phone / OTP events (sign-in and sign-up share these)
  # --------------------------------------------------------------------

  @impl true
  def handle_event("iframe-status", %{"in_iframe" => in_iframe}, socket) do
    {:noreply, assign(socket, :in_iframe, !!in_iframe)}
  end

  def handle_event("update_mobile", %{"value" => mobile}, socket) do
    {:noreply,
     socket
     |> assign(:mobile_number, mobile)
     |> assign(:mobile_number_error, nil)}
  end

  def handle_event("send_code", _params, socket) do
    phone = socket.assigns.mobile_number
    formatted = format_phone(phone)

    cond do
      not valid_phone_shape?(phone) ->
        {:noreply, assign(socket, :mobile_number_error, "Enter a valid 10-digit number.")}

      true ->
        # Order matters: check per-phone first so we don't leak IP-bucket
        # state to users who can't even pass the phone gate, and so a
        # single abusive IP burning through the IP bucket still trips
        # the per-phone limit for attempted victims.
        with :ok <- RateLimit.check_send_code_per_phone(formatted),
             :ok <- RateLimit.check_send_code_per_ip(socket.assigns.client_ip) do
          # B3 change: no longer short-circuit on "unknown phone here" —
          # we send the code regardless so we can still verify ownership
          # before branching into sign-up. `verify_code/1` now owns the
          # sign-in-vs-sign-up decision.
          dispatch_send_code(socket, formatted)
        else
          {:error, {:rate_limited, retry_after_s}} ->
            Logger.info(
              "[AuthSheet] send_code rate-limited phone=#{mask_phone(formatted)} surface=#{inspect(socket.assigns.surface)}"
            )

            {:noreply,
             assign(
               socket,
               :mobile_number_error,
               "Too many attempts. Try again in about #{humanize_retry_after(retry_after_s)}."
             )}
        end
    end
  end

  def handle_event("update_verification_code", %{"verification_code" => code}, socket) do
    {:noreply,
     socket
     |> assign(:verification_code, code)
     |> assign(:verification_code_error, nil)}
  end

  def handle_event("verify_code", %{"code" => code}, socket) do
    verify(assign(socket, :verification_code, code))
  end

  def handle_event("verify_code", _params, socket), do: verify(socket)

  def handle_event("back_to_phone", _params, socket) do
    {:noreply,
     socket
     |> assign(:state, :phone)
     |> assign(:verification_code, "")
     |> assign(:verification_code_error, nil)
     |> assign(:finalize_error, nil)}
  end

  def handle_event("retry_finalize", _params, socket) do
    verify(socket)
  end

  def handle_event("auth:finalize_failed", %{"reason" => reason}, socket) do
    Logger.warning("[AuthSheet] finalize failed reason=#{inspect(reason)}")

    message =
      case reason do
        "rate_limited" ->
          "Too many sign-in attempts from this device. Try again in about an hour."

        _ ->
          "Something went wrong finishing sign-in. Try again."
      end

    {:noreply,
     socket
     |> assign(:state, :code)
     |> assign(:finalize_error, message)}
  end

  def handle_event("auth:finalize_failed", _params, socket) do
    handle_event("auth:finalize_failed", %{"reason" => "unknown"}, socket)
  end

  # --------------------------------------------------------------------
  # Sign-up events (B3). These are only reachable after `verify_code/1`
  # promotes an unknown-phone visitor into `:alias`, so the heavy sign-up
  # assigns (trait lookups, alias generator output) are guaranteed to be
  # present via `init_signup_assigns/1`.
  # --------------------------------------------------------------------

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

  def handle_event("toggle_confirmation", %{"checked" => checked}, socket) do
    {:noreply, assign(socket, :confirmation_checked, checked == "true")}
  end

  # Linear next/back through the sign-up steps. We deliberately keep a
  # flat state machine (no `:current_step` index) — each transition is
  # guarded by `can_advance?/1` so buttons only enable once the current
  # step is complete.
  def handle_event("signup_next", _params, socket) do
    {:noreply, advance_signup(socket)}
  end

  def handle_event("signup_back", _params, socket) do
    {:noreply, retreat_signup(socket)}
  end

  def handle_event("submit_signup", _params, socket) do
    if can_complete?(socket.assigns) do
      create_user_and_finalize(socket)
    else
      {:noreply, assign(socket, :signup_error, "Please complete all required fields.")}
    end
  end

  # --------------------------------------------------------------------
  # Sign-in / sign-up decision and post-verify flow
  # --------------------------------------------------------------------

  defp verify(socket) do
    phone = socket.assigns.mobile_number
    code = socket.assigns.verification_code
    formatted = format_phone(phone)
    bypass = Application.get_env(:qlarius, :bypass_phone_verification, false)

    otp_result =
      if bypass and code == "000000" do
        {:ok, :verified}
      else
        Twilio.verify_code(formatted, code)
      end

    case otp_result do
      {:ok, :verified} ->
        handle_verified(socket, formatted, bypass)

      {:error, _reason} ->
        {:noreply,
         socket
         |> assign(:verification_code, "")
         |> assign(:verification_code_error, "Invalid code — try again.")}
    end
  end

  # After OTP success we run carrier validation (same contract as
  # `RegistrationLive`), then branch sign-in vs sign-up on whether the
  # phone is attached to an existing user.
  defp handle_verified(socket, formatted_phone, true = _bypass) do
    # Mirror RegistrationLive's dev-mode fake carrier info so downstream
    # logic (which expects a map) doesn't need a separate branch.
    carrier_info = %{
      type: "mobile",
      valid: true,
      country_code: "US",
      carrier_name: "[DEV MODE]",
      error_code: nil
    }

    branch_on_user(socket, formatted_phone, carrier_info)
  end

  defp handle_verified(socket, formatted_phone, false = _bypass) do
    case Twilio.validate_carrier(formatted_phone) do
      {:ok, carrier_info} ->
        branch_on_user(socket, formatted_phone, carrier_info)

      {:error, _reason, message} ->
        {:noreply,
         socket
         |> assign(:verification_code, "")
         |> assign(:verification_code_error, message)}
    end
  end

  defp branch_on_user(socket, formatted_phone, carrier_info) do
    socket = assign(socket, :carrier_info, carrier_info)

    case AuthCtx.get_user_by_phone(formatted_phone) do
      nil ->
        # Unknown phone → sign-up. Lazy-init the heavy assigns now.
        {:noreply,
         socket
         |> init_signup_assigns()
         |> assign(:state, :alias)
         |> assign(:verification_code_error, nil)
         |> assign(:finalize_error, nil)}

      user ->
        finalize_for_user(socket, user)
    end
  end

  defp finalize_for_user(socket, user) do
    token =
      FinalizeToken.sign(%{
        user_id: user.id,
        resume: socket.assigns.resume,
        surface: surface_to_string(socket.assigns.surface)
      })

    {:noreply,
     socket
     |> assign(:state, :finalizing)
     |> assign(:verification_code_error, nil)
     |> assign(:finalize_error, nil)
     |> assign(:signup_error, nil)
     |> push_event("qadabra:finalize-auth", %{token: token})}
  end

  # --------------------------------------------------------------------
  # Sign-up step progression
  # --------------------------------------------------------------------

  defp advance_signup(%{assigns: %{state: :alias}} = socket) do
    if alias_ready?(socket.assigns) do
      assign(socket, :state, :data)
    else
      assign(socket, :alias_error, "Pick a name and number to build your alias.")
    end
  end

  defp advance_signup(%{assigns: %{state: :data}} = socket) do
    if data_step_ready?(socket.assigns) do
      assign(socket, :state, :confirm)
    else
      assign(socket, :signup_error, "Fill in birthdate, sex, and a valid zip code.")
    end
  end

  defp advance_signup(socket), do: socket

  defp retreat_signup(%{assigns: %{state: :data}} = socket),
    do: assign(socket, :state, :alias)

  defp retreat_signup(%{assigns: %{state: :confirm}} = socket),
    do: assign(socket, :state, :data)

  defp retreat_signup(%{assigns: %{state: :alias}} = socket),
    do: assign(socket, :state, :code)

  defp retreat_signup(socket), do: socket

  # --------------------------------------------------------------------
  # User creation + in-place finalize
  # --------------------------------------------------------------------

  defp create_user_and_finalize(socket) do
    socket = assign(socket, :state, :creating)

    attrs = build_user_attrs(socket.assigns)
    referral_code = ReferralContext.code(socket.assigns.referral_context)

    case Accounts.register_new_user(attrs, referral_code) do
      {:ok, %{user: user}} ->
        Logger.info(
          "[AuthSheet] created user id=#{user.id} alias=#{user.alias} " <>
            "referral_source=#{inspect(ReferralContext.source(socket.assigns.referral_context))}"
        )

        finalize_for_user(socket, user)

      {:error, failed_step, failed_value, _changes_so_far} ->
        Logger.warning(
          "[AuthSheet] registration failed step=#{inspect(failed_step)} " <>
            "value=#{inspect(failed_value)}"
        )

        {:noreply,
         socket
         |> assign(:state, :confirm)
         |> assign(:signup_error, "We couldn't complete registration. Please double-check your details and try again.")}
    end
  end

  defp build_user_attrs(assigns) do
    date =
      Date.new!(
        String.to_integer(assigns.birthdate_year),
        String.to_integer(assigns.birthdate_month),
        String.to_integer(assigns.birthdate_day)
      )

    mobile_number =
      case assigns.mobile_number do
        "" -> nil
        phone when is_binary(phone) -> phone
        _ -> nil
      end

    %{
      alias: assigns.alias,
      mobile_number: mobile_number,
      role: "user",
      date_of_birth: date,
      sex_trait_id: assigns.sex_trait_id,
      age_trait_id: assigns.age_trait_id,
      zip_code_trait_id: if(assigns.zip_lookup_valid, do: assigns.zip_lookup_trait.id, else: nil),
      home_zip: if(assigns.zip_lookup_valid, do: assigns.zip_lookup_input, else: nil)
    }
  end

  # --------------------------------------------------------------------
  # Sign-up assigns init
  # --------------------------------------------------------------------

  # Loads trait data + alias candidates the first time the sign-up flow
  # is entered. Skipped if already initialized (e.g. the visitor bounced
  # back to `:code` and re-verified).
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
    # Trait 4 is the zip-code parent trait; see `RegistrationLive`.
    |> assign(:trait_in_edit, %{id: 4})
    |> ZipCodeLookup.initialize_zip_lookup_assigns()
  end

  # Trait id `1` is the parent "sex" trait. We surface its children as
  # `%{id, name}` for `AuthSteps.data_step`/`confirm_step`. Mirrors
  # `RegistrationLive.load_sex_options/0`.
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

  defp dispatch_send_code(socket, formatted_phone) do
    bypass = Application.get_env(:qlarius, :bypass_phone_verification, false)

    if bypass do
      {:noreply,
       socket
       |> assign(:state, :code)
       |> assign(:mobile_number_error, nil)
       |> assign(:verification_code, "")}
    else
      case Twilio.send_verification_code(formatted_phone) do
        {:ok, _resp} ->
          {:noreply,
           socket
           |> assign(:state, :code)
           |> assign(:mobile_number_error, nil)
           |> assign(:verification_code, "")}

        {:error, _reason} ->
          {:noreply,
           assign(socket, :mobile_number_error, "Couldn't send code. Try again.")}
      end
    end
  end

  # Hammer rate-limit key per-phone per-kind. Falls back to the
  # component DOM id when the visitor hasn't yet entered a phone (which
  # shouldn't happen since they've already verified OTP by the time they
  # can regenerate, but defensive in any case).
  defp regenerate_key(kind, socket) do
    phone =
      case socket.assigns[:mobile_number] do
        phone when is_binary(phone) and phone != "" -> phone
        _ -> socket.assigns.id
      end

    "auth_sheet_regenerate_#{kind}:#{phone}"
  end

  defp format_phone(nil), do: ""
  defp format_phone("+" <> _ = p), do: p
  defp format_phone(p) when is_binary(p), do: "+1" <> String.replace(p, ~r/\D/, "")
  defp format_phone(_), do: ""

  # Log helper: we don't want full phone numbers in log aggregates but
  # do want enough to correlate a rate-limit hit with a support report.
  defp mask_phone("+" <> rest), do: "+" <> mask_phone(rest)

  defp mask_phone(phone) when is_binary(phone) do
    digits = String.replace(phone, ~r/\D/, "")

    case String.length(digits) do
      n when n >= 4 -> String.duplicate("*", n - 4) <> String.slice(digits, -4, 4)
      _ -> String.duplicate("*", String.length(digits))
    end
  end

  defp mask_phone(_), do: "****"

  defp humanize_retry_after(seconds) when seconds <= 90, do: "a minute"
  defp humanize_retry_after(seconds) when seconds < 60 * 60, do: "#{div(seconds, 60)} minutes"
  defp humanize_retry_after(_), do: "an hour"

  defp valid_phone_shape?(nil), do: false

  defp valid_phone_shape?(phone) when is_binary(phone) do
    digits = String.replace(phone, ~r/\D/, "")
    byte_size(digits) in 10..15
  end

  defp valid_phone_shape?(_), do: false

  defp surface_to_string(nil), do: nil
  defp surface_to_string(atom) when is_atom(atom), do: Atom.to_string(atom)
  defp surface_to_string(str) when is_binary(str), do: str
  defp surface_to_string(_), do: nil

  defp register_url, do: "https://qadabra.app/register"

  # --------------------------------------------------------------------
  # Render
  # --------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook="AuthFinalize"
      data-auth-sheet="true"
    >
      <%= if @show do %>
        <div
          id={"#{@id}-iframe-probe"}
          phx-hook="IframeDetect"
          phx-target={@myself}
          class="hidden"
        />

        <div class="fixed inset-0 z-50 flex items-end md:items-center justify-center">
          <%!-- Backdrop --%>
          <div
            id={"#{@id}-backdrop"}
            class="absolute inset-0 bg-black/60 backdrop-blur-sm"
            phx-click={@on_cancel}
          />

          <%!--
            Sheet / modal card. Bottom-sheet on narrow viewports so the
            long sign-up steps have room to scroll; centered dialog on
            md+. `max-h-[90vh]` + inner `overflow-y-auto` keeps the
            card itself bounded to the viewport while the content scrolls.
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

  # Switch off the current component state. Each branch is an independent
  # render fragment; we deliberately avoid `<.live_component>` nesting
  # so the sheet stays one atomic component.
  defp render_state(%{in_iframe: true} = assigns) do
    ~H"""
    <div class="space-y-5 text-center">
      <div>
        <h2 class="text-2xl font-bold dark:text-white">Open Qadabra to sign in</h2>
        <p class="mt-2 text-base-content/70">
          This widget is embedded, so we need to open Qadabra in a new tab to finish signing you in.
        </p>
      </div>

      <a
        href="https://qadabra.app/login"
        target="_blank"
        rel="noopener"
        class="btn btn-primary w-full"
      >
        <.icon name="hero-arrow-top-right-on-square" class="w-4 h-4" /> Sign in at qadabra.app
      </a>

      <p class="text-xs text-base-content/60">
        New to Qadabra?
        <a href={register_url()} target="_blank" rel="noopener" class="link link-primary">
          Create an account
        </a>
      </p>
    </div>
    """
  end

  defp render_state(%{state: :phone} = assigns) do
    ~H"""
    <div class="space-y-5">
      <div>
        <h2 class="text-2xl md:text-3xl font-bold dark:text-white">Sign in or sign up</h2>
        <p class="mt-1 text-sm md:text-base text-base-content/70">
          Enter your mobile number and we'll text you a 6-digit code. We'll
          take you through a quick sign-up if you don't have an account yet.
        </p>
      </div>

      <.form
        for={%{}}
        phx-change="update_mobile"
        phx-submit="send_code"
        phx-target={@myself}
        autocomplete="off"
        class="space-y-4"
      >
        <div class="form-control w-full">
          <label class="label pb-1">
            <span class="label-text text-sm font-medium dark:text-gray-300">Mobile number</span>
          </label>
          <input
            type="tel"
            name="value"
            value={@mobile_number}
            inputmode="numeric"
            autocomplete="tel"
            placeholder="(555) 555-5555"
            class="input input-bordered w-full"
            aria-invalid={if @mobile_number_error, do: "true"}
          />
          <%= if @mobile_number_error do %>
            <p class="mt-2 text-sm text-error">{@mobile_number_error}</p>
          <% end %>
        </div>

        <button
          type="submit"
          class="btn btn-primary w-full"
          disabled={not valid_phone_shape?(@mobile_number)}
        >
          Send code
        </button>
      </.form>
    </div>
    """
  end

  defp render_state(%{state: :code} = assigns) do
    ~H"""
    <div class="space-y-5">
      <div>
        <h2 class="text-2xl md:text-3xl font-bold dark:text-white">Enter your code</h2>
        <p class="mt-1 text-sm md:text-base text-base-content/70">
          We sent a 6-digit code to <span class="font-medium">{@mobile_number}</span>.
        </p>
      </div>

      <%= if @finalize_error do %>
        <div class="alert alert-warning text-sm">
          <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
          <span>{@finalize_error}</span>
        </div>
      <% end %>

      <QlariusWeb.Components.CustomComponentsMobile.otp_input
        id={"#{@id}-otp"}
        value={@verification_code}
        error={@verification_code_error}
        verify_event="verify_code"
        update_event="update_verification_code"
      />

      <div class="flex items-center justify-between text-sm">
        <button
          type="button"
          phx-click="back_to_phone"
          phx-target={@myself}
          class="link link-hover"
        >
          Use a different number
        </button>

        <button
          type="button"
          phx-click="send_code"
          phx-target={@myself}
          class="link link-hover"
        >
          Resend code
        </button>
      </div>
    </div>
    """
  end

  defp render_state(%{state: :finalizing} = assigns) do
    ~H"""
    <div class="space-y-5 text-center py-6">
      <div class="flex justify-center">
        <span class="loading loading-spinner loading-lg text-primary"></span>
      </div>
      <div>
        <h2 class="text-xl md:text-2xl font-bold dark:text-white">Signing you in…</h2>
        <p class="mt-1 text-sm text-base-content/70">Hang tight, this only takes a second.</p>
      </div>
    </div>
    """
  end

  defp render_state(%{state: :alias} = assigns) do
    ~H"""
    <div class="space-y-5">
      <.signup_progress step={:alias} />

      <AuthSteps.alias_picker
        alias={@alias}
        alias_error={@alias_error}
        base_names={@base_names}
        available_numbers={@available_numbers}
        selected_base={@selected_base}
        selected_number={@selected_number}
        target={@myself}
      />

      <.signup_nav
        target={@myself}
        back_label="Use a different number"
        next_disabled={not alias_ready?(assigns)}
      />
    </div>
    """
  end

  defp render_state(%{state: :data} = assigns) do
    ~H"""
    <div class="space-y-5">
      <.signup_progress step={:data} />

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

      <.signup_nav
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
      <.signup_progress step={:confirm} />

      <%= if @signup_error do %>
        <div class="alert alert-error text-sm">
          <.icon name="hero-x-circle" class="w-5 h-5" />
          <span>{@signup_error}</span>
        </div>
      <% end %>

      <AuthSteps.confirm_step
        mobile_number={@mobile_number}
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
          Create account
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
        <h2 class="text-xl md:text-2xl font-bold dark:text-white">Creating your account…</h2>
        <p class="mt-1 text-sm text-base-content/70">Setting up your MeFile and wallet.</p>
      </div>
    </div>
    """
  end

  # --------------------------------------------------------------------
  # Sub-components: progress bar + nav
  # --------------------------------------------------------------------

  attr :step, :atom, required: true, values: [:alias, :data, :confirm]

  defp signup_progress(assigns) do
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
  attr :next_disabled, :boolean, default: false

  defp signup_nav(assigns) do
    ~H"""
    <div class="flex gap-2 pt-2">
      <button
        type="button"
        phx-click="signup_back"
        phx-target={@target}
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
