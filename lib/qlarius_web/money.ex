defmodule QlariusWeb.Money do
  def format_usd(%Decimal{} = amount) do
    "$#{Decimal.round(amount, 2) |> Decimal.to_string()}"
  end
end
