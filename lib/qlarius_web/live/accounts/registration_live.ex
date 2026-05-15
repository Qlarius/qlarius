defmodule QlariusWeb.RegistrationLive do
  use QlariusWeb, :live_view

  alias Qlarius.Accounts
  alias Qlarius.YouData.Traits
  alias QlariusWeb.Components.AuthSteps
  alias QlariusWeb.Live.Helpers.ZipCodeLookup
  import QlariusWeb.PWAHelpers
  import QlariusWeb.Components.CustomComponentsMobile, only: [otp_input: 1]

  on_mount {QlariusWeb.DetectMobile, :detect_mobile}

  def mount(params, session, socket) do
    require Logger

    mode = Map.get(params, "mode", "regular")
    proxy_user_id = Map.get(params, "proxy_user_id")
    referral_code_from_params = Map.get(params, "ref") || Map.get(params, "invite")

    referral_code_from_session =
      Map.get(session, "referral_code") || Map.get(session, "invitation_code")

    referral_code = referral_code_from_params || referral_code_from_session || ""

    Logger.info("""
    🎯 REFERRAL DEBUG - Registration mount:
      - from_params: #{inspect(referral_code_from_params)}
      - from_session: #{inspect(referral_code_from_session)}
      - final referral_code: #{inspect(referral_code)}
    """)

    mobile = Phoenix.Flash.get(socket.assigns.flash, :registration_mobile)
    alias_value = Phoenix.Flash.get(socket.assigns.flash, :registration_alias)

    referral_code_verified = mode == "proxy" && referral_code != nil && referral_code != ""
    true_user_id = if mode == "proxy", do: get_true_user_id_from_scope(socket), else: nil

    socket =
      socket
      |> assign(:page_title, "Register")
      |> assign(:mode, mode)
      |> assign(:proxy_user_id, proxy_user_id)
      |> assign(:true_user_id, true_user_id)
      |> assign(:referral_code, referral_code)
      |> assign(:referral_code_input, referral_code)
      |> assign(:referral_code_error, nil)
      |> assign(:referral_code_attempts, 0)
      |> assign(:referral_code_verified, referral_code_verified)
      |> assign(:referral_code_can_skip, false)
      |> assign(:current_step, determine_starting_step(mode, mobile, alias_value))
      |> assign(:mobile_number, "")
      |> assign(:mobile_number_error, nil)
      |> assign(:mobile_number_exists, false)
      |> assign(:proxy_offer_user, nil)
      |> assign(:verification_code, "")
      |> assign(:verification_code_error, nil)
      |> assign(:code_sent, false)
      |> assign(:phone_verified, mode == "proxy")
      |> assign(:carrier_info, nil)
      |> assign(:alias, alias_value || "")
      |> assign(:alias_error, nil)
      |> assign(:base_names, Qlarius.Accounts.AliasGenerator.generate_base_names(5))
      |> assign(:available_numbers, [])
      |> assign(:selected_base, nil)
      |> assign(:selected_number, nil)
      |> assign(:sex_trait_id, nil)
      |> assign(:sex_options, load_sex_options())
      |> assign(:birthdate_year, "")
      |> assign(:birthdate_month, "")
      |> assign(:birthdate_day, "")
      |> assign(:birthdate_valid, false)
      |> assign(:birthdate_error, nil)
      |> assign(:calculated_age, nil)
      |> assign(:age_trait_id, nil)
      |> assign(:confirmation_checked, false)
      |> assign(:legal_confirmation_checked, false)
      |> ZipCodeLookup.initialize_zip_lookup_assigns()
      |> assign(:trait_in_edit, %{id: 4})
      |> init_pwa_assigns(session)

    {:ok, socket}
  end

  def handle_event("pwa_detected", params, socket) do
    handle_pwa_detection(socket, params)
  end

  def handle_event("next_step", _params, socket) do
    case socket.assigns.current_step do
      0 ->
        {:noreply, assign(socket, :current_step, 1)}

      1 ->
        {:noreply, assign(socket, :current_step, 2)}

      2 ->
        {:noreply, assign(socket, :current_step, 3)}

      3 ->
        {:noreply, assign(socket, :current_step, 4)}

      4 ->
        {:noreply, assign(socket, :current_step, 5)}

      5 ->
        {:noreply, socket}
    end
  end

  def handle_event("prev_step", _params, socket) do
    case socket.assigns.current_step do
      0 ->
        {:noreply, socket}

      1 ->
        {:noreply, socket}

      step ->
        {:noreply, assign(socket, :current_step, step - 1)}
    end
  end

  def handle_event("referral_code_from_storage", %{"code" => code}, socket) do
    require Logger

    Logger.info("🎯 REFERRAL DEBUG - Got code from localStorage: #{inspect(code)}")

    # Only use stored code if we don't already have one from URL/session
    if socket.assigns.referral_code == "" do
      {:noreply,
       socket
       |> assign(:referral_code, code)
       |> assign(:referral_code_input, code)}
    else
      Logger.info(
        "🎯 REFERRAL DEBUG - Already have code from URL/session: #{socket.assigns.referral_code}"
      )

      {:noreply, socket}
    end
  end

  def handle_event("update_referral_code", %{"referral_code" => code}, socket) do
    require Logger
    trimmed = String.trim(code)

    Logger.info(
      "🎯 REFERRAL DEBUG - update_referral_code: incoming=#{inspect(trimmed)}, current=#{inspect(socket.assigns.referral_code_input)}"
    )

    # Don't clear the input if incoming is empty but we already have a value
    # This prevents the form's initial change event from clearing a pre-populated value
    new_value =
      if trimmed == "" && socket.assigns.referral_code_input != "" do
        socket.assigns.referral_code_input
      else
        trimmed
      end

    {:noreply,
     socket
     |> assign(:referral_code_input, new_value)
     |> assign(:referral_code_error, nil)}
  end

  def handle_event("validate_referral_code", _params, socket) do
    code = String.trim(socket.assigns.referral_code_input)
    attempts = socket.assigns.referral_code_attempts + 1

    cond do
      code == "" ->
        {:noreply,
         socket
         |> assign(:referral_code_attempts, attempts)
         |> assign(:referral_code_can_skip, attempts >= 3)
         |> assign(:referral_code_verified, true)
         |> assign(:current_step, 1)
         |> put_flash(:info, "Welcome! Feel free to register without a referral code.")}

      true ->
        case Qlarius.Referrals.lookup_referrer_by_code(code) do
          {:ok, _referrer_type, _referrer_id} ->
            {:noreply,
             socket
             |> assign(:referral_code_verified, true)
             |> assign(:referral_code, code)
             |> assign(:current_step, 1)
             |> put_referral_code_cookie(code)
             |> put_flash(:info, "✨ Referral code accepted! Let's get started.")}

          {:error, :not_found} ->
            if attempts >= 3 do
              {:noreply,
               socket
               |> assign(:referral_code_attempts, attempts)
               |> assign(:referral_code_can_skip, true)
               |> assign(
                 :referral_code_error,
                 "Invalid referral code. You can leave the field blank and try registering anyway."
               )}
            else
              {:noreply,
               socket
               |> assign(:referral_code_attempts, attempts)
               |> assign(:referral_code_error, "Invalid referral code. Please try again.")}
            end
        end
    end
  end

  def handle_event("skip_referral_code", _params, socket) do
    {:noreply,
     socket
     |> assign(:referral_code_verified, true)
     |> assign(:current_step, 1)
     |> put_flash(:info, "Welcome! Feel free to explore.")}
  end

  def handle_event("update_mobile", %{"mobile_number" => mobile}, socket) do
    cleaned_mobile = String.replace(mobile, ~r/[^0-9]/, "")

    {:noreply,
     socket
     |> assign(:mobile_number, cleaned_mobile)
     |> assign(:mobile_number_error, nil)
     |> assign(:mobile_number_exists, false)
     |> assign(:proxy_offer_user, nil)}
  end

  def handle_event("send_verification_code", _params, socket) do
    phone = socket.assigns.mobile_number
    formatted_phone = if String.starts_with?(phone, "+"), do: phone, else: "+1#{phone}"

    case Qlarius.Auth.get_user_by_phone(formatted_phone) do
      nil ->
        dispatch_send_verification_code(socket)

      %{role: "admin"} = existing_user ->
        # Admin phone: offer the proxy-under-this-account escape hatch instead
        # of dead-ending at a "log in instead" error. Verifying the code proves
        # the caller controls this admin's phone, which authorizes them to
        # spawn a proxy user beneath the admin account. No code is sent until
        # the admin explicitly accepts the offer via `accept_proxy_offer`.
        {:noreply,
         socket
         |> assign(:proxy_offer_user, existing_user)
         |> assign(:mobile_number_exists, true)
         |> assign(:mobile_number_error, nil)
         |> assign(:code_sent, false)}

      _existing_user ->
        {:noreply,
         socket
         |> assign(:mobile_number_error, "This mobile number is already registered.")
         |> assign(:mobile_number_exists, true)
         |> assign(:proxy_offer_user, nil)
         |> assign(:code_sent, false)}
    end
  end

  @doc false
  # Admin accepted the "spawn a proxy under this admin account" offer. Flip
  # the flow into proxy mode (so `create_user/1` sets `true_user_id` and
  # inherits the admin's referral code on completion), then actually send the
  # verification code to the admin's phone. The verification step proves the
  # caller controls the phone, which is what authorizes the proxy creation.
  def handle_event("accept_proxy_offer", _params, socket) do
    require Logger

    case socket.assigns.proxy_offer_user do
      nil ->
        {:noreply, socket}

      %{id: admin_id, alias: admin_alias} ->
        Logger.info(
          "🧑‍💼 PROXY-VIA-REGISTRATION: admin id=#{admin_id} alias=#{inspect(admin_alias)} accepted proxy offer"
        )

        socket =
          socket
          |> assign(:mode, "proxy")
          |> assign(:true_user_id, admin_id)
          |> assign(:mobile_number_error, nil)

        dispatch_send_verification_code(socket)
    end
  end

  def handle_event("update_verification_code", %{"verification_code" => code}, socket) do
    {:noreply,
     socket
     |> assign(:verification_code, code)
     |> assign(:verification_code_error, nil)}
  end

  def handle_event("verify_code", params, socket) do
    phone = socket.assigns.mobile_number
    # Accept code from hook params or fall back to assign
    code = Map.get(params, "code", socket.assigns.verification_code)
    formatted_phone = if String.starts_with?(phone, "+"), do: phone, else: "+1#{phone}"
    bypass_verification = Application.get_env(:qlarius, :bypass_phone_verification, false)

    # Update assign with the code being verified
    socket = assign(socket, :verification_code, code)

    # Development bypass: Accept "000000" as valid code
    if bypass_verification && code == "000000" do
      {:noreply,
       socket
       |> assign(:phone_verified, true)
       |> assign(:carrier_info, %{
         type: "mobile",
         valid: true,
         country_code: "US",
         carrier_name: "[DEV MODE]",
         mobile_country_code: "310",
         mobile_network_code: "000",
         national_format: AuthSteps.format_phone_number(phone),
         error_code: nil
       })
       |> assign(:verification_code_error, nil)
       |> put_flash(:info, "[DEV MODE] Phone verified!")}
    else
      # Production mode: Use Twilio verification
      case Qlarius.Services.Twilio.verify_code(formatted_phone, code) do
        {:ok, :verified} ->
          case Qlarius.Services.Twilio.validate_carrier(formatted_phone) do
            {:ok, carrier_info} ->
              {:noreply,
               socket
               |> assign(:phone_verified, true)
               |> assign(:carrier_info, carrier_info)
               |> assign(:verification_code_error, nil)
               |> put_flash(:info, "Phone verified successfully!")}

            {:error, :voip_not_allowed, message} ->
              {:noreply,
               socket
               |> assign(:verification_code_error, message)
               |> assign(:code_sent, false)
               |> assign(:verification_code, "")
               |> put_flash(:error, message)}

            {:error, :landline_not_allowed, message} ->
              {:noreply,
               socket
               |> assign(:verification_code_error, message)
               |> assign(:code_sent, false)
               |> assign(:verification_code, "")
               |> put_flash(:error, message)}

            {:error, :carrier_not_allowed, message} ->
              {:noreply,
               socket
               |> assign(:verification_code_error, message)
               |> assign(:code_sent, false)
               |> assign(:verification_code, "")
               |> put_flash(:error, message)}

            {:error, :non_us_number, message} ->
              {:noreply,
               socket
               |> assign(:verification_code_error, message)
               |> assign(:code_sent, false)
               |> assign(:verification_code, "")
               |> put_flash(:error, message)}

            {:error, _reason, message} ->
              {:noreply,
               socket
               |> assign(:verification_code_error, message)
               |> assign(:code_sent, false)
               |> assign(:verification_code, "")
               |> put_flash(:error, message)}
          end

        {:error, _reason} ->
          {:noreply,
           socket
           |> assign(:verification_code_error, "Invalid code entered. Please try again.")
           |> put_flash(:error, "Invalid verification code")}
      end
    end
  end

  def handle_event("validate_alias", %{"alias" => alias_value}, socket) do
    require Logger
    Logger.debug("validate_alias called with value: #{alias_value}")

    alias_value = String.trim(alias_value)

    socket =
      cond do
        alias_value == "" ->
          socket
          |> assign(:alias, alias_value)
          |> assign(:alias_error, nil)

        String.length(alias_value) < 10 ->
          socket
          |> assign(:alias, alias_value)
          |> assign(:alias_error, "Alias must be at least 10 characters")

        true ->
          available = Accounts.alias_available?(alias_value)

          if available do
            socket
            |> assign(:alias, alias_value)
            |> assign(:alias_error, nil)
          else
            socket
            |> assign(:alias, alias_value)
            |> assign(:alias_error, "This alias is already taken")
          end
      end

    {:noreply, socket}
  end

  def handle_event("select_base_name", %{"base_name" => base_name}, socket) do
    alias_gen = Qlarius.Accounts.AliasGenerator
    available_numbers = alias_gen.generate_available_numbers(base_name, 5)

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
    case Hammer.check_rate("regenerate_base:#{socket.assigns.mobile_number}", 60_000, 10) do
      {:allow, _count} ->
        alias_gen = Qlarius.Accounts.AliasGenerator
        base_names = alias_gen.generate_base_names(5)

        {:noreply,
         socket
         |> assign(:base_names, base_names)
         |> assign(:selected_base, nil)
         |> assign(:available_numbers, [])
         |> assign(:selected_number, nil)
         |> assign(:alias, "")
         |> assign(:alias_error, nil)}

      {:deny, _limit} ->
        {:noreply,
         socket
         |> put_flash(:error, "Please wait before regenerating again")}
    end
  end

  def handle_event("regenerate_numbers", _params, socket) do
    base_name = socket.assigns.selected_base

    if base_name do
      case Hammer.check_rate("regenerate_numbers:#{socket.assigns.mobile_number}", 60_000, 10) do
        {:allow, _count} ->
          alias_gen = Qlarius.Accounts.AliasGenerator
          available_numbers = alias_gen.generate_available_numbers(base_name, 5)

          {:noreply,
           socket
           |> assign(:available_numbers, available_numbers)
           |> assign(:selected_number, nil)
           |> assign(:alias, "")
           |> assign(:alias_error, nil)}

        {:deny, _limit} ->
          {:noreply,
           socket
           |> put_flash(:error, "Please wait before regenerating again")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("select_sex", %{"sex_id" => sex_id}, socket) do
    {:noreply, assign(socket, :sex_trait_id, String.to_integer(sex_id))}
  end

  def handle_event("update_birthdate", params, socket) do
    year = Map.get(params, "year", socket.assigns.birthdate_year)
    month = Map.get(params, "month", socket.assigns.birthdate_month)
    day = Map.get(params, "day", socket.assigns.birthdate_day)

    socket =
      socket
      |> assign(:birthdate_year, year)
      |> assign(:birthdate_month, month)
      |> assign(:birthdate_day, day)
      |> validate_birthdate()

    {:noreply, socket}
  end

  def handle_event("lookup_zip_code", %{"zip" => zip_code}, socket) do
    socket = ZipCodeLookup.handle_zip_lookup(socket, zip_code)
    {:noreply, socket}
  end

  def handle_event("toggle_confirmation", %{"checked" => checked}, socket) do
    {:noreply, assign(socket, :confirmation_checked, checked == "true")}
  end

  def handle_event("toggle_legal_confirmation", %{"checked" => checked}, socket) do
    {:noreply, assign(socket, :legal_confirmation_checked, checked == "true")}
  end

  def handle_event("complete_registration", _params, socket) do
    if can_complete?(socket.assigns) do
      case create_user(socket) do
        {:ok, result} ->
          socket = maybe_activate_proxy(socket, result.user.id)

          cond do
            # Admin-phone-verify proxy path: the admin is NOT logged in on this
            # socket (they arrived anonymously at /register and proved phone
            # ownership). Auto-login as the freshly created proxy user so they
            # land on /home instead of bouncing off /proxy_users.
            socket.assigns.mode == "proxy" and not is_nil(socket.assigns.proxy_offer_user) ->
              token = Accounts.generate_user_login_token(result.user.id)

              {:noreply,
               socket
               |> put_flash(:info, "Proxy user created! You're now signed in.")
               |> redirect(to: ~p"/auto_login/#{token}")}

            # Legacy admin-authed proxy path (admin already logged in, creating
            # proxy from the proxy admin UI).
            socket.assigns.mode == "proxy" ->
              {:noreply,
               socket
               |> put_flash(:info, "Proxy user created successfully!")
               |> push_navigate(to: ~p"/proxy_users")}

            true ->
              token = Accounts.generate_user_login_token(result.user.id)

              {:noreply,
               socket
               |> put_flash(:info, "Registration complete!")
               |> redirect(to: ~p"/auto_login/#{token}")}
          end

        {:error, _failed_operation, _failed_value, _changes_so_far} ->
          {:noreply,
           socket
           |> put_flash(:error, "Registration failed. Please try again.")
           |> assign(:current_step, 1)}
      end
    else
      {:noreply, put_flash(socket, :error, "Please complete all required fields")}
    end
  end

  # Link the new proxy user to its true (admin) user. Works for both proxy
  # entry paths: the legacy flow supplies `true_user` via `current_scope`, the
  # admin-phone-verify flow supplies it via the `:true_user_id` assign set in
  # `accept_proxy_offer`.
  defp maybe_activate_proxy(socket, new_user_id) do
    if socket.assigns.mode == "proxy" do
      true_user_id =
        case socket.assigns do
          %{current_scope: %{true_user: %{id: id}}} -> id
          %{true_user_id: id} when is_integer(id) -> id
          _ -> nil
        end

      if true_user_id, do: Accounts.activate_proxy_user(true_user_id, new_user_id)
    end

    socket
  end

  defp get_true_user_id_from_scope(socket) do
    case socket.assigns do
      %{current_scope: %{true_user: %{id: id}}} -> id
      %{current_scope: %{user: %{id: id}}} -> id
      _ -> nil
    end
  end

  defp determine_starting_step("proxy", _mobile, _alias_value), do: 2

  defp determine_starting_step(_mode, _mobile, _alias_value), do: 0

  defp load_sex_options do
    case Traits.get_trait_with_full_survey_data!(1) do
      {:ok, trait} ->
        trait.child_traits
        |> Enum.map(fn child ->
          %{id: child.id, name: child.trait_name}
        end)

      {:error, _} ->
        []
    end
  end

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

  defp can_complete?(assigns) do
    assigns.alias != "" &&
      assigns.alias_error == nil &&
      assigns.sex_trait_id != nil &&
      assigns.birthdate_valid &&
      assigns.age_trait_id != nil &&
      assigns.confirmation_checked &&
      assigns.legal_confirmation_checked
  end

  defp put_referral_code_cookie(socket, _code) do
    socket
  end

  # Actually send (or bypass) the SMS verification code for the phone number
  # currently in `socket.assigns.mobile_number`. Extracted so the happy path
  # and the admin proxy-offer acceptance path share the same plumbing.
  defp dispatch_send_verification_code(socket) do
    phone = socket.assigns.mobile_number
    formatted_phone = if String.starts_with?(phone, "+"), do: phone, else: "+1#{phone}"
    bypass_verification = Application.get_env(:qlarius, :bypass_phone_verification, false)

    if bypass_verification do
      {:noreply,
       socket
       |> assign(:code_sent, true)
       |> assign(:mobile_number_error, nil)
       |> assign(:verification_code, "")
       |> put_flash(:info, "[DEV MODE] Use code: 000000")}
    else
      case Qlarius.Services.Twilio.send_verification_code(formatted_phone) do
        {:ok, _response} ->
          {:noreply,
           socket
           |> assign(:code_sent, true)
           |> assign(:mobile_number_error, nil)
           |> assign(:verification_code, "")
           |> put_flash(:info, "Verification code sent to #{phone}")}

        {:error, _reason} ->
          {:noreply,
           socket
           |> assign(
             :mobile_number_error,
             "Failed to send verification code. Please try again."
           )
           |> put_flash(:error, "Failed to send SMS. Please try again.")}
      end
    end
  end

  defp create_user(socket) do
    require Logger

    Logger.info(
      "🎯 REFERRAL DEBUG - create_user called with referral_code: #{inspect(socket.assigns.referral_code)}"
    )

    date =
      Date.new!(
        String.to_integer(socket.assigns.birthdate_year),
        String.to_integer(socket.assigns.birthdate_month),
        String.to_integer(socket.assigns.birthdate_day)
      )

    # In the admin-phone-verify proxy flow the `mobile_number` assign holds the
    # admin's phone (used only to prove phone ownership). Persisting it on the
    # new proxy user would collide with the admin's existing record under the
    # `mobile_number_hash IS NOT NULL` unique index, so drop it.
    mobile_number =
      cond do
        socket.assigns.mode == "proxy" and not is_nil(socket.assigns.proxy_offer_user) -> nil
        socket.assigns.mobile_number == "" -> nil
        true -> socket.assigns.mobile_number
      end

    attrs = %{
      alias: socket.assigns.alias,
      mobile_number: mobile_number,
      role: "user",
      date_of_birth: date,
      sex_trait_id: socket.assigns.sex_trait_id,
      age_trait_id: socket.assigns.age_trait_id,
      zip_code_trait_id:
        if(socket.assigns.zip_lookup_valid, do: socket.assigns.zip_lookup_trait.id, else: nil),
      home_zip:
        if(socket.assigns.zip_lookup_valid, do: socket.assigns.zip_lookup_input, else: nil)
    }

    attrs =
      if socket.assigns.mode == "proxy" && socket.assigns.true_user_id do
        Map.put(attrs, :true_user_id, socket.assigns.true_user_id)
      else
        attrs
      end

    # For proxy users, always use the admin's referral code (generate if needed)
    referral_code =
      if socket.assigns.mode == "proxy" && socket.assigns.true_user_id do
        admin_me_file = Accounts.get_me_file_by_user_id(socket.assigns.true_user_id)

        cond do
          is_nil(admin_me_file) ->
            Logger.warning("🎯 REFERRAL DEBUG - Proxy user: admin has no me_file!")
            socket.assigns.referral_code

          admin_me_file.referral_code && admin_me_file.referral_code != "" ->
            Logger.info(
              "🎯 REFERRAL DEBUG - Proxy user: using admin referral code: #{admin_me_file.referral_code}"
            )

            admin_me_file.referral_code

          true ->
            # Generate referral code for admin if they don't have one
            code = Qlarius.Referrals.generate_referral_code("mefile")

            case Qlarius.Referrals.set_referral_code(admin_me_file, code) do
              {:ok, _} ->
                Logger.info(
                  "🎯 REFERRAL DEBUG - Proxy user: generated admin referral code: #{code}"
                )

                code

              {:error, _} ->
                Logger.warning("🎯 REFERRAL DEBUG - Proxy user: failed to generate admin code")
                socket.assigns.referral_code
            end
        end
      else
        socket.assigns.referral_code
      end

    Accounts.register_new_user(attrs, referral_code)
  end

  def render(assigns) do
    ~H"""
    <%!-- Hook to read referral code from localStorage --%>
    <div id="registration-referral-loader" phx-hook="RegistrationReferralCode" class="hidden"></div>

    <div
      id="registration-pwa-detect"
      phx-hook="HiPagePWADetect"
      class="min-h-screen flex flex-col px-4 pb-24"
    >
      <%!-- Safe area top spacer for PWA notch --%>
      <div class="h-[env(safe-area-inset-top)] flex-shrink-0"></div>
      <%!-- Logo spacer --%>
      <div class="flex-shrink-0 py-8 md:py-12 flex justify-center">
        <img
          src="/images/qadabra_full_gray_opt.svg"
          alt="Qadabra"
          class="h-12 md:h-16 w-auto"
        />
      </div>

      <div class="flex-1 flex items-center justify-center pb-16">
        <div class="w-full max-w-2xl space-y-8 px-6 md:px-8">
          <%= if @current_step > 0 do %>
            <h1 class="text-4xl md:text-5xl font-bold mb-8 dark:text-white">
              Registration
            </h1>
            <%= if @mode == "proxy" do %>
              <ul class="steps w-full mb-8 text-xs md:text-sm">
                <li class={"step #{if @current_step >= 2, do: "step-primary"}"}>Alias</li>
                <li class={"step #{if @current_step >= 3, do: "step-primary"}"}>Data</li>
                <li class={"step #{if @current_step >= 4, do: "step-primary"}"}>Confirm</li>
              </ul>
            <% else %>
              <ul class="steps w-full mb-8 text-xs md:text-sm">
                <li class={"step #{if @current_step >= 1, do: "step-primary"}"}>Mobile</li>
                <li class={"step #{if @current_step >= 2, do: "step-primary"}"}>Alias</li>
                <li class={"step #{if @current_step >= 3, do: "step-primary"}"}>Data</li>
                <li class={"step #{if @current_step >= 4, do: "step-primary"}"}>Confirm</li>
              </ul>
            <% end %>
          <% end %>

          <%= if @current_step == 0 do %>
            <.step_zero
              referral_code={@referral_code_input}
              referral_code_error={@referral_code_error}
              referral_code_attempts={@referral_code_attempts}
              referral_code_can_skip={@referral_code_can_skip}
            />
          <% end %>

          <%= if @current_step == 1 do %>
            <.step_one
              mobile_number={@mobile_number}
              mode={@mode}
              mobile_number_error={@mobile_number_error}
              mobile_number_exists={@mobile_number_exists}
              proxy_offer_user={@proxy_offer_user}
              verification_code={@verification_code}
              verification_code_error={@verification_code_error}
              code_sent={@code_sent}
              phone_verified={@phone_verified}
              carrier_info={@carrier_info}
            />
          <% end %>

          <%= if @current_step == 2 do %>
            <AuthSteps.alias_picker
              alias={@alias}
              alias_error={@alias_error}
              base_names={@base_names}
              available_numbers={@available_numbers}
              selected_base={@selected_base}
              selected_number={@selected_number}
            />
          <% end %>

          <%= if @current_step == 3 do %>
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
            />
          <% end %>

          <%= if @current_step == 4 do %>
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
              referral_code={@referral_code}
              confirmation_checked={@confirmation_checked}
              legal_confirmation_checked={@legal_confirmation_checked}
              can_complete={can_complete?(assigns)}
            />
          <% end %>

          <%= if @mode == "proxy" && @current_step > 0 do %>
            <div class="mt-12 text-center">
              <span class="badge badge-sm badge-outline badge-primary">PROXY USER MODE</span>
            </div>
          <% end %>
        </div>
      </div>

      <div class="fixed bottom-0 left-0 right-0 bg-base-100 dark:bg-base-300 border-t border-base-300 dark:border-base-content/20">
        <div class="p-4 max-w-2xl mx-auto flex gap-3">
          <%= if @current_step > 1 do %>
            <button
              phx-click="prev_step"
              class="btn btn-outline btn-lg flex-1 rounded-full text-lg normal-case"
            >
              ← Previous
            </button>
          <% end %>

          <%= if @current_step == 0 do %>
            <%= if @referral_code_can_skip do %>
              <button
                phx-click="skip_referral_code"
                class="btn btn-outline btn-lg flex-1 rounded-full text-lg normal-case"
              >
                Skip & Register
              </button>
            <% end %>
            <button
              phx-click="validate_referral_code"
              class="btn btn-primary btn-lg flex-1 rounded-full text-lg normal-case"
            >
              Continue
            </button>
          <% end %>

          <%= if @current_step > 0 && @current_step < 4 do %>
            <%= if can_proceed_to_next_step?(assigns) do %>
              <button
                phx-click="next_step"
                class="btn btn-primary btn-lg flex-1 rounded-full text-lg normal-case"
              >
                Next →
              </button>
            <% else %>
              <button
                class="btn btn-disabled btn-lg flex-1 rounded-full text-lg normal-case"
                disabled
              >
                Next →
              </button>
            <% end %>
          <% end %>

          <%= if @current_step == 4 do %>
            <%= if can_complete?(assigns) do %>
              <button
                phx-click="complete_registration"
                class="btn btn-success btn-lg flex-1 rounded-full text-lg normal-case"
              >
                Register
              </button>
            <% else %>
              <button
                class="btn btn-disabled btn-lg flex-1 rounded-full text-lg normal-case"
                disabled
              >
                Register
              </button>
            <% end %>
          <% end %>
        </div>
        <%!-- Safe area bottom spacer for PWA home indicator --%>
        <div class="h-[env(safe-area-inset-bottom)]"></div>
      </div>
    </div>
    """
  end

  defp can_proceed_to_next_step?(assigns) do
    case assigns.current_step do
      1 ->
        # Phone verification is always required UNLESS we're in the legacy
        # admin-authed proxy flow (admin already authed; phone is optional
        # metadata). When proxy mode was entered via the admin-phone-verify
        # escape hatch (`proxy_offer_user` is set), we still need to prove
        # phone ownership before advancing.
        if assigns.mode == "proxy" and is_nil(assigns.proxy_offer_user) do
          true
        else
          assigns.phone_verified
        end

      2 ->
        assigns.selected_base != nil && assigns.selected_number != nil && assigns.alias != ""

      3 ->
        assigns.sex_trait_id != nil && assigns.birthdate_valid &&
          assigns.age_trait_id != nil && assigns.zip_lookup_valid

      4 ->
        false
    end
  end

  attr :referral_code, :string, required: true
  attr :referral_code_error, :string, default: nil
  attr :referral_code_attempts, :integer, default: 0
  attr :referral_code_can_skip, :boolean, default: false

  defp step_zero(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="text-center mb-8">
        <h3 class="text-2xl md:text-3xl font-bold mb-4 text-primary">
          Join our BETA!
        </h3>
        <p class="text-lg md:text-xl text-base-content/70 dark:text-base-content/60">
          You've been invited to early access to Qadabra. Enter your referral code.
        </p>
      </div>

      <div class="card bg-base-200 shadow-xl">
        <div class="card-body">
          <.form for={%{}} phx-change="update_referral_code">
            <div class="form-control">
              <label class="label">
                <span class="label-text text-lg">Referral Code</span>
              </label>
              <input
                type="text"
                name="referral_code"
                value={@referral_code}
                placeholder="Enter your referral code"
                class="input input-bordered input-lg w-full font-mono"
                autocomplete="off"
              />
              <%= if @referral_code_error do %>
                <label class="label">
                  <span class="label-text-alt text-error text-base">{@referral_code_error}</span>
                </label>
              <% end %>
              <%= if @referral_code_attempts > 0 && !@referral_code_error do %>
                <label class="label">
                  <span class="label-text-alt text-base-content/60">
                    Attempt {@referral_code_attempts} of 3
                  </span>
                </label>
              <% end %>
            </div>
          </.form>

          <%= if @referral_code_can_skip do %>
            <div class="alert alert-info mt-4">
              <.icon name="hero-information-circle" class="h-6 w-6" />
              <span>
                Having trouble? You can skip and register without a referral code.
              </span>
            </div>
          <% end %>

          <div class="mt-4">
            <p class="text-sm text-base-content/60 text-center">
              Don't have a code? Ask a friend to share their referral link.
            </p>
          </div>
        </div>
      </div>

      <div class="mt-8 flex justify-center">
        <img
          src="/images/4_product_logo_strip.png"
          alt="YouData, Sponster, TIQIT, qlink"
          class="h-16 md:h-18 w-auto"
        />
      </div>

      <div class="text-center mt-6">
        <p class="text-base">
          Already have an account?
          <.link navigate={~p"/login"} class="link link-primary">Sign In</.link>
        </p>
      </div>
    </div>
    """
  end

  attr :mobile_number, :string, required: true
  attr :mode, :string, required: true
  attr :mobile_number_error, :string, default: nil
  attr :mobile_number_exists, :boolean, default: false
  attr :proxy_offer_user, :any, default: nil
  attr :verification_code, :string, required: true
  attr :verification_code_error, :string, default: nil
  attr :code_sent, :boolean, required: true
  attr :phone_verified, :boolean, required: true
  attr :carrier_info, :map, default: nil

  defp step_one(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h2 class="text-2xl md:text-3xl font-bold mb-3 dark:text-white">Mobile Number</h2>
        <%= if not @phone_verified do %>
          <p class="text-base md:text-lg text-base-content/70 dark:text-base-content/60">
            <%= cond do %>
              <% @proxy_offer_user -> %>
                Enter the code we just texted to {@proxy_offer_user.alias}'s phone to confirm ownership.
              <% @mode == "proxy" -> %>
                Optional: Enter a mobile number for this proxy user
              <% true -> %>
                We'll send a verification code to confirm your phone number
            <% end %>
          </p>
        <% end %>
      </div>

      <%= if @mode != "proxy" or @proxy_offer_user do %>
        <%= if not @phone_verified do %>
          <.form
            for={%{}}
            phx-change="update_mobile"
            phx-submit="send_verification_code"
            autocomplete="off"
          >
            <div class="form-control w-full">
              <label class="label">
                <span class="label-text text-lg dark:text-gray-300">Mobile Number *</span>
              </label>
              <div class="flex flex-col gap-3 w-full">
                <input
                  id="mobile-input"
                  name="mobile_number"
                  type="tel"
                  inputmode="numeric"
                  pattern="[0-9]*"
                  maxlength="10"
                  placeholder="5551234567"
                  autocomplete="tel-national"
                  oninput="this.value = this.value.replace(/[^0-9]/g, '')"
                  data-form-type="other"
                  class={"input input-bordered input-lg w-full text-lg dark:bg-base-100 dark:text-white #{if @mobile_number_error, do: "input-error"}"}
                  value={@mobile_number}
                  disabled={@code_sent}
                />
                <%= if not @code_sent do %>
                  <button
                    type="submit"
                    class="btn btn-primary btn-lg rounded-full w-full"
                    disabled={String.length(@mobile_number) != 10}
                  >
                    Send Code
                  </button>
                <% end %>
              </div>
              <%= if @proxy_offer_user do %>
                <div class="mt-3 p-4 bg-info/10 border border-info rounded-lg">
                  <div class="flex items-start gap-3">
                    <.icon
                      name="hero-user-plus"
                      class="w-6 h-6 text-info flex-shrink-0 mt-0.5"
                    />
                    <div class="flex-1">
                      <p class="font-medium text-base dark:text-white">
                        Admin account recognized:
                        <span class="font-mono">{@proxy_offer_user.alias}</span>
                      </p>
                      <p class="text-sm text-base-content/70 dark:text-base-content/60 mt-1">
                        Create a new proxy user under this account? We'll text
                        a verification code to confirm you own this phone.
                      </p>
                      <div class="mt-3 flex flex-wrap gap-2">
                        <button
                          type="button"
                          phx-click="accept_proxy_offer"
                          class="btn btn-info btn-sm"
                        >
                          <.icon name="hero-user-plus" class="w-4 h-4" /> Continue as proxy user
                        </button>
                        <.link
                          navigate={~p"/login"}
                          class="btn btn-ghost btn-sm"
                        >
                          <.icon name="hero-arrow-right-on-rectangle" class="w-4 h-4" />
                          Log in instead
                        </.link>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>
              <%= if @mobile_number_error do %>
                <%= if @mobile_number_exists do %>
                  <div class="mt-3 p-4 bg-warning/10 border border-warning rounded-lg">
                    <div class="flex items-start gap-3">
                      <.icon
                        name="hero-exclamation-triangle"
                        class="w-6 h-6 text-warning flex-shrink-0 mt-0.5"
                      />
                      <div class="flex-1">
                        <p class="font-medium text-base dark:text-white">
                          This mobile number is already registered
                        </p>
                        <p class="text-sm text-base-content/70 dark:text-base-content/60 mt-1">
                          If this is your number, please log in instead.
                        </p>
                        <.link
                          navigate={~p"/login"}
                          class="btn btn-warning btn-sm mt-3"
                        >
                          <.icon name="hero-arrow-right-on-rectangle" class="w-4 h-4" /> Go to Login
                        </.link>
                      </div>
                    </div>
                  </div>
                <% else %>
                  <div class="mt-3">
                    <div class="badge badge-error badge-lg p-4 text-base">
                      <.icon name="hero-x-circle" class="w-5 h-5 mr-2" />
                      {@mobile_number_error}
                    </div>
                  </div>
                <% end %>
              <% else %>
                <%= if @mobile_number != "" && String.length(@mobile_number) < 10 do %>
                  <label class="label">
                    <span class="label-text-alt text-base">
                      {String.length(@mobile_number)}/10 digits
                    </span>
                  </label>
                <% end %>
              <% end %>
            </div>
          </.form>

          <%= if @code_sent do %>
            <div class="space-y-2">
              <label class="label">
                <span class="label-text text-lg dark:text-gray-300">Verification Code *</span>
              </label>
              <.otp_input
                id="registration-otp"
                value={@verification_code}
                error={@verification_code_error}
                verify_event="verify_code"
                update_event="update_verification_code"
                resend_event="send_verification_code"
              />
            </div>
          <% end %>
        <% else %>
          <div class="card bg-success text-success-content shadow-lg">
            <div class="card-body p-6">
              <div class="flex items-start gap-4">
                <div class="flex-shrink-0">
                  <div class="w-12 h-12 rounded-full bg-success-content/20 flex items-center justify-center">
                    <.icon name="hero-check-circle" class="w-7 h-7" />
                  </div>
                </div>
                <div class="flex-1 space-y-3">
                  <div>
                    <h3 class="font-bold text-lg">Phone Number Verified</h3>
                    <p class="text-base opacity-90 font-mono">
                      {AuthSteps.format_phone_number(@mobile_number)}
                    </p>
                  </div>
                  <%= if @carrier_info do %>
                    <div class="flex flex-wrap gap-2">
                      <div class="badge badge-lg bg-success-content/20 border-0 gap-2">
                        <.icon name="hero-signal" class="w-4 h-4" />
                        {@carrier_info.carrier_name || "Unknown"}
                      </div>
                      <div class="badge badge-lg bg-success-content/20 border-0 gap-2">
                        <.icon name="hero-globe-americas" class="w-4 h-4" />
                        {@carrier_info.country_code}
                      </div>
                      <div class="badge badge-lg bg-success-content/20 border-0 gap-2">
                        <.icon name="hero-device-phone-mobile" class="w-4 h-4" />
                        {String.capitalize(@carrier_info.type || "mobile")}
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      <% else %>
        <.form for={%{}} phx-change="update_mobile" autocomplete="off">
          <div class="form-control w-full">
            <label class="label">
              <span class="label-text text-lg dark:text-gray-300">
                Mobile Number (optional)
              </span>
            </label>
            <input
              id="mobile-input"
              name="mobile_number"
              type="tel"
              inputmode="numeric"
              pattern="[0-9]*"
              maxlength="10"
              placeholder="5551234567"
              autocomplete="tel-national"
              oninput="this.value = this.value.replace(/[^0-9]/g, '')"
              data-form-type="other"
              class="input input-bordered input-lg w-full text-lg dark:bg-base-100 dark:text-white"
              value={@mobile_number}
            />
          </div>
        </.form>
      <% end %>

      <%= if @mode != "proxy" do %>
        <div class="text-center mt-6">
          <p class="text-base">
            Already have an account?
            <.link navigate={~p"/login"} class="link link-primary">Sign In</.link>
          </p>
        </div>
      <% end %>
    </div>
    """
  end
end
