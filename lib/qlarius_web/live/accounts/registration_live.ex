defmodule QlariusWeb.RegistrationLive do
  use QlariusWeb, :live_view

  alias Qlarius.Accounts
  alias Qlarius.YouData.{MeFiles, Traits}
  alias QlariusWeb.Live.Helpers.ZipCodeLookup
  import QlariusWeb.PWAHelpers

  def mount(params, session, socket) do
    mode = Map.get(params, "mode", "regular")
    proxy_user_id = Map.get(params, "proxy_user_id")
    referral_code = Map.get(params, "ref") || Map.get(params, "invite")

    invitation_from_cookie = Map.get(session, "invitation_code")
    invitation_code = referral_code || invitation_from_cookie || ""

    mobile = Phoenix.Flash.get(socket.assigns.flash, :registration_mobile)
    alias_value = Phoenix.Flash.get(socket.assigns.flash, :registration_alias)

    invitation_verified = mode == "proxy" && referral_code != nil
    true_user_id = if mode == "proxy", do: get_true_user_id_from_scope(socket), else: nil

    socket =
      socket
      |> assign(:page_title, "Register")
      |> assign(:mode, mode)
      |> assign(:proxy_user_id, proxy_user_id)
      |> assign(:true_user_id, true_user_id)
      |> assign(:referral_code, referral_code)
      |> assign(:invitation_code, invitation_code)
      |> assign(:invitation_error, nil)
      |> assign(:invitation_attempts, 0)
      |> assign(:invitation_verified, invitation_verified)
      |> assign(:invitation_can_skip, false)
      |> assign(:current_step, determine_starting_step(mode, mobile, alias_value))
      |> assign(:mobile_number, "")
      |> assign(:mobile_number_error, nil)
      |> assign(:mobile_number_exists, false)
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
      |> ZipCodeLookup.initialize_zip_lookup_assigns()
      |> assign(:trait_in_edit, %{id: 4})
      |> assign(:is_pwa, false)
      |> assign(:device_type, :desktop)

    {:ok, socket}
  end

  def handle_event("pwa_detected", params, socket) do
    handle_pwa_detection(socket, params)
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

  def handle_event("update_invitation_code", %{"invitation_code" => code}, socket) do
    {:noreply,
     socket
     |> assign(:invitation_code, String.trim(code))
     |> assign(:invitation_error, nil)}
  end

  def handle_event("validate_invitation", _params, socket) do
    code = String.trim(socket.assigns.invitation_code)
    attempts = socket.assigns.invitation_attempts + 1

    cond do
      code == "" ->
        {:noreply,
         socket
         |> assign(:invitation_attempts, attempts)
         |> assign(:invitation_can_skip, attempts >= 3)
         |> assign(:invitation_verified, true)
         |> assign(:current_step, 1)
         |> put_flash(:info, "Welcome! Feel free to register without an invitation.")}

      true ->
        case Qlarius.Referrals.lookup_referrer_by_code(code) do
          {:ok, _referrer_type, _referrer_id} ->
            {:noreply,
             socket
             |> assign(:invitation_verified, true)
             |> assign(:referral_code, code)
             |> assign(:current_step, 1)
             |> put_invitation_cookie(code)
             |> put_flash(:info, "✨ Invitation accepted! Let's get started.")}

          {:error, :not_found} ->
            if attempts >= 3 do
              {:noreply,
               socket
               |> assign(:invitation_attempts, attempts)
               |> assign(:invitation_can_skip, true)
               |> assign(
                 :invitation_error,
                 "Invalid invitation code. You can leave the field blank and try registering anyway."
               )}
            else
              {:noreply,
               socket
               |> assign(:invitation_attempts, attempts)
               |> assign(:invitation_error, "Invalid invitation code. Please try again.")}
            end
        end
    end
  end

  def handle_event("skip_invitation", _params, socket) do
    {:noreply,
     socket
     |> assign(:invitation_verified, true)
     |> assign(:current_step, 1)
     |> put_flash(:info, "Welcome! Feel free to explore.")}
  end

  def handle_event("update_mobile", %{"mobile_number" => mobile}, socket) do
    cleaned_mobile = String.replace(mobile, ~r/[^0-9]/, "")

    {:noreply,
     socket
     |> assign(:mobile_number, cleaned_mobile)
     |> assign(:mobile_number_error, nil)
     |> assign(:mobile_number_exists, false)}
  end

  def handle_event("send_verification_code", _params, socket) do
    phone = socket.assigns.mobile_number
    formatted_phone = if String.starts_with?(phone, "+"), do: phone, else: "+1#{phone}"
    bypass_verification = Application.get_env(:qlarius, :bypass_phone_verification, false)

    # Check if mobile number is already registered
    case Qlarius.Auth.get_user_by_phone(formatted_phone) do
      nil ->
        # Number not registered, proceed with verification
        if bypass_verification do
          # Development mode: Skip Twilio, auto-approve
          {:noreply,
           socket
           |> assign(:code_sent, true)
           |> assign(:mobile_number_error, nil)
           |> assign(:verification_code, "000000")
           |> push_event("focus", %{id: "verification-code-input"})
           |> put_flash(:info, "[DEV MODE] Use code: 000000")}
        else
          # Production mode: Send real SMS via Twilio
          case Qlarius.Services.Twilio.send_verification_code(formatted_phone) do
            {:ok, _response} ->
              {:noreply,
               socket
               |> assign(:code_sent, true)
               |> assign(:mobile_number_error, nil)
               |> push_event("focus", %{id: "verification-code-input"})
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

      _existing_user ->
        # Number already registered
        {:noreply,
         socket
         |> assign(:mobile_number_error, "This mobile number is already registered.")
         |> assign(:mobile_number_exists, true)
         |> assign(:code_sent, false)}
    end
  end

  def handle_event("update_verification_code", %{"verification_code" => code}, socket) do
    {:noreply,
     socket
     |> assign(:verification_code, code)
     |> assign(:verification_code_error, nil)}
  end

  def handle_event("verify_code", _params, socket) do
    phone = socket.assigns.mobile_number
    code = socket.assigns.verification_code
    formatted_phone = if String.starts_with?(phone, "+"), do: phone, else: "+1#{phone}"
    bypass_verification = Application.get_env(:qlarius, :bypass_phone_verification, false)

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
         national_format: format_phone_number(phone),
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

  def handle_event("complete_registration", _params, socket) do
    if can_complete?(socket.assigns) do
      case create_user(socket) do
        {:ok, result} ->
          socket =
            if socket.assigns.mode == "proxy" do
              case socket.assigns do
                %{current_scope: %{true_user: %{id: true_user_id}}} ->
                  Accounts.activate_proxy_user(true_user_id, result.user.id)
                  socket

                _ ->
                  socket
              end
            else
              socket
            end

          if socket.assigns.mode == "proxy" do
            {:noreply,
             socket
             |> put_flash(:info, "Proxy user created successfully!")
             |> push_navigate(to: ~p"/proxy_users")}
          else
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

  defp validate_birthdate(socket) do
    year = socket.assigns.birthdate_year
    month = socket.assigns.birthdate_month
    day = socket.assigns.birthdate_day

    with true <- String.length(year) == 4,
         {year_int, ""} <- Integer.parse(year),
         true <- String.length(month) >= 1 and String.length(month) <= 2,
         {month_int, ""} <- Integer.parse(month),
         true <- month_int >= 1 and month_int <= 12,
         true <- String.length(day) >= 1 and String.length(day) <= 2,
         {day_int, ""} <- Integer.parse(day),
         true <- day_int >= 1 and day_int <= 31,
         {:ok, date} <- Date.new(year_int, month_int, day_int) do
      age = MeFiles.calculate_age(date)

      if age && age >= 18 do
        age_trait = MeFiles.get_age_trait_for_age(age)

        socket
        |> assign(:birthdate_valid, true)
        |> assign(:birthdate_error, nil)
        |> assign(:calculated_age, age)
        |> assign(:age_trait_id, if(age_trait, do: age_trait.id, else: nil))
      else
        socket
        |> assign(:birthdate_valid, false)
        |> assign(:birthdate_error, "Must be 18 or older")
        |> assign(:calculated_age, age)
        |> assign(:age_trait_id, nil)
      end
    else
      _ ->
        socket
        |> assign(:birthdate_valid, false)
        |> assign(:birthdate_error, nil)
        |> assign(:calculated_age, nil)
        |> assign(:age_trait_id, nil)
    end
  end

  defp can_complete?(assigns) do
    assigns.alias != "" &&
      assigns.alias_error == nil &&
      assigns.sex_trait_id != nil &&
      assigns.birthdate_valid &&
      assigns.age_trait_id != nil &&
      assigns.confirmation_checked
  end

  defp put_invitation_cookie(socket, _code) do
    socket
  end

  defp create_user(socket) do
    date =
      Date.new!(
        String.to_integer(socket.assigns.birthdate_year),
        String.to_integer(socket.assigns.birthdate_month),
        String.to_integer(socket.assigns.birthdate_day)
      )

    attrs = %{
      alias: socket.assigns.alias,
      mobile_number:
        if(socket.assigns.mobile_number != "", do: socket.assigns.mobile_number, else: nil),
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

    Accounts.register_new_user(attrs, socket.assigns.referral_code)
  end

  def render(assigns) do
    ~H"""
    <div
      id="registration-pwa-detect"
      phx-hook="HiPagePWADetect"
      class="min-h-screen flex items-center justify-center px-4 pb-24 relative"
    >
      <div class="absolute top-12 left-0 right-0 flex justify-center">
        <img
          src="/images/qadabra_full_gray_opt.svg"
          alt="Qadabra"
          class="h-12 md:h-16 w-auto"
        />
      </div>

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
            invitation_code={@invitation_code}
            invitation_error={@invitation_error}
            invitation_attempts={@invitation_attempts}
            invitation_can_skip={@invitation_can_skip}
          />
        <% end %>

        <%= if @current_step == 1 do %>
          <.step_one
            mobile_number={@mobile_number}
            mode={@mode}
            mobile_number_error={@mobile_number_error}
            mobile_number_exists={@mobile_number_exists}
            verification_code={@verification_code}
            verification_code_error={@verification_code_error}
            code_sent={@code_sent}
            phone_verified={@phone_verified}
            carrier_info={@carrier_info}
          />
        <% end %>

        <%= if @current_step == 2 do %>
          <.step_two
            alias={@alias}
            alias_error={@alias_error}
            base_names={@base_names}
            available_numbers={@available_numbers}
            selected_base={@selected_base}
            selected_number={@selected_number}
          />
        <% end %>

        <%= if @current_step == 3 do %>
          <.step_three
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
          <.step_four
            mobile_number={@mobile_number}
            alias={@alias}
            sex_trait_id={@sex_trait_id}
            sex_options={@sex_options}
            birthdate_year={@birthdate_year}
            birthdate_month={@birthdate_month}
            birthdate_day={@birthdate_day}
            calculated_age={@calculated_age}
            zip_lookup_trait={@zip_lookup_trait}
            confirmation_checked={@confirmation_checked}
            can_complete={can_complete?(assigns)}
          />
        <% end %>

        <%= if @mode == "proxy" && @current_step > 0 do %>
          <div class="mt-12 text-center">
            <span class="badge badge-sm badge-outline badge-primary">PROXY USER MODE</span>
          </div>
        <% end %>
      </div>

      <div class="fixed bottom-0 left-0 right-0 bg-base-100 dark:bg-base-300 border-t border-base-300 dark:border-base-content/20 p-4 safe-area-inset-bottom">
        <div class="max-w-2xl mx-auto flex gap-3">
          <%= if @current_step > 1 do %>
            <button
              phx-click="prev_step"
              class="btn btn-outline btn-lg flex-1 rounded-full text-lg normal-case"
            >
              ← Previous
            </button>
          <% end %>

          <%= if @current_step == 0 do %>
            <%= if @invitation_can_skip do %>
              <button
                phx-click="skip_invitation"
                class="btn btn-outline btn-lg flex-1 rounded-full text-lg normal-case"
              >
                Skip & Register
              </button>
            <% end %>
            <button
              phx-click="validate_invitation"
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
      </div>
    </div>
    """
  end

  defp can_proceed_to_next_step?(assigns) do
    case assigns.current_step do
      1 ->
        if assigns.mode == "proxy" do
          true
        else
          assigns.phone_verified
        end

      2 ->
        assigns.selected_base != nil && assigns.selected_number != nil && assigns.alias != ""

      3 ->
        has_required =
          assigns.sex_trait_id != nil && assigns.birthdate_valid && assigns.age_trait_id != nil

        zip_ok =
          if assigns.zip_lookup_input != "" do
            assigns.zip_lookup_valid
          else
            true
          end

        has_required && zip_ok

      4 ->
        false
    end
  end

  attr :invitation_code, :string, required: true
  attr :invitation_error, :string, default: nil
  attr :invitation_attempts, :integer, default: 0
  attr :invitation_can_skip, :boolean, default: false

  defp step_zero(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="text-center mb-8">
        <h3 class="text-2xl md:text-3xl font-bold mb-4 text-primary">
          Join our BETA!
        </h3>
        <p class="text-lg md:text-xl text-base-content/70 dark:text-base-content/60">
          You've been invited to early access to Qadabra. Enter your invitation code.
        </p>
      </div>

      <div class="card bg-base-200 shadow-xl">
        <div class="card-body">
          <.form for={%{}} phx-change="update_invitation_code">
            <div class="form-control">
              <label class="label">
                <span class="label-text text-lg">Invitation Code</span>
              </label>
              <input
                type="text"
                name="invitation_code"
                value={@invitation_code}
                placeholder="Enter your invitation code"
                class="input input-bordered input-lg w-full font-mono"
                autocomplete="off"
              />
              <%= if @invitation_error do %>
                <label class="label">
                  <span class="label-text-alt text-error text-base">{@invitation_error}</span>
                </label>
              <% end %>
              <%= if @invitation_attempts > 0 && !@invitation_error do %>
                <label class="label">
                  <span class="label-text-alt text-base-content/60">
                    Attempt {@invitation_attempts} of 3
                  </span>
                </label>
              <% end %>
            </div>
          </.form>

          <%= if @invitation_can_skip do %>
            <div class="alert alert-info mt-4">
              <.icon name="hero-information-circle" class="h-6 w-6" />
              <span>
                Having trouble? You can skip and register without an invitation.
              </span>
            </div>
          <% end %>

          <div class="mt-4">
            <p class="text-sm text-base-content/60 text-center">
              Don't have a code? Contact us for an invitation or ask a friend to share their referral link.
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
    </div>
    """
  end

  attr :mobile_number, :string, required: true
  attr :mode, :string, required: true
  attr :mobile_number_error, :string, default: nil
  attr :mobile_number_exists, :boolean, default: false
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
        <p class="text-base md:text-lg text-base-content/70 dark:text-base-content/60">
          <%= if @mode == "proxy" do %>
            Optional: Enter a mobile number for this proxy user
          <% else %>
            We'll send a verification code to confirm your phone number
          <% end %>
        </p>
      </div>

      <%= if @mode != "proxy" do %>
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
            <.form
              for={%{}}
              phx-change="update_verification_code"
              phx-submit="verify_code"
              autocomplete="off"
            >
              <div class="form-control w-full">
                <label class="label">
                  <span class="label-text text-lg dark:text-gray-300">Verification Code *</span>
                </label>
                <div class="flex flex-col gap-3 w-full">
                  <input
                    id="verification-code-input"
                    name="verification_code"
                    type="text"
                    inputmode="numeric"
                    pattern="[0-9]*"
                    placeholder="Enter 6-digit code"
                    maxlength="6"
                    autocomplete="one-time-code"
                    data-form-type="other"
                    class={"input input-bordered input-lg w-full text-lg dark:bg-base-100 dark:text-white #{if @verification_code_error, do: "input-error"}"}
                    value={@verification_code}
                  />
                  <button
                    type="submit"
                    class="btn btn-primary btn-lg rounded-full w-full"
                    disabled={String.length(@verification_code) != 6}
                  >
                    Verify
                  </button>
                </div>
                <%= if @verification_code_error do %>
                  <div class="mt-3">
                    <div class="badge badge-error badge-lg p-4 text-base">
                      <.icon name="hero-x-circle" class="w-5 h-5 mr-2" />
                      {@verification_code_error}
                    </div>
                  </div>
                <% end %>
                <label class="label">
                  <button
                    type="button"
                    phx-click="send_verification_code"
                    class="label-text-alt link link-primary text-base"
                  >
                    Resend code
                  </button>
                </label>
              </div>
            </.form>
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
                      {format_phone_number(@mobile_number)}
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

  attr :alias, :string, required: true
  attr :alias_error, :string, default: nil
  attr :base_names, :list, required: true
  attr :available_numbers, :list, required: true
  attr :selected_base, :string, default: nil
  attr :selected_number, :string, default: nil

  defp step_two(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h2 class="text-2xl md:text-3xl font-bold mb-3 dark:text-white">Choose Your Alias</h2>
        <p class="text-base md:text-lg text-base-content/70 dark:text-base-content/60">
          Select a unique name and number combination. This will be your username and display name.
        </p>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <%!-- Left Column: Base Names --%>
        <div class="space-y-3">
          <div class="flex justify-between items-center">
            <label class="label-text text-lg dark:text-gray-300 font-medium">
              Select a name:
            </label>
            <button
              type="button"
              phx-click="regenerate_base_names"
              class="btn btn-sm btn-ghost gap-1"
              title="Generate new names"
            >
              <.icon name="hero-arrow-path" class="w-4 h-4" />
              <span class="hidden sm:inline">New Names</span>
            </button>
          </div>

          <div class="space-y-2">
            <%= for base_name <- @base_names do %>
              <button
                type="button"
                phx-click="select_base_name"
                phx-value-base_name={base_name}
                class={[
                  "w-full p-3 rounded-lg text-left transition-all border-2",
                  if(@selected_base == base_name,
                    do: "bg-primary/20 border-primary dark:bg-primary/30 dark:border-primary",
                    else:
                      "bg-base-200 border-base-300 hover:bg-base-300 dark:bg-base-100 dark:border-base-200"
                  )
                ]}
              >
                <div class="flex items-center gap-2">
                  <%= if @selected_base == base_name do %>
                    <.icon name="hero-check-circle-solid" class="w-5 h-5 text-primary" />
                  <% else %>
                    <.icon name="hero-circle" class="w-5 h-5 text-base-content/30" />
                  <% end %>
                  <span class="font-medium text-base dark:text-white">{base_name}</span>
                </div>
              </button>
            <% end %>
          </div>
        </div>

        <%!-- Right Column: Numbers --%>
        <div class="space-y-3">
          <div class="flex justify-between items-center">
            <label class="label-text text-lg dark:text-gray-300 font-medium">
              Choose a number:
            </label>
            <%= if @selected_base do %>
              <button
                type="button"
                phx-click="regenerate_numbers"
                class="btn btn-sm btn-ghost gap-1"
                title="Generate new numbers"
              >
                <.icon name="hero-arrow-path" class="w-4 h-4" />
                <span class="hidden sm:inline">New Numbers</span>
              </button>
            <% end %>
          </div>

          <%= if is_nil(@selected_base) do %>
            <div class="flex items-center justify-center h-full min-h-[200px] bg-base-200 dark:bg-base-100 rounded-lg border-2 border-dashed border-base-300">
              <p class="text-base-content/50 text-center px-4">
                Select a name first
              </p>
            </div>
          <% else %>
            <div class="space-y-2">
              <%= for number <- @available_numbers do %>
                <button
                  type="button"
                  phx-click="select_number"
                  phx-value-number={number}
                  class={[
                    "w-full p-3 rounded-lg text-left transition-all border-2",
                    if(@selected_number == number,
                      do: "bg-primary/20 border-primary dark:bg-primary/30 dark:border-primary",
                      else:
                        "bg-base-200 border-base-300 hover:bg-base-300 dark:bg-base-100 dark:border-base-200"
                    )
                  ]}
                >
                  <div class="flex items-center gap-2">
                    <%= if @selected_number == number do %>
                      <.icon name="hero-check-circle-solid" class="w-5 h-5 text-primary" />
                    <% else %>
                      <.icon name="hero-circle" class="w-5 h-5 text-base-content/30" />
                    <% end %>
                    <span class="font-mono font-medium text-base dark:text-white">-{number}</span>
                  </div>
                </button>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>

      <%!-- Preview --%>
      <%= if @alias != "" do %>
        <div class="mt-6 p-4 bg-base-200 dark:bg-base-100 rounded-lg border border-base-300">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm text-base-content/70 dark:text-base-content/60">Your alias:</p>
              <p class="text-2xl font-bold text-primary dark:text-primary mt-1">{@alias}</p>
            </div>
            <div class="badge badge-success badge-lg gap-2">
              <.icon name="hero-check-circle" class="w-5 h-5" /> Available
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp step_three(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h2 class="text-2xl md:text-3xl font-bold mb-3 dark:text-white">Core MeFile Data</h2>
        <div class="alert alert-warning">
          <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
          <span class="text-base">
            <strong>Important:</strong>
            Birthdate and Sex cannot be changed later. Please ensure accuracy.
          </span>
        </div>
      </div>

      <.form for={%{}} phx-change="select_sex">
        <div class="form-control w-full">
          <label class="label">
            <span class="label-text text-lg dark:text-gray-300">Sex (Biological) *</span>
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

      <.form for={%{}} phx-change="update_birthdate">
        <div class="form-control w-full">
          <label class="label">
            <span class="label-text text-lg dark:text-gray-300">Birthdate *</span>
          </label>
          <div class="flex gap-2">
            <input
              id="birthdate-year"
              name="year"
              type="text"
              placeholder="YYYY"
              maxlength="4"
              class={"input input-bordered input-lg flex-1 text-lg dark:bg-base-100 dark:text-white #{if @birthdate_error, do: "input-error"}"}
              value={@birthdate_year}
            />
            <input
              id="birthdate-month"
              name="month"
              type="text"
              placeholder="MM"
              maxlength="2"
              class={"input input-bordered input-lg w-24 text-lg dark:bg-base-100 dark:text-white #{if @birthdate_error, do: "input-error"}"}
              value={@birthdate_month}
            />
            <input
              id="birthdate-day"
              name="day"
              type="text"
              placeholder="DD"
              maxlength="2"
              class={"input input-bordered input-lg w-24 text-lg dark:bg-base-100 dark:text-white #{if @birthdate_error, do: "input-error"}"}
              value={@birthdate_day}
            />
          </div>
          <%= if @birthdate_error do %>
            <div class="mt-3">
              <div class="badge badge-error badge-lg p-4 text-base">
                <.icon name="hero-x-circle" class="w-5 h-5 mr-2" />
                {@birthdate_error}
              </div>
            </div>
          <% end %>
          <%= if @birthdate_valid and @calculated_age do %>
            <div class="mt-3">
              <div class="badge badge-primary badge-lg p-4 text-base">
                <.icon name="hero-calendar" class="w-5 h-5 mr-2" /> Age: {@calculated_age}
              </div>
            </div>
          <% end %>
        </div>
      </.form>

      <.form for={%{}} phx-change="lookup_zip_code" phx-debounce="500">
        <div class="form-control w-full">
          <label class="label">
            <span class="label-text text-lg dark:text-gray-300">
              Home Zip Code (optional, but encouraged)
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
              <div class="badge badge-error badge-lg p-4 text-base">
                <.icon name="hero-x-circle" class="w-5 h-5 mr-2" />
                {@zip_lookup_error}
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

  defp step_four(assigns) do
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
            {Enum.find(@sex_options, fn opt -> opt.id == @sex_trait_id end).name}
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
      </div>

      <div class="form-control mt-4">
        <label class="cursor-pointer flex items-start gap-3 p-3 bg-base-200 dark:bg-base-200 rounded-lg">
          <input
            type="checkbox"
            class="checkbox checkbox-primary flex-shrink-0 mt-0.5"
            checked={@confirmation_checked}
            phx-click="toggle_confirmation"
            phx-value-checked={to_string(!@confirmation_checked)}
          />
          <span class="text-sm md:text-base dark:text-gray-300">
            I confirm my birthdate and sex are correct and understand the data values cannot be changed later.
          </span>
        </label>
      </div>

      <%= if not @can_complete do %>
        <div class="alert alert-warning py-3">
          <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
          <span class="text-sm">Please check the confirmation box to complete registration.</span>
        </div>
      <% end %>
    </div>
    """
  end

  defp format_phone_number(phone_number) when is_binary(phone_number) do
    digits = String.replace(phone_number, ~r/\D/, "")

    case String.length(digits) do
      10 ->
        <<area::binary-size(3), prefix::binary-size(3), line::binary-size(4)>> = digits
        "#{area}-#{prefix}-#{line}"

      _ ->
        phone_number
    end
  end

  defp format_phone_number(_), do: ""
end
