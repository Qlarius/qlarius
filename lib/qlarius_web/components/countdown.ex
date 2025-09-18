defmodule QlariusWeb.Components.TiqitExpirationCountdown do
  use QlariusWeb, :html

  alias DateTime, as: ElixirDateTime
  alias NaiveDateTime, as: ElixirNaiveDateTime

  attr :expires_at, :any, required: true
  attr :id, :string, default: nil
  attr :class, :string, default: ""

  def badge(assigns) do
    assigns =
      assigns
      |> assign_new(:id, fn ->
        "countdown-" <> Integer.to_string(System.unique_integer([:positive]))
      end)
      |> assign_new(:expires_str, fn ->
        case assigns.expires_at do
          %ElixirDateTime{} = dt -> ElixirDateTime.to_iso8601(dt)
          %ElixirNaiveDateTime{} = ndt -> ElixirNaiveDateTime.to_iso8601(ndt) <> "Z"
          binary when is_binary(binary) -> binary
          _ -> ""
        end
      end)

    ~H"""
    <div
      id={@id}
      class={"badge #{@class}"}
      phx-hook="TiqitExpirationCountdown"
      data-expires-at={@expires_str}
      data-countdown-root
    >
      <.icon name="hero-clock" class="w-3 h-3" />
      <span>Time Remaining:</span>
      <span data-countdown-display></span>
    </div>
    """
  end
end
