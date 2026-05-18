defmodule QlariusWeb.Components.TiqitExpirationCountdown do
  use QlariusWeb, :html

  alias DateTime, as: ElixirDateTime
  alias NaiveDateTime, as: ElixirNaiveDateTime

  attr :expires_at, :any, required: true
  attr :id, :string, default: nil
  attr :class, :string, default: ""
  attr :label, :string, default: nil
  attr :countdown_kind, :atom, default: :expires, values: [:expires, :auto_fleet]
  attr :show_icon, :boolean, default: true

  def badge(assigns) do
    label =
      case Map.get(assigns, :label) do
        nil -> default_badge_label(Map.get(assigns, :countdown_kind, :expires))
        label -> label
      end

    assigns =
      assigns
      |> assign(:id, Map.get(assigns, :id) || "countdown-#{System.unique_integer([:positive])}")
      |> assign(:label, label)
      |> assign(
        :expires_str,
        case assigns.expires_at do
          %ElixirDateTime{} = dt -> ElixirDateTime.to_iso8601(dt)
          %ElixirNaiveDateTime{} = ndt -> ElixirNaiveDateTime.to_iso8601(ndt) <> "Z"
          binary when is_binary(binary) -> binary
          _ -> ""
        end
      )

    ~H"""
    <span
      id={@id}
      class={"badge #{@class}"}
      phx-hook="TiqitExpirationCountdown"
      data-expires-at={@expires_str}
      data-countdown-root
    >
      <.icon :if={@show_icon} name="hero-clock" class="w-3 h-3" />
      <span :if={@label != ""}>{@label}</span>
      <span data-countdown-display></span>
    </span>
    """
  end

  attr :expires_at, :any, required: true
  attr :id, :string, default: nil
  attr :class, :string, default: ""

  def text(assigns) do
    assigns =
      assigns
      |> assign(:id, assigns[:id] || "countdown-#{System.unique_integer([:positive])}")
      |> assign(
        :expires_str,
        case assigns.expires_at do
          %ElixirDateTime{} = dt -> ElixirDateTime.to_iso8601(dt)
          %ElixirNaiveDateTime{} = ndt -> ElixirNaiveDateTime.to_iso8601(ndt) <> "Z"
          binary when is_binary(binary) -> binary
          _ -> ""
        end
      )

    ~H"""
    <span
      id={@id}
      class={"font-semibold #{@class}"}
      phx-hook="TiqitExpirationCountdown"
      data-expires-at={@expires_str}
      data-countdown-root
    >
      <span data-countdown-display></span>
    </span>
    """
  end

  defp default_badge_label(:auto_fleet), do: "Auto-Fleets in"
  defp default_badge_label(_), do: "Expires in"
end
