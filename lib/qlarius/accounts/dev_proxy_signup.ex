defmodule Qlarius.Accounts.DevProxySignup do
  @moduledoc """
  Local-dev hook: a configured trigger phone starts a normal signup
  attached as a proxy under a configured true-user alias.

  Enabled only when `bypass_phone_verification` is true **and**
  `:dev_proxy_signup` is configured with both keys. Never keys off
  hostname. The trigger phone is not persisted on the new user.
  """

  alias Qlarius.Accounts
  alias Qlarius.Accounts.User

  @type resolve_result :: {:ok, User.t()} | {:error, :true_user_missing} | :ignore

  def enabled? do
    Application.get_env(:qlarius, :bypass_phone_verification, false) == true and
      not is_nil(config())
  end

  @doc """
  If this phone is the configured trigger, look up the true user by alias.

  Returns `:ignore` when the hook is off or the phone does not match.
  """
  @spec resolve_true_user(term()) :: resolve_result()
  def resolve_true_user(phone) do
    with true <- enabled?(),
         %{trigger_phone: trigger, true_user_alias: user_alias} <- config(),
         true <- digits_match?(phone, trigger) do
      case Accounts.get_user_by_alias(user_alias) do
        %User{} = user -> {:ok, user}
        nil -> {:error, :true_user_missing}
      end
    else
      _ -> :ignore
    end
  end

  @doc """
  True when the hook is on and `phone` is the trigger. Callers must not
  persist that number on the new user.
  """
  def omit_persisted_phone?(phone) do
    case config() do
      %{trigger_phone: trigger} ->
        enabled?() and digits_match?(phone, trigger)

      _ ->
        false
    end
  end

  def missing_true_user_message do
    case config() do
      %{true_user_alias: user_alias} ->
        "Parent user #{user_alias} was not found. Create that account first, then retry."

      _ ->
        "Parent user for proxy signup was not found. Create that account first, then retry."
    end
  end

  defp config do
    case Application.get_env(:qlarius, :dev_proxy_signup) do
      opts when is_list(opts) ->
        trigger = Keyword.get(opts, :trigger_phone)
        user_alias = Keyword.get(opts, :true_user_alias)
        build_config(trigger, user_alias)

      %{trigger_phone: trigger, true_user_alias: user_alias} ->
        build_config(trigger, user_alias)

      _ ->
        nil
    end
  end

  defp build_config(trigger, user_alias) do
    if present?(trigger) and present?(user_alias) do
      %{trigger_phone: trigger, true_user_alias: user_alias}
    else
      nil
    end
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_), do: false

  defp digits_match?(phone, trigger) do
    digits = normalize_digits(phone)
    digits != "" and digits == normalize_digits(trigger)
  end

  defp normalize_digits(phone) when is_binary(phone) do
    digits = String.replace(phone, ~r/\D/, "")

    if String.length(digits) == 11 and String.starts_with?(digits, "1") do
      String.slice(digits, 1, 10)
    else
      digits
    end
  end

  defp normalize_digits(_), do: ""
end
