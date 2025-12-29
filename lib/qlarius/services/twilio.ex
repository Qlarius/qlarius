defmodule Qlarius.Services.Twilio do
  @moduledoc """
  Twilio integration for SMS verification and carrier lookup.

  ## Carrier Whitelist

  The `@allowed_carriers` list defines which mobile carriers are accepted
  during registration. Carrier names must match Twilio's Line Type Intelligence
  API response format (e.g., "AT&T Wireless", not "AT&T").

  ### Updating the Whitelist:

  1. Edit the `@allowed_carriers` list below (around line 35)
  2. Use exact carrier names as returned by Twilio API
  3. Run `mix compile` to apply changes
  4. Restart server for changes to take effect

  ### Finding New Carrier Names:

  When a carrier is rejected, check your logs for:
  ```
  [warning] Carrier not in whitelist carrier=<name> phone_number=<number>
  ```

  Review these logs periodically to identify legitimate carriers to add.

  ### Current Whitelist:

  - Major carriers: AT&T Wireless, Verizon Wireless, T-Mobile USA, Sprint
  - MVNOs: Cricket, Boost, Metro, Visible, Mint, Google Fi, Xfinity, Consumer Cellular

  Note: Matching uses partial, case-insensitive string comparison for flexibility.
  """

  require Logger

  @verify_url "https://verify.twilio.com/v2"
  @lookup_url "https://lookups.twilio.com/v2"

  @allowed_carriers [
    "AT&T Wireless",
    "Verizon Wireless",
    "T-Mobile USA",
    "Sprint",
    "Sprint Spectrum",
    "US Cellular",
    "Metro by T-Mobile",
    "MetroPCS",
    "Cricket Wireless",
    "Boost Mobile",
    "Visible",
    "Mint Mobile",
    "Google Fi",
    "Xfinity Mobile",
    "Comcast",
    "Consumer Cellular"
  ]

  defp get_config do
    Application.get_env(:qlarius, __MODULE__, [])
  end

  defp verify_service_sid, do: Keyword.get(get_config(), :verify_service_sid)
  defp account_sid, do: Keyword.get(get_config(), :account_sid)
  defp auth_token, do: Keyword.get(get_config(), :auth_token)

  def allowed_carriers, do: @allowed_carriers

  def send_verification_code(phone_number) do
    url = "#{@verify_url}/Services/#{verify_service_sid()}/Verifications"

    body = %{
      "To" => phone_number,
      "Channel" => "sms"
    }

    case post(url, body) do
      {:ok, %{status: 201, body: response}} ->
        {:ok, response}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Twilio verification failed: #{status} - #{inspect(body)}")
        {:error, :twilio_error}

      {:error, reason} ->
        Logger.error("Twilio request failed: #{inspect(reason)}")
        {:error, :network_error}
    end
  end

  def verify_code(phone_number, code) do
    url = "#{@verify_url}/Services/#{verify_service_sid()}/VerificationCheck"

    body = %{
      "To" => phone_number,
      "Code" => code
    }

    case post(url, body) do
      {:ok, %{status: 200, body: %{"status" => "approved"}}} ->
        {:ok, :verified}

      {:ok, %{status: 200, body: %{"status" => status}}} ->
        {:error, String.to_atom(status)}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Twilio verification check failed: #{status} - #{inspect(body)}")
        {:error, :verification_failed}

      {:error, reason} ->
        Logger.error("Twilio request failed: #{inspect(reason)}")
        {:error, :network_error}
    end
  end

  def lookup_phone_carrier(phone_number) do
    url = "#{@lookup_url}/PhoneNumbers/#{URI.encode(phone_number)}"

    query_params = [
      {"Fields", "line_type_intelligence"}
    ]

    case get(url, query_params) do
      {:ok, %{status: 200, body: response}} ->
        carrier_info = %{
          type: get_in(response, ["line_type_intelligence", "type"]),
          carrier_name: get_in(response, ["line_type_intelligence", "carrier_name"]),
          mobile_country_code:
            get_in(response, ["line_type_intelligence", "mobile_country_code"]),
          mobile_network_code:
            get_in(response, ["line_type_intelligence", "mobile_network_code"]),
          country_code: response["country_code"],
          national_format: response["national_format"],
          valid: response["valid"],
          error_code: get_in(response, ["line_type_intelligence", "error_code"])
        }

        {:ok, carrier_info}

      {:ok, %{status: 404}} ->
        {:error, :invalid_number}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Twilio lookup failed: #{status} - #{inspect(body)}")
        {:error, :lookup_failed}

      {:error, reason} ->
        Logger.error("Twilio request failed: #{inspect(reason)}")
        {:error, :network_error}
    end
  end

  def validate_carrier(phone_number) do
    if skip_carrier_validation?() do
      Logger.warning("Carrier validation SKIPPED (dev mode)", phone_number: phone_number)

      {:ok,
       %{
         type: "mobile",
         carrier_name: "DEV MODE - Validation Skipped",
         country_code: "US",
         valid: true,
         mobile_country_code: nil,
         mobile_network_code: nil,
         national_format: phone_number,
         error_code: nil
       }}
    else
      do_validate_carrier(phone_number)
    end
  end

  defp do_validate_carrier(phone_number) do
    case lookup_phone_carrier(phone_number) do
      {:ok, %{valid: false}} ->
        {:error, :invalid_number, "This phone number appears to be invalid"}

      {:ok, %{country_code: country}} when country != "US" ->
        {:error, :non_us_number, "We currently only support US phone numbers"}

      {:ok, %{type: "voip"}} ->
        {:error, :voip_not_allowed,
         "VOIP numbers are not supported. Please use a mobile number from a major carrier"}

      {:ok, %{type: "landline"}} ->
        {:error, :landline_not_allowed,
         "Landline numbers are not supported. Please use a mobile number"}

      {:ok, %{type: "mobile", carrier_name: nil}} ->
        {:error, :unknown_carrier,
         "Unable to verify carrier. Please ensure you're using a major US carrier"}

      {:ok, %{type: "mobile", carrier_name: carrier} = info} ->
        if carrier_allowed?(carrier) do
          {:ok, info}
        else
          Logger.warning("Carrier not in whitelist",
            carrier: carrier,
            phone_number: phone_number,
            full_info: inspect(info)
          )

          {:error, :carrier_not_allowed,
           "We currently only support major US carriers. Your carrier: #{carrier}"}
        end

      {:ok, %{type: type}} ->
        Logger.warning("Unknown carrier type: #{type}")
        {:error, :unknown_type, "Unable to verify this phone number type"}

      {:error, :invalid_number} ->
        {:error, :invalid_number, "This phone number is not valid"}

      {:error, reason} ->
        Logger.error("Carrier validation failed: #{inspect(reason)}")
        {:error, :lookup_failed, "Unable to verify phone number. Please try again"}
    end
  end

  defp skip_carrier_validation? do
    Application.get_env(:qlarius, :skip_carrier_validation, false)
  end

  defp carrier_allowed?(carrier_name) when is_binary(carrier_name) do
    normalized_carrier = String.downcase(carrier_name)

    Enum.any?(@allowed_carriers, fn allowed ->
      normalized_allowed = String.downcase(allowed)

      String.contains?(normalized_carrier, normalized_allowed) or
        String.contains?(normalized_allowed, normalized_carrier)
    end)
  end

  defp carrier_allowed?(_), do: false

  defp post(url, body) do
    sid = to_string(account_sid() || "")
    token = to_string(auth_token() || "")
    auth_header = "Basic " <> Base.encode64("#{sid}:#{token}")

    Req.post(url,
      headers: [{"authorization", auth_header}],
      form: body,
      decode_body: true
    )
  end

  defp get(url, query_params) do
    sid = to_string(account_sid() || "")
    token = to_string(auth_token() || "")
    auth_header = "Basic " <> Base.encode64("#{sid}:#{token}")

    Req.get(url,
      headers: [{"authorization", auth_header}],
      params: query_params,
      decode_body: true
    )
  end
end
