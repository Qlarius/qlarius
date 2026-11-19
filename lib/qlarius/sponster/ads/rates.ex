defmodule Qlarius.Sponster.Ads.Rates do
  @moduledoc false

  @default_video_publisher_credit_amt Decimal.new("0.02")
  @default_three_tap_publisher_credit_amt Decimal.new("0.01")

  def video_publisher_credit_amt do
    fetch_decimal(:video_publisher_credit_amt, @default_video_publisher_credit_amt)
  end

  def three_tap_publisher_credit_amt do
    fetch_decimal(:three_tap_publisher_credit_amt, @default_three_tap_publisher_credit_amt)
  end

  defp fetch_decimal(key, %Decimal{} = default) do
    value =
      :qlarius
      |> Application.get_env(:ad_rates, [])
      |> Keyword.get(key, default)

    cond do
      match?(%Decimal{}, value) ->
        value

      is_binary(value) ->
        Decimal.new(value)

      true ->
        default
    end
  end
end
