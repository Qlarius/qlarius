defmodule QlariusWeb.Money do
  def format_usd(%Decimal{} = amount) do
    if Decimal.eq?(amount, 0) do
      "FREE"
    else
      "$#{Decimal.round(amount, 2) |> Decimal.to_string()}"
    end
  end
end
