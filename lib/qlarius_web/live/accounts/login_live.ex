defmodule QlariusWeb.LoginLive do
  use QlariusWeb, :live_view

  alias Qlarius.{Auth, Accounts}
  import QlariusWeb.PWAHelpers

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Sign In")
      |> assign(:mobile_number, "")
      |> assign(:mobile_number_error, nil)
      |> assign(:verification_code, "")
      |> assign(:verification_code_error, nil)
      |> assign(:code_sent, false)
      |> assign(:show_biometric, false)
      |> assign(:is_pwa, false)
      |> assign(:device_type, :desktop)

    {:ok, socket}
  end

  def handle_event("pwa_detected", params, socket) do
    handle_pwa_detection(socket, params)
  end

  def handle_event("update_mobile", %{"value" => mobile}, socket) do
    {:noreply,
     socket
     |> assign(:mobile_number, mobile)
     |> assign(:mobile_number_error, nil)}
  end

  def handle_event("send_login_code", _params, socket) do
    phone = socket.assigns.mobile_number
    formatted_phone = if String.starts_with?(phone, "+"), do: phone, else: "+1#{phone}"

    case Auth.get_user_by_phone(formatted_phone) do
      nil ->
        {:noreply,
         socket
         |> assign(:mobile_number_error, "No account found with this number")
         |> put_flash(:error, "No account found. Please register first.")}

      _user ->
        case Qlarius.Services.Twilio.send_verification_code(formatted_phone) do
          {:ok, _response} ->
            {:noreply,
             socket
             |> assign(:code_sent, true)
             |> assign(:mobile_number_error, nil)
             |> push_event("focus", %{id: "verification-code-input"})
             |> put_flash(:info, "Verification code sent")}

          {:error, _reason} ->
            {:noreply,
             socket
             |> assign(:mobile_number_error, "Failed to send code")
             |> put_flash(:error, "Failed to send SMS. Please try again.")}
        end
    end
  end

  def handle_event("update_verification_code", %{"value" => code}, socket) do
    {:noreply,
     socket
     |> assign(:verification_code, code)
     |> assign(:verification_code_error, nil)}
  end

  def handle_event("verify_login_code", _params, socket) do
    phone = socket.assigns.mobile_number
    code = socket.assigns.verification_code
    formatted_phone = if String.starts_with?(phone, "+"), do: phone, else: "+1#{phone}"

    case Qlarius.Services.Twilio.verify_code(formatted_phone, code) do
      {:ok, :verified} ->
        case Auth.get_user_by_phone(formatted_phone) do
          nil ->
            {:noreply,
             socket
             |> put_flash(:error, "Account not found")
             |> assign(:code_sent, false)}

          user ->
            token = Accounts.generate_user_login_token(user.id)

            {:noreply,
             socket
             |> put_flash(:info, "Welcome back!")
             |> redirect(to: ~p"/auto_login/#{token}")}
        end

      {:error, _reason} ->
        {:noreply,
         socket
         |> assign(:verification_code_error, "Invalid code entered. Please try again.")
         |> put_flash(:error, "Invalid verification code")}
    end
  end

  def render(assigns) do
    ~H"""
    <div
      id="login-pwa-detect"
      phx-hook="HiPagePWADetect"
      class="min-h-screen flex items-center justify-center px-4 relative"
    >
      <div class="absolute top-12 left-0 right-0 flex justify-center">
        <img
          src="/images/qadabra_full_gray_opt.svg"
          alt="Qadabra"
          class="h-12 md:h-16 w-auto"
        />
      </div>

      <div class="max-w-md w-full space-y-8 px-6 md:px-8">
        <div>
          <h1 class="text-4xl md:text-5xl font-bold text-center dark:text-white">
            Sign In
          </h1>
          <p class="mt-2 text-center text-base md:text-lg text-base-content/70">
            Enter your mobile number to continue
          </p>
        </div>

        <div class="space-y-6">
          <%= if not @code_sent do %>
            <.form
              for={%{}}
              phx-change="update_mobile"
              phx-submit="send_login_code"
              autocomplete="off"
            >
              <div class="form-control w-full">
                <label class="label">
                  <span class="label-text text-lg dark:text-gray-300">Mobile Number</span>
                </label>
                <div class="flex flex-col gap-3 w-full">
                  <input
                    id="mobile-input"
                    name="value"
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
                  />
                  <button
                    type="submit"
                    class="btn btn-primary btn-lg rounded-full w-full"
                    disabled={String.length(@mobile_number) != 10}
                  >
                    Send Code
                  </button>
                </div>
                <%= if @mobile_number_error do %>
                  <div class="mt-3">
                    <div class="badge badge-error badge-lg p-4 text-base">
                      <.icon name="hero-x-circle" class="w-5 h-5 mr-2" />
                      {@mobile_number_error}
                    </div>
                  </div>
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
          <% else %>
            <div class="alert alert-info">
              <.icon name="hero-information-circle" class="w-6 h-6" />
              <span>Verification code sent to {format_phone_number(@mobile_number)}</span>
            </div>

            <.form
              for={%{}}
              phx-change="update_verification_code"
              phx-submit="verify_login_code"
              autocomplete="off"
            >
              <div class="form-control w-full">
                <label class="label">
                  <span class="label-text text-lg dark:text-gray-300">Verification Code</span>
                </label>
                <div class="flex flex-col gap-3 w-full">
                  <input
                    id="verification-code-input"
                    name="value"
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
                    phx-click="send_login_code"
                    class="label-text-alt link link-primary text-base"
                  >
                    Resend code
                  </button>
                </label>
              </div>
            </.form>
          <% end %>

          <div class="text-center">
            <p class="text-base">
              Don't have an account?
              <.link navigate={~p"/register"} class="link link-primary">Register</.link>
            </p>
          </div>
        </div>
      </div>
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
