defmodule QlariusWeb.BirthdateRules do
  @moduledoc false

  alias Qlarius.YouData.MeFiles

  @min_age 16
  @max_age 120

  def min_age, do: @min_age
  def max_age, do: @max_age

  @doc """
  Validates MM/DD/YYYY strings. Returns
  `{:ok, age, age_trait_id}` or `{:error, error_message, age | nil}`.
  """
  def evaluate(year_str, month_str, day_str) do
    all_digits_entered =
      String.length(month_str) == 2 and String.length(day_str) == 2 and
        String.length(year_str) == 4

    with true <- String.length(year_str) == 4,
         {year_int, ""} <- Integer.parse(year_str),
         true <- String.length(month_str) == 2,
         {month_int, ""} <- Integer.parse(month_str),
         true <- month_int in 1..12,
         true <- String.length(day_str) == 2,
         {day_int, ""} <- Integer.parse(day_str),
         true <- day_int in 1..31,
         {:ok, date} <- Date.new(year_int, month_int, day_int) do
      age = MeFiles.calculate_age(date)

      cond do
        is_nil(age) ->
          {:error, if(all_digits_entered, do: "Date entered is invalid", else: nil), nil}

        age < @min_age ->
          {:error, "Must be #{@min_age} or older", age}

        age > @max_age ->
          {:error,
           "That birthdate would mean age #{age}. Please enter a year so age is between #{@min_age} and #{@max_age}.",
           age}

        true ->
          age_trait = MeFiles.get_age_trait_for_age(age)
          {:ok, age, if(age_trait, do: age_trait.id, else: nil)}
      end
    else
      _ ->
        {:error, if(all_digits_entered, do: "Date entered is invalid", else: nil), nil}
    end
  end
end
