defmodule Qlarius.ApiRef do
  @moduledoc """
  The caller-supplied key that makes admin API creates idempotent.

  Rows created through the admin API carry an `api_ref`; rows created in the
  UI leave it nil. Uniqueness is enforced per table by a partial unique index.
  """

  import Ecto.Changeset

  @format ~r/\A[a-z0-9][a-z0-9._-]{2,127}\z/

  def format, do: @format

  def valid?(ref) when is_binary(ref), do: Regex.match?(@format, ref)
  def valid?(_), do: false

  def validate(changeset) do
    changeset
    |> validate_format(:api_ref, @format,
      message: "must be 3 to 128 characters of lowercase letters, digits, '-', '_' or '.'"
    )
    |> unique_constraint(:api_ref)
  end

  @doc """
  The scope a PTP coverage report groups by, read from the area segment of
  `<program>-<yymm>-<brand>[-<area>].<type>` keys. Brand slugs use underscores,
  so everything after the third hyphen is the area.
  """
  def scope(ref) do
    case area(ref) do
      nil -> "unscoped"
      "nat" -> "national"
      "niche-" <> _ -> "niche"
      _ -> "local"
    end
  end

  def area(ref) when is_binary(ref) do
    base = ref |> String.split(".", parts: 2) |> hd()

    case String.split(base, "-", parts: 4) do
      [_program, _yymm, _brand, area] when area != "" -> area
      _ -> nil
    end
  end

  def area(_), do: nil
end
