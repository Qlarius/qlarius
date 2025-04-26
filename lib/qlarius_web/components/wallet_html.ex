defmodule QlariusWeb.WalletHTML do
  use QlariusWeb, :html

  embed_templates "wallet_html/*"

  def format_amount(amount) when is_nil(amount), do: "0.00"
  def format_amount(amount) do
    amount
    |> Decimal.round(2)
    |> Decimal.to_string()
  end

  def format_datetime(%NaiveDateTime{} = datetime) do
    Calendar.strftime(datetime, "%B %d, %Y at %I:%M %p")
  end

  def sidebar_down_arrow(assigns) do
    ~H"""
    <div class="flex justify-around">
      <.icon name="hero-arrow-down-circle" class="h-8 w-8 text-gray-400" />
    </div>
    """
  end
end
