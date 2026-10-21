defmodule Qlarius.YouData.MeFileTagExport do
  @moduledoc """
  A MeFile as portable JSON for the owner to copy out.

  The document is `Qlarius.MeCP.Export` (the same category > trait > values
  taxonomy MeCP capsules use). Account identifiers are never added: no mobile
  number, email, alias, user id, MeFile id, display name, birthdate, referral
  code, or token.

  Tag values that *are* the account mobile number, an email address, or a
  contact trait (phone, mobile, email) are removed, so the unlock phone
  cannot ride along inside a tag.
  """

  alias Qlarius.MeCP.Export
  alias Qlarius.YouData.MeFiles.MeFile

  @contact_trait ~r/phone|mobile|e-?mail/i
  @email_value ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/

  @doc """
  Pretty JSON for a preloaded MeFile. `mobile_number` is used only to strip
  matching tag values; it is not written into the document.
  """
  @spec to_json(MeFile.t(), keyword()) :: String.t()
  def to_json(%MeFile{} = me_file, opts \\ []) do
    mobile = Keyword.get(opts, :mobile_number)

    me_file
    |> Export.build(Keyword.take(opts, [:exported_at]))
    |> scrub(mobile)
    |> Jason.encode!(pretty: true)
  end

  @doc """
  Drops contact traits and any value that repeats `mobile_number` or is an
  email address. Empty traits and categories are removed.
  """
  def scrub(export, mobile_number) do
    mobile_key = mobile_key(mobile_number)

    update_in(export, ["me_file", "categories"], fn categories ->
      categories
      |> Enum.map(&scrub_category(&1, mobile_key))
      |> Enum.reject(&(&1["traits"] == []))
    end)
  end

  defp scrub_category(category, mobile_key) do
    traits =
      category["traits"]
      |> Enum.reject(&contact_trait?/1)
      |> Enum.map(&scrub_trait(&1, mobile_key))
      |> Enum.reject(&(&1["values"] == []))

    %{category | "traits" => traits}
  end

  defp scrub_trait(trait, mobile_key) do
    values = Enum.reject(trait["values"], &drop_value?(&1["value"], mobile_key))
    %{trait | "values" => values}
  end

  defp contact_trait?(%{"name" => name}) when is_binary(name) do
    Regex.match?(@contact_trait, name)
  end

  defp contact_trait?(_), do: false

  defp drop_value?(value, _mobile_key) when not is_binary(value), do: false

  defp drop_value?(value, mobile_key) do
    Regex.match?(@email_value, String.trim(value)) or contains_mobile?(value, mobile_key)
  end

  defp contains_mobile?(_value, nil), do: false

  defp contains_mobile?(value, mobile_key) do
    digits = digits(value)
    String.contains?(digits, mobile_key)
  end

  defp mobile_key(nil), do: nil

  defp mobile_key(phone) do
    case digits(phone) do
      digits when byte_size(digits) >= 10 -> String.slice(digits, -10, 10)
      _ -> nil
    end
  end

  defp digits(value), do: String.replace(to_string(value), ~r/\D/, "")
end
