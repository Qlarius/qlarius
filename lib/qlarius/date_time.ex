defmodule Qlarius.DateTime do
  @moduledoc """
  DateTime conversion and formatting helpers with timezone support.
  """

  alias Qlarius.Accounts.User
  alias Qlarius.Timezones

  def to_user_timezone(%DateTime{} = datetime, %User{timezone: timezone}) when is_binary(timezone) do
    to_timezone(datetime, timezone)
  end

  def to_user_timezone(%DateTime{} = datetime, %User{timezone: nil}) do
    to_timezone(datetime, Timezones.default())
  end

  def to_user_timezone(%NaiveDateTime{} = naive_datetime, user) do
    naive_datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> to_user_timezone(user)
  end

  def to_timezone(%DateTime{} = datetime, timezone) do
    Timex.Timezone.convert(datetime, timezone)
  end

  def to_timezone(%NaiveDateTime{} = naive_datetime, timezone) do
    naive_datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> to_timezone(timezone)
  end

  def format_for_user(datetime, user, format \\ :standard)

  def format_for_user(%DateTime{} = datetime, user, format) do
    datetime
    |> to_user_timezone(user)
    |> format_datetime(format)
  end

  def format_for_user(%NaiveDateTime{} = naive_datetime, user, format) do
    naive_datetime
    |> to_user_timezone(user)
    |> format_datetime(format)
  end

  def format_for_user(nil, _user, _format), do: "-"

  def format_datetime(%DateTime{} = datetime, :standard) do
    Timex.format!(datetime, "%b %d, %Y %I:%M %p %Z", :strftime)
  end

  def format_datetime(%DateTime{} = datetime, :short) do
    Timex.format!(datetime, "%b %d %I:%M %p", :strftime)
  end

  def format_datetime(%DateTime{} = datetime, :date_only) do
    Timex.format!(datetime, "%b %d, %Y", :strftime)
  end

  def format_datetime(%DateTime{} = datetime, :time_only) do
    Timex.format!(datetime, "%I:%M %p %Z", :strftime)
  end

  def format_datetime(%DateTime{} = datetime, :iso) do
    DateTime.to_iso8601(datetime)
  end

  def format_utc(%DateTime{} = datetime) do
    datetime
    |> Timex.Timezone.convert("Etc/UTC")
    |> Timex.format!("%I:%M %p UTC", :strftime)
  end

  def format_utc(%NaiveDateTime{} = naive_datetime) do
    naive_datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> format_utc()
  end

  def format_utc(nil), do: "-"

  def current_hour_in_timezone(timezone) do
    DateTime.utc_now()
    |> to_timezone(timezone)
    |> Map.get(:hour)
  end

  def to_utc(%DateTime{} = datetime) do
    Timex.Timezone.convert(datetime, "Etc/UTC")
  end

  def to_utc(%NaiveDateTime{} = naive_datetime, from_timezone) do
    naive_datetime
    |> Timex.to_datetime(from_timezone)
    |> to_utc()
  end

  def current_time_in_timezone(timezone) do
    DateTime.utc_now()
    |> to_timezone(timezone)
    |> Timex.format!("%I:%M %p %Z", :strftime)
  end
end
