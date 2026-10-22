defmodule QlariusWeb.MeFileTagExportPanel do
  @moduledoc """
  Settings panel that texts a 6-digit code to the account owner, then shows
  the MeFile tag export for the MeFile currently in use.
  """

  use QlariusWeb, :live_component

  import QlariusWeb.Components.CustomComponentsMobile, only: [otp_input: 1]

  alias Qlarius.Auth.AuditLog
  alias Qlarius.Auth.RateLimit
  alias Qlarius.MeCP
  alias Qlarius.Services.Twilio
  alias Qlarius.YouData.MeFileTagExport

  @max_attempts 5

  @impl true
  def update(assigns, socket) do
    phone = assigns.current_scope.true_user.mobile_number_encrypted

    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:phase, fn -> :locked end)
     |> assign_new(:code, fn -> "" end)
     |> assign_new(:error, fn -> nil end)
     |> assign_new(:challenge, fn -> nil end)
     |> assign_new(:attempts, fn -> 0 end)
     |> assign_new(:json, fn -> nil end)
     |> assign(:masked_phone, mask_phone(phone))
     |> assign(:has_phone?, is_binary(phone) and phone != "")
     |> assign(:proxy_notice?, acting_as_proxy?(assigns.current_scope))}
  end

  @impl true
  def handle_event("send_export_code", _params, socket) do
    phone = socket.assigns.current_scope.true_user.mobile_number_encrypted

    cond do
      not socket.assigns.has_phone? ->
        {:noreply, assign(socket, :error, "No mobile number on this account.")}

      rate_limited?(phone) ->
        AuditLog.log(:"send_code.denied", %{
          phone: phone,
          ip: "0.0.0.0",
          surface: "me_file_tag_export",
          reason: :phone_limit
        })

        {:noreply, assign(socket, :error, "Too many codes. Try again in a few minutes.")}

      true ->
        send_code(socket, phone)
    end
  end

  def handle_event("update_export_code", %{"verification_code" => code}, socket) do
    {:noreply, socket |> assign(:code, code) |> assign(:error, nil)}
  end

  def handle_event("verify_export_code", %{"code" => code}, socket) do
    phone = socket.assigns.current_scope.true_user.mobile_number_encrypted

    case accept_code(socket.assigns, code, phone) do
      :ok ->
        unlock(socket)

      :expired ->
        {:noreply,
         socket
         |> assign(:phase, :locked)
         |> assign(:challenge, nil)
         |> assign(:code, "")
         |> assign(:error, "That code expired. Send a new one.")}

      :invalid ->
        attempts = socket.assigns.attempts + 1

        if attempts >= @max_attempts do
          {:noreply,
           socket
           |> assign(:phase, :locked)
           |> assign(:challenge, nil)
           |> assign(:attempts, 0)
           |> assign(:code, "")
           |> assign(:error, "Too many tries. Send a new code.")}
        else
          {:noreply,
           socket
           |> assign(:attempts, attempts)
           |> assign(:code, "")
           |> assign(:error, "Invalid code. Try again.")}
        end
    end
  end

  defp send_code(socket, phone) do
    bypass = Application.get_env(:qlarius, :bypass_phone_verification, false)

    result =
      if bypass do
        {:ok, :bypass}
      else
        case Twilio.send_verification_code(phone) do
          {:ok, _} -> {:ok, :twilio}
          {:error, _} -> :error
        end
      end

    case result do
      {:ok, challenge} ->
        AuditLog.log(:"send_code.allowed", %{
          phone: phone,
          ip: "0.0.0.0",
          surface: "me_file_tag_export"
        })

        {:noreply,
         socket
         |> assign(:phase, :code_sent)
         |> assign(:challenge, challenge)
         |> assign(:code, "")
         |> assign(:attempts, 0)
         |> assign(:error, nil)}

      :error ->
        AuditLog.log(:"send_code.denied", %{
          phone: phone,
          ip: "0.0.0.0",
          surface: "me_file_tag_export",
          reason: :twilio_error
        })

        {:noreply, assign(socket, :error, "Couldn't send the code. Try again.")}
    end
  end

  defp unlock(socket) do
    scope = socket.assigns.current_scope

    case scope.user.me_file do
      %{id: id} ->
        json =
          id
          |> MeCP.load_me_file()
          |> MeFileTagExport.to_json(mobile_number: scope.true_user.mobile_number_encrypted)

        AuditLog.log(:"verify_code.allowed", %{
          phone: scope.true_user.mobile_number_encrypted,
          ip: "0.0.0.0",
          surface: "me_file_tag_export",
          outcome: :tag_export
        })

        {:noreply,
         socket
         |> assign(:phase, :unlocked)
         |> assign(:json, json)
         |> assign(:challenge, nil)
         |> assign(:code, "")
         |> assign(:error, nil)}

      _ ->
        {:noreply, assign(socket, :error, "No MeFile to export.")}
    end
  end

  # Dev skips Twilio (`bypass_phone_verification`) and accepts the same
  # stand-in code as sign-in. Production asks Twilio, which sends 6 digits.
  defp accept_code(%{phase: :code_sent, challenge: :bypass}, "000000", _phone), do: :ok
  defp accept_code(%{phase: :code_sent, challenge: :bypass}, _code, _phone), do: :invalid

  defp accept_code(%{phase: :code_sent, challenge: :twilio}, code, phone) do
    case Twilio.verify_code(phone, code) do
      {:ok, :verified} -> :ok
      {:error, :expired} -> :expired
      _ -> :invalid
    end
  end

  defp accept_code(_assigns, _code, _phone), do: :invalid

  defp rate_limited?(phone) do
    RateLimit.check_send_code_per_phone(phone) != :ok
  end

  defp mask_phone(phone) when is_binary(phone) and phone != "" do
    case String.replace(phone, ~r/\D/, "") |> String.slice(-4, 4) do
      last4 when is_binary(last4) and byte_size(last4) == 4 -> "···" <> last4
      _ -> nil
    end
  end

  defp mask_phone(_), do: nil

  # Proxy personas belong to admins. The text still goes to the admin's phone,
  # so say so only while that admin is actually using a proxy.
  defp acting_as_proxy?(%{true_user: %{id: admin_id, role: "admin"}, user: %{id: user_id}})
       when admin_id != user_id,
       do: true

  defp acting_as_proxy?(_scope), do: false

  @impl true
  def render(assigns) do
    ~H"""
    <div class="pb-8 w-full max-w-2xl mx-auto flex flex-col gap-4">
      <.surface_panel>
        <h2 class="text-xl font-bold tracking-tight text-base-content flex items-center gap-2 mb-2">
          <.icon name="hero-arrow-down-tray" class="w-5 h-5" /> MeFile Tag Export
        </h2>
        <p class="text-sm text-base-content/70 mb-4">
          A JSON copy of this MeFile's tags, grouped the same way MeCP reads them
          (category, trait, values). It does not include your mobile number or other
          account details.
        </p>
        <div class="alert alert-info mb-4">
          <.icon name="hero-information-circle" class="w-5 h-5" />
          <span class="text-sm">
            Be considerate about how you use and share this. Your tags are zero-party
            data, and they are usually best kept zero-party. Most systems can use a
            secure MeCP connection, so the data stays under your control. An export
            is a copy that leaves with you.
          </span>
        </div>

        <%= cond do %>
          <% @phase == :unlocked -> %>
            <label for="mefile-tag-export" class="mb-2 block text-sm font-medium text-base-content/70">
              Select the text and copy it.
            </label>
            <textarea
              id="mefile-tag-export"
              readonly
              rows="18"
              spellcheck="false"
              class="w-full rounded-lg border border-base-300 bg-base-200 p-3 font-mono text-xs text-base-content"
            >{@json}</textarea>
          <% not @has_phone? -> %>
            <p class="text-sm text-base-content/70">
              Add a mobile number to this account before exporting tags.
            </p>
          <% true -> %>
            <p class="text-sm text-base-content/70 mb-4">
              Text a 6-digit code to the mobile number on this account
              <%= if @masked_phone do %>
                ({@masked_phone})
              <% end %>
              to show the export.
              <span :if={@proxy_notice?}>
                While you are acting as a proxy, the code still goes to your phone.
              </span>
            </p>
            <button
              type="button"
              phx-click="send_export_code"
              phx-target={@myself}
              class="btn btn-primary"
            >
              {if @phase == :code_sent, do: "Send a new code", else: "Text me a code"}
            </button>
            <p :if={@error && @phase == :locked} class="mt-3 text-sm text-error">{@error}</p>
            <div :if={@phase == :code_sent} class="mt-6">
              <.otp_input
                id={"#{@id}-code"}
                value={@code}
                error={@error}
                length={6}
                verify_event="verify_export_code"
                update_event="update_export_code"
                aria_label="Enter the 6-digit code"
              />
            </div>
        <% end %>
      </.surface_panel>
    </div>
    """
  end
end
