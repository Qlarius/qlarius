defmodule QlariusWeb.Money do
  def format_usd(amount, opts \\ []) do
    zero_free = Keyword.get(opts, :zero_free, false)
    do_format_usd(amount, zero_free)
  end

  defp do_format_usd(nil, zero_free) do
    if zero_free, do: "FREE", else: "$0.00"
  end

  defp do_format_usd(0, zero_free) do
    if zero_free, do: "FREE", else: "$0.00"
  end

  defp do_format_usd(%Decimal{} = amount, zero_free) do
    if Decimal.eq?(amount, 0) do
      if zero_free, do: "FREE", else: "$0.00"
    else
      "$#{Decimal.round(amount, 2) |> Decimal.to_string()}"
    end
  end

  defp do_format_usd(amount, zero_free) when is_number(amount) do
    do_format_usd(Decimal.new(amount), zero_free)
  end
end
