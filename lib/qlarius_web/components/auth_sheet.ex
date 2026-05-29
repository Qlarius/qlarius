defmodule QlariusWeb.Components.AuthSheet do
  @moduledoc """
  Public-auth LiveComponent. Handles both **sign-in** (B2) and
  **sign-up** (B3) for anonymous visitors on a Qlink/qadabra-family
  surface, completing authentication *in place* (no page navigation)
  via the `FinalizeToken` exchange + `AuthFinalize` JS hook.

  ## State machine

      :phone            # mobile number entry
        ↓ send_code (may Twilio-gate unknown phones before SMS when filter on)
        ├─ fails gate ─── :carrier_rejected (optional durable block replay)
        └─ passes ───── :code
      :code             # OTP entry (also branch back on finalize error)
        ↓ verify_code (→ carrier validation unless pre-checked at send_code)
        ↓
        ┌─── known phone ─────── :finalizing ─── (socket reconnect) → done
        └─── unknown phone ──── :signup_intro → :alias → :data → :confirm → :creating
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
    * `:connect_brand` — `:qadabra` | `:sponster` | `:tiqit`; selects the
      header logo on the `:phone` and `:code` steps only (defaults to
      `:qadabra`). Does not change the sign-up intro pane.
  """

  use QlariusWeb, :live_component

  alias Phoenix.LiveView.JS
  alias Qlarius.Accounts
  alias Qlarius.Accounts.AliasGenerator
  alias Qlarius.Auth, as: AuthCtx
  alias Qlarius.Auth.AuditLog
  alias Qlarius.Auth.PhoneCarrierRejection
  alias Qlarius.Auth.PhoneCarrierRejections
  alias Qlarius.Auth.RateLimit
  alias Qlarius.Referrals.Context, as: ReferralContext
  alias Qlarius.Services.Twilio
  alias Qlarius.YouData.Traits
  alias QlariusWeb.Auth.FinalizeToken
  alias QlariusWeb.Components.AuthSteps
  alias QlariusWeb.Live.Helpers.ZipCodeLookup

  # Time to keep the overlay mounted after the parent sets `show: false`,
  # so backdrop + panel exit animations can finish before unmounting.
  @auth_sheet_exit_ms 360

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
     |> assign(:carrier_info, nil)
     |> assign(:pending_carrier_info, nil)
     |> assign(:carrier_rejection_message, nil)
     |> assign(:modal_overlay_visible, false)
     |> assign(:modal_exiting, false)
     |> assign(:exit_timer_ref, nil)}
  end

  @impl true
  def update(assigns, socket) do
    exit_done? = Map.get(assigns, :__auth_sheet_exit_done__) == true

    parent_show =
      case Map.fetch(assigns, :show) do
        {:ok, v} -> !!v
        :error -> if exit_done?, do: !!socket.assigns[:show], else: false
      end

    was_overlay_visible = socket.assigns[:modal_overlay_visible] == true
    was_exiting = socket.assigns[:modal_exiting] == true

    # Parent often resets `connect_brand` to :qadabra in the same patch as
    # `show: false` while we keep the overlay mounted for the exit animation.
    # Ignore that reset until the overlay is fully dismissed so the header
    # logo does not flash back to Qadabra mid-close.
    #
    # Note: LiveView still re-renders this component on every patch; stable
    # `connect_brand` only keeps assigns consistent. A separate visual "pop"
    # came from swapping panel enter/exit keyframes that used `scale()` —
    # see `app.css` (translateY + opacity only).
    preserve_connect_brand? =
      not parent_show && (was_overlay_visible || was_exiting)

    connect_brand =
      if preserve_connect_brand? do
        socket.assigns[:connect_brand] || :qadabra
      else
        normalize_connect_brand(Map.get(assigns, :connect_brand, socket.assigns[:connect_brand]))
      end

    socket =
      socket
      |> assign(:id, assigns.id)
      |> assign(:show, parent_show)
      |> assign(:surface, Map.get(assigns, :surface, socket.assigns[:surface]))
      |> assign(
        :referral_context,
        Map.get(assigns, :referral_context, socket.assigns[:referral_context])
      )
      |> assign(:resume, Map.get(assigns, :resume, socket.assigns[:resume]))
      |> assign(:on_cancel, Map.get(assigns, :on_cancel, socket.assigns[:on_cancel]) || %JS{})
      |> assign(:client_ip, Map.get(assigns, :client_ip, socket.assigns[:client_ip]) || "0.0.0.0")
      |> assign(:connect_brand, connect_brand)
      |> maybe_apply_iframe_hint(Map.get(assigns, :iframe_hint, :not_provided))

    socket =
      cond do
        exit_done? && parent_show ->
          socket
          |> cancel_auth_sheet_exit_timer()
          |> assign(:modal_exiting, false)
          |> assign(:modal_overlay_visible, true)

        exit_done? ->
          socket
          |> cancel_auth_sheet_exit_timer()
          |> assign(:modal_overlay_visible, false)
          |> assign(:modal_exiting, false)

        parent_show ->
          socket
          |> cancel_auth_sheet_exit_timer()
          |> assign(:modal_overlay_visible, true)
          |> assign(:modal_exiting, false)

        was_overlay_visible && not parent_show && socket.assigns[:modal_exiting] != true ->
          ref =
            Phoenix.LiveView.send_update_after(
              self(),
              __MODULE__,
              [
                id: socket.assigns.id,
                __auth_sheet_exit_done__: true,
                connect_brand: socket.assigns[:connect_brand] || :qadabra
              ],
              @auth_sheet_exit_ms
            )

          socket
          |> cancel_auth_sheet_exit_timer()
          |> assign(:exit_timer_ref, ref)
          |> assign(:modal_exiting, true)

        was_overlay_visible && not parent_show ->
          socket

        true ->
          socket
          |> cancel_auth_sheet_exit_timer()
          |> assign(:modal_overlay_visible, false)
          |> assign(:modal_exiting, false)
      end

    {:ok, socket}
  end

  defp cancel_auth_sheet_exit_timer(socket) do
    case socket.assigns[:exit_timer_ref] do
      ref when is_reference(ref) ->
        Process.cancel_timer(ref)
        assign(socket, :exit_timer_ref, nil)

      _ ->
        assign(socket, :exit_timer_ref, nil)
    end
  end

  defp normalize_connect_brand(nil), do: :qadabra

  defp normalize_connect_brand(b) when b in [:qadabra, :sponster, :tiqit], do: b

  defp normalize_connect_brand(b) when is_binary(b) do
    case String.downcase(String.trim(b)) do
      "sponster" -> :sponster
      "tiqit" -> :tiqit
      "qadabra" -> :qadabra
      _ -> :qadabra
    end
  end

  defp normalize_connect_brand(_), do: :qadabra

  defp connect_brand_header_logo(:sponster) do
    %{
      src: "/images/Sponster_logo_color_horiz.svg",
      alt: "Sponster",
      class: "h-9 w-auto max-w-[min(18rem,88vw)] object-contain md:h-11"
    }
  end

  defp connect_brand_header_logo(:tiqit) do
    %{
      src: "/images/Tiqit_logo_color_horiz.svg",
      alt: "Tiqit",
      class: "h-9 w-auto max-w-[min(18rem,88vw)] object-contain md:h-11"
    }
  end

  defp connect_brand_header_logo(_) do
    %{
      src: "/images/qadabra_full_gray_opt.svg",
      alt: "Qadabra",
      class: "h-10 w-auto max-w-[min(20rem,88vw)] object-contain md:h-11"
    }
  end

  # Apply the server-side iframe heuristic once, before the JS hook has
  # had a chance to confirm. We don't want to overwrite a later JS
  # confirmation, so only apply on the very first `update/2`.
  defp maybe_apply_iframe_hint(%{assigns: %{iframe_hint_applied: true}} = socket, _hint),
    do: socket

  defp maybe_apply_iframe_hint(socket, :not_provided), do: socket

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

  def handle_event("update_mobile", params, socket) do
    raw = Map.get(params, "value", "") || ""

    {:noreply,
     socket
     |> assign(:mobile_number, AuthSteps.format_phone_number(to_string(raw)))
     |> assign(:mobile_number_error, nil)}
  end

  def handle_event("send_code", _params, socket) do
    phone = socket.assigns.mobile_number
    formatted = format_phone(phone)
    ip = socket.assigns.client_ip
    surface = socket.assigns.surface

    cond do
      not valid_phone_shape?(phone) ->
        AuditLog.log(:"send_code.denied", %{
          phone: formatted,
          ip: ip,
          surface: surface,
          reason: :invalid_phone
        })

        {:noreply, assign(socket, :mobile_number_error, "Enter a valid 10-digit number.")}

      true ->
        # Order matters: check per-phone first so we don't leak IP-bucket
        # state to users who can't even pass the phone gate, and so a
        # single abusive IP burning through the IP bucket still trips
        # the per-phone limit for attempted victims.
        case rate_check_send_code(formatted, ip) do
          :ok ->
            maybe_gate_send_code(socket, formatted)

          {:denied, reason, retry_after_s} ->
            AuditLog.log(:"send_code.denied", %{
              phone: formatted,
              ip: ip,
              surface: surface,
              reason: reason,
              retry_after_s: retry_after_s
            })

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
    digits =
      (socket.assigns.mobile_number || "")
      |> String.replace(~r/\D/, "")
      |> String.slice(0, 10)

    {:noreply,
     socket
     |> assign(:state, :phone)
     |> assign(:mobile_number, AuthSteps.format_phone_number(digits))
     |> assign(:verification_code, "")
     |> assign(:verification_code_error, nil)
     |> assign(:finalize_error, nil)
     |> assign(:pending_carrier_info, nil)
     |> assign(:carrier_rejection_message, nil)}
  end

  def handle_event("retry_finalize", _params, socket) do
    verify(socket)
  end

  def handle_event("auth:finalize_failed", %{"reason" => reason}, socket) do
    # Client-reported failure. The controller already logged the
    # server-side decision; this line captures how the hook
    # classified it (useful for correlating, e.g., "rate_limited"
    # reported here vs. 429 responses in the controller log).
    AuditLog.log(:"finalize_session.denied", %{
      ip: socket.assigns.client_ip,
      surface: socket.assigns.surface,
      reason: classify_finalize_reason(reason),
      source: :client_hook
    })

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
  # promotes an unknown-phone visitor into `:signup_intro` then `:alias`, so the heavy sign-up
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
             |> assign(
               :available_numbers,
               AliasGenerator.generate_available_numbers(base_name, 5)
             )
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

  def handle_event("toggle_legal_confirmation", %{"checked" => checked}, socket) do
    {:noreply, assign(socket, :legal_confirmation_checked, checked == "true")}
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

  def handle_event("signup_intro_continue", _params, socket) do
    {:noreply, assign(socket, :state, :alias)}
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
        AuditLog.log(:"verify_code.denied", %{
          phone: formatted,
          ip: socket.assigns.client_ip,
          surface: socket.assigns.surface,
          reason: :incorrect_code
        })

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
    case socket.assigns[:pending_carrier_info] do
      %{} = carrier_info ->
        socket
        |> assign(:pending_carrier_info, nil)
        |> branch_on_user(formatted_phone, carrier_info)

      _ ->
        case Twilio.validate_carrier(formatted_phone) do
          {:ok, carrier_info} ->
            branch_on_user(socket, formatted_phone, carrier_info)

          {:error, reason, message} ->
            AuditLog.log(:"verify_code.denied", %{
              phone: formatted_phone,
              ip: socket.assigns.client_ip,
              surface: socket.assigns.surface,
              reason: reason
            })

            {:noreply,
             socket
             |> assign(:verification_code, "")
             |> assign(:verification_code_error, message)}
        end
    end
  end

  defp branch_on_user(socket, formatted_phone, carrier_info) do
    socket = assign(socket, :carrier_info, carrier_info)
    ip = socket.assigns.client_ip
    surface = socket.assigns.surface

    case AuthCtx.get_user_by_phone(formatted_phone) do
      nil ->
        AuditLog.log(:"verify_code.allowed", %{
          phone: formatted_phone,
          ip: ip,
          surface: surface,
          outcome: :new_user_branch
        })

        # Unknown phone → sign-up. Lazy-init the heavy assigns now.
        {:noreply,
         socket
         |> init_signup_assigns()
         |> assign(:state, :signup_intro)
         |> assign(:verification_code_error, nil)
         |> assign(:finalize_error, nil)}

      user ->
        AuditLog.log(:"verify_code.allowed", %{
          phone: formatted_phone,
          ip: ip,
          surface: surface,
          outcome: :signed_in,
          user_id: user.id
        })

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

  defp retreat_signup(%{assigns: %{state: :signup_intro}} = socket),
    do: assign(socket, :state, :code)

  defp retreat_signup(socket), do: socket

  # --------------------------------------------------------------------
  # User creation + in-place finalize
  # --------------------------------------------------------------------

  defp create_user_and_finalize(socket) do
    socket = assign(socket, :state, :creating)

    attrs = build_user_attrs(socket.assigns)
    referral_code = ReferralContext.code(socket.assigns.referral_context)
    ip = socket.assigns.client_ip
    surface = socket.assigns.surface

    case Accounts.register_new_user(attrs, referral_code) do
      {:ok, %{user: user}} ->
        AuditLog.log(:"register_new_user.allowed", %{
          user_id: user.id,
          alias: user.alias,
          ip: ip,
          surface: surface,
          referral_source: ReferralContext.source(socket.assigns.referral_context)
        })

        finalize_for_user(socket, user)

      {:error, failed_step, _failed_value, _changes_so_far} ->
        # Intentionally NOT logging `failed_value` — it may contain
        # the raw changeset with the submitted phone / zip / etc.
        # `failed_step` is enough to aggregate on.
        AuditLog.log(:"register_new_user.denied", %{
          phone: socket.assigns.mobile_number,
          ip: ip,
          surface: surface,
          failed_step: failed_step
        })

        {:noreply,
         socket
         |> assign(:state, :confirm)
         |> assign(
           :signup_error,
           "We couldn't complete registration. Please double-check your details and try again."
         )}
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
        phone when is_binary(phone) -> format_phone(phone)
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
    |> assign(:legal_confirmation_checked, false)
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

    case QlariusWeb.BirthdateRules.evaluate(year, month, day) do
      {:ok, age, age_trait_id} ->
        socket
        |> assign(:birthdate_valid, true)
        |> assign(:birthdate_error, nil)
        |> assign(:calculated_age, age)
        |> assign(:age_trait_id, age_trait_id)

      {:error, err, age} ->
        socket
        |> assign(:birthdate_valid, false)
        |> assign(:birthdate_error, err)
        |> assign(:calculated_age, age)
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
    alias_ready?(assigns) and data_step_ready?(assigns) and assigns[:confirmation_checked] and
      assigns[:legal_confirmation_checked]
  end

  # --------------------------------------------------------------------
  # Misc helpers
  # --------------------------------------------------------------------

  defp dispatch_send_code(socket, formatted_phone) do
    bypass = Application.get_env(:qlarius, :bypass_phone_verification, false)
    ip = socket.assigns.client_ip
    surface = socket.assigns.surface

    allowed_reply =
      {:noreply,
       socket
       |> assign(:state, :code)
       |> assign(:mobile_number_error, nil)
       |> assign(:verification_code, "")}

    if bypass do
      AuditLog.log(:"send_code.allowed", %{
        phone: formatted_phone,
        ip: ip,
        surface: surface,
        bypass: true
      })

      allowed_reply
    else
      case Twilio.send_verification_code(formatted_phone) do
        {:ok, _resp} ->
          AuditLog.log(:"send_code.allowed", %{
            phone: formatted_phone,
            ip: ip,
            surface: surface
          })

          allowed_reply

        {:error, _reason} ->
          AuditLog.log(:"send_code.denied", %{
            phone: formatted_phone,
            ip: ip,
            surface: surface,
            reason: :twilio_error
          })

          {:noreply,
           socket
           |> assign(:mobile_number_error, "Couldn't send code. Try again.")
           |> assign(:pending_carrier_info, nil)}
      end
    end
  end

  defp maybe_gate_send_code(socket, formatted_phone) do
    if Twilio.carrier_gate_enforced?() do
      gate_unknown_phone_send(socket, formatted_phone)
    else
      dispatch_send_code(socket, formatted_phone)
    end
  end

  defp gate_unknown_phone_send(socket, formatted_phone) do
    case PhoneCarrierRejections.active_block_for_phone(formatted_phone) do
      %PhoneCarrierRejection{user_message: msg} ->
        message =
          if msg in [nil, ""],
            do: default_carrier_rejection_user_message(),
            else: msg

        {:noreply,
         socket
         |> assign(:state, :carrier_rejected)
         |> assign(:carrier_rejection_message, message)}

      nil ->
        case AuthCtx.get_user_by_phone(formatted_phone) do
          nil ->
            case Twilio.validate_carrier(formatted_phone) do
              {:ok, carrier_info} ->
                socket
                |> assign(:pending_carrier_info, carrier_info)
                |> dispatch_send_code(formatted_phone)

              {:error, reason, message} ->
                shown =
                  if message == "",
                    do: default_carrier_rejection_user_message(),
                    else: message

                _ = record_carrier_rejection(socket, formatted_phone, reason, shown)

                {:noreply,
                 socket
                 |> assign(:state, :carrier_rejected)
                 |> assign(:carrier_rejection_message, shown)}
            end

          _existing ->
            dispatch_send_code(socket, formatted_phone)
        end
    end
  end

  defp default_carrier_rejection_user_message do
    "This mobile number is not eligible for sign-in with Qadabra right now."
  end

  defp record_carrier_rejection(socket, formatted_phone, reason, message) do
    {snapshot, line, carrier, country, mcc, mnc} =
      case Twilio.lookup_phone_carrier(formatted_phone) do
        {:ok, info} ->
          snap = %{
            "type" => info.type,
            "carrier_name" => info.carrier_name,
            "country_code" => info.country_code,
            "valid" => info.valid,
            "mobile_country_code" => info.mobile_country_code,
            "mobile_network_code" => info.mobile_network_code,
            "national_format" => info.national_format,
            "error_code" => info.error_code
          }

          {snap, info.type, info.carrier_name, info.country_code, info.mobile_country_code,
           info.mobile_network_code}

        _ ->
          {%{}, nil, nil, nil, nil, nil}
      end

    PhoneCarrierRejections.record_rejection(%{
      phone_number: formatted_phone,
      rejection_reason: to_string(reason),
      user_message: message,
      line_type: line,
      carrier_name: carrier,
      country_code: country,
      mobile_country_code: mcc,
      mobile_network_code: mnc,
      lookup_snapshot: snapshot,
      client_ip: socket.assigns.client_ip,
      surface: surface_to_string(socket.assigns.surface)
    })
  end

  # Hammer rate-limit key per-phone per-kind. Falls back to the
  # component DOM id when the visitor hasn't yet entered a phone (which
  # shouldn't happen since they've already verified OTP by the time they
  # can regenerate, but defensive in any case).
  defp regenerate_key(kind, socket) do
    phone =
      case socket.assigns[:mobile_number] do
        phone when is_binary(phone) and phone != "" ->
          String.replace(phone, ~r/\D/, "")

        _ ->
          socket.assigns.id
      end

    "auth_sheet_regenerate_#{kind}:#{phone}"
  end

  defp format_phone(nil), do: ""
  defp format_phone("+" <> _ = p), do: p
  defp format_phone(p) when is_binary(p), do: "+1" <> String.replace(p, ~r/\D/, "")
  defp format_phone(_), do: ""

  # Explicit whitelist — never `String.to_atom/1` untrusted input
  # (the reason comes through a client-pushed event).
  defp classify_finalize_reason("rate_limited"), do: :rate_limited
  defp classify_finalize_reason("token_expired"), do: :token_expired
  defp classify_finalize_reason("token_replayed"), do: :token_replayed
  defp classify_finalize_reason("invalid_token"), do: :token_invalid
  defp classify_finalize_reason("missing_token"), do: :missing_token
  defp classify_finalize_reason("network"), do: :client_network
  defp classify_finalize_reason(_), do: :unknown

  # Runs the two `send_code` rate-limit gates and collapses the result
  # into `:ok` or a `{:denied, reason, retry_after_s}` tuple the
  # handler can match on for user-messaging + audit logging.
  defp rate_check_send_code(formatted_phone, ip) do
    case RateLimit.check_send_code_per_phone(formatted_phone) do
      {:error, {:rate_limited, retry_after_s}} ->
        {:denied, :phone_limit, retry_after_s}

      :ok ->
        case RateLimit.check_send_code_per_ip(ip) do
          {:error, {:rate_limited, retry_after_s}} -> {:denied, :ip_limit, retry_after_s}
          :ok -> :ok
        end
    end
  end

  defp humanize_retry_after(seconds) when seconds <= 90, do: "a minute"
  defp humanize_retry_after(seconds) when seconds < 60 * 60, do: "#{div(seconds, 60)} minutes"
  defp humanize_retry_after(_), do: "an hour"

  # `assigns.mobile_number` uses `AuthSteps.format_phone_number/1` (`###-###-####`).
  # OTP + Twilio paths use `format_phone/1` / `valid_phone_shape?/1`, which strip
  # non-digits first.

  defp valid_phone_shape?(nil), do: false

  defp valid_phone_shape?(phone) when is_binary(phone) do
    digits = String.replace(phone, ~r/\D/, "")
    byte_size(digits) == 10
  end

  defp valid_phone_shape?(_), do: false

  defp surface_to_string(nil), do: nil
  defp surface_to_string(atom) when is_atom(atom), do: Atom.to_string(atom)
  defp surface_to_string(str) when is_binary(str), do: str
  defp surface_to_string(_), do: nil

  defp register_url, do: "https://qadabra.app/register"

  # Phone + code steps only (not signup / iframe / etc.).
  defp powered_by_qadabra_footer do
    assigns = %{}

    ~H"""
    <div class="mt-2 flex flex-col items-center gap-1 border-t border-base-content/[0.07] pt-5">
      <span class="text-[10px] font-medium text-base-content/45 -mb-1">
        Powered by
      </span>
      <img
        src="/images/qadabra_full_gray_opt.svg"
        alt="Qadabra"
        class="h-4.5 w-auto max-w-[5.25rem] object-contain ml-1"
      />
    </div>
    """
  end

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
      <%= if @modal_overlay_visible do %>
        <div
          id={"#{@id}-iframe-probe"}
          phx-hook="IframeDetect"
          phx-target={@myself}
          class="hidden"
        />

        <div
          class="fixed inset-0 z-[70] flex items-end md:items-center justify-center p-0 md:p-4"
          id={"#{@id}-scroll-lock"}
          phx-hook="BodyScrollLock"
          data-body-scroll-lock="true"
        >
          <%!-- Backdrop --%>
          <div
            id={"#{@id}-backdrop"}
            class={[
              "absolute inset-0 bg-black/60 backdrop-blur-sm",
              if(@modal_exiting,
                do: "animate-auth-sheet-backdrop-out",
                else: "animate-auth-sheet-backdrop"
              )
            ]}
            phx-click={@on_cancel}
          />

          <%!--
            Sheet / modal card. Bottom-sheet on narrow viewports so the
            long sign-up steps have room to scroll; centered dialog on
            md+. `max-h-[90vh]` + inner `overflow-y-auto` keeps the
            card itself bounded to the viewport while the content scrolls.
            Enter animation matches qlink modals (fade + slight motion).
          --%>
          <div
            class={[
              "relative flex w-full max-h-[90vh] flex-col overflow-hidden rounded-t-2xl border border-widget-300 bg-base-100 shadow-2xl md:max-w-lg md:rounded-2xl dark:bg-base-200",
              if(@modal_exiting,
                do: "animate-auth-sheet-panel-out",
                else: "animate-auth-sheet-panel"
              )
            ]}
            phx-window-keydown={@on_cancel}
            phx-key="escape"
          >
            <button
              type="button"
              phx-click={@on_cancel}
              class="absolute top-3 right-3 btn btn-sm btn-circle btn-widget-ghost z-10"
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
        class="btn-widget btn-widget-emphasis btn-lg btn-block min-h-14 rounded-full py-3.5 text-base"
      >
        <.icon name="hero-arrow-top-right-on-square" class="w-4 h-4" /> Sign in at qadabra.app
      </a>

      <p class="text-xs text-base-content/60">
        New to Qadabra?
        <a
          href={register_url()}
          target="_blank"
          rel="noopener"
          class="font-medium text-widget-800 hover:text-widget-900 hover:underline"
        >
          Create an account
        </a>
      </p>
    </div>
    """
  end

  defp render_state(%{state: :carrier_rejected} = assigns) do
    ~H"""
    <div class="space-y-5">
      <AuthSteps.phone_carrier_blocked_panel
        message={@carrier_rejection_message || ""}
        mobile_number={@mobile_number}
        target={@myself}
      />
    </div>
    """
  end

  defp render_state(%{state: :phone} = assigns) do
    assigns =
      assign(
        assigns,
        :header_logo,
        connect_brand_header_logo(assigns.connect_brand)
      )

    ~H"""
    <div class="space-y-5">
      <div class="flex flex-col items-center gap-0 text-center">
        <div class="mb-4 md:mb-5">
          <img
            id={"#{@id}-sheet-brand-logo"}
            src={@header_logo.src}
            alt={@header_logo.alt}
            class={@header_logo.class}
          />
        </div>
        <h2 class="text-2xl font-bold text-widget-900 md:text-3xl dark:text-white">
          Connect via mobile
        </h2>
        <p class="text-sm text-base-content/70 md:text-base">
          Enter your mobile number to receive a 6-digit code.
        </p>
        <h3 class="text-md font-bold text-base-content/70 md:text-base mb-0 mt-3 tracking-tight">
          New here?
        </h3>
        <p class="text-sm text-base-content/70 md:text-base">
          Start your new account and wallet.<br />Prefunded with $3.00+ on us.
        </p>
      </div>

      <.form
        for={%{}}
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
            type="text"
            name="value"
            id={"#{@id}-phone-input"}
            value={@mobile_number}
            phx-hook="AuthSheetPhone"
            inputmode="tel"
            autocomplete="tel"
            maxlength="12"
            placeholder="555-123-4567"
            class="input input-bordered w-full text-xl md:text-2xl font-medium tabular-nums tracking-wide"
            aria-invalid={if @mobile_number_error, do: "true"}
          />
          <%= if @mobile_number_error do %>
            <p class="mt-2 text-sm text-error">{@mobile_number_error}</p>
          <% end %>
        </div>

        <button
          type="submit"
          class="btn-widget btn-widget-emphasis btn-lg btn-block min-h-14 rounded-full py-3.5 text-base"
          disabled={not valid_phone_shape?(@mobile_number)}
        >
          Send code
        </button>
      </.form>

      {powered_by_qadabra_footer()}
    </div>
    """
  end

  defp render_state(%{state: :code} = assigns) do
    assigns =
      assign(
        assigns,
        :header_logo,
        connect_brand_header_logo(assigns.connect_brand)
      )

    ~H"""
    <div class="space-y-5">
      <div class="flex flex-col items-center gap-0 text-center">
        <div class="mb-4 md:mb-5">
          <img
            id={"#{@id}-sheet-brand-logo"}
            src={@header_logo.src}
            alt={@header_logo.alt}
            class={@header_logo.class}
          />
        </div>
        <h2 class="text-2xl font-bold text-widget-900 md:text-3xl dark:text-white">
          Enter your code
        </h2>
        <p class="text-sm text-base-content/70 md:text-base">
          We sent a 6-digit code to{" "}
          <span class="font-semibold text-widget-900 dark:text-white">
            {AuthSteps.format_phone_number(@mobile_number)}
          </span>
          .
        </p>
      </div>

      <%= if @finalize_error do %>
        <div
          role="alert"
          class="mx-auto flex w-full max-w-xl gap-2 rounded-lg border border-widget-300 bg-widget-100 px-3 py-2 text-left text-sm text-widget-900"
        >
          <.icon name="hero-exclamation-triangle" class="w-5 h-5 shrink-0 text-widget-700" />
          <span>{@finalize_error}</span>
        </div>
      <% end %>

      <div class="mx-auto w-full max-w-md">
        <QlariusWeb.Components.CustomComponentsMobile.otp_input
          id={"#{@id}-otp"}
          value={@verification_code}
          error={@verification_code_error}
          verify_event="verify_code"
          update_event="update_verification_code"
          widget_theme={true}
        />
      </div>

      <div class="mx-auto flex w-full max-w-lg flex-col gap-2 border-t border-widget-200/40 pt-4 sm:flex-row sm:items-center sm:justify-center sm:gap-3">
        <button
          type="button"
          phx-click="back_to_phone"
          phx-target={@myself}
          title="Use a different mobile number"
          class="btn-widget-ghost btn-md order-2 min-h-11 w-full rounded-full text-sm sm:order-1 sm:flex-1"
        >
          Different number
        </button>
        <button
          type="button"
          phx-click="send_code"
          phx-target={@myself}
          class="btn-widget btn-widget-emphasis btn-lg order-1 min-h-14 w-full rounded-full py-3.5 text-base sm:order-2 sm:flex-1"
        >
          Resend code
        </button>
      </div>

      {powered_by_qadabra_footer()}
    </div>
    """
  end

  defp render_state(%{state: :finalizing} = assigns) do
    ~H"""
    <div class="space-y-5 text-center py-6">
      <div class="flex justify-center">
        <span class="loading loading-spinner loading-lg text-widget-700"></span>
      </div>
      <div>
        <h2 class="text-xl md:text-2xl font-bold dark:text-white">Signing you in…</h2>
        <p class="mt-1 text-sm text-base-content/70">Hang tight, this only takes a second.</p>
      </div>
    </div>
    """
  end

  defp render_state(%{state: :signup_intro} = assigns) do
    ~H"""
    <div class="space-y-5">
      <AuthSteps.signup_intro_panel mobile_number={@mobile_number} target={@myself} />
    </div>
    """
  end

  defp render_state(%{state: :alias} = assigns) do
    ~H"""
    <div class="space-y-5">
      <AuthSteps.signup_progress_bar step={:alias} />

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
        show_back={false}
        next_disabled={not alias_ready?(assigns)}
      />
    </div>
    """
  end

  defp render_state(%{state: :data} = assigns) do
    ~H"""
    <div class="space-y-5">
      <AuthSteps.signup_progress_bar step={:data} />

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
      <AuthSteps.signup_progress_bar step={:confirm} />

      <%= if @signup_error do %>
        <div
          role="alert"
          class="flex gap-2 rounded-lg border border-error/40 bg-error/5 px-3 py-2 text-sm text-error"
        >
          <.icon name="hero-x-circle" class="w-5 h-5 shrink-0" />
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
        legal_confirmation_checked={@legal_confirmation_checked}
        can_complete={can_complete?(assigns)}
        target={@myself}
      />

      <div class="flex flex-col gap-2 pt-2 sm:flex-row sm:items-center sm:gap-3">
        <button
          type="button"
          phx-click="signup_back"
          phx-target={@myself}
          class="btn-widget-ghost btn-md order-2 min-h-11 w-full rounded-full text-sm sm:order-1 sm:flex-1"
        >
          Back
        </button>
        <button
          type="button"
          phx-click="submit_signup"
          phx-target={@myself}
          class="btn-widget btn-widget-emphasis btn-lg order-1 min-h-14 w-full rounded-full py-3.5 text-base sm:order-2 sm:flex-1"
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
        <span class="loading loading-spinner loading-lg text-widget-700"></span>
      </div>
      <div>
        <h2 class="text-xl md:text-2xl font-bold dark:text-white">Creating your account…</h2>
        <p class="mt-1 text-sm text-base-content/70">Setting up your MeFile and wallet.</p>
      </div>
    </div>
    """
  end

  # --------------------------------------------------------------------
  # Sub-components: nav
  # --------------------------------------------------------------------

  attr :target, :any, required: true
  attr :show_back, :boolean, default: true
  attr :back_label, :string, default: "Back"
  attr :back_title, :string, default: nil
  attr :next_disabled, :boolean, default: false

  defp signup_nav(assigns) do
    ~H"""
    <div class="flex flex-col gap-2 pt-2 sm:flex-row sm:items-center sm:gap-3">
      <button
        :if={@show_back}
        type="button"
        phx-click="signup_back"
        phx-target={@target}
        title={@back_title}
        class="btn-widget-ghost btn-md order-2 min-h-11 w-full min-w-0 rounded-full text-sm sm:order-1 sm:flex-1"
      >
        {@back_label}
      </button>
      <button
        type="button"
        phx-click="signup_next"
        phx-target={@target}
        class={[
          "btn-widget btn-widget-emphasis btn-lg min-h-14 rounded-full py-3.5 text-base",
          if(@show_back,
            do: "order-1 w-full sm:order-2 sm:flex-1",
            else: "w-full"
          )
        ]}
        disabled={@next_disabled}
      >
        Next
      </button>
    </div>
    """
  end
end
