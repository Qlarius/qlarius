defmodule QlariusWeb.LoginLive do
  @moduledoc """
  Retired public sign-in LiveView.

  Public entry is `/connect` (AuthSheet). The `/login` route redirects
  via `QlariusWeb.ConnectRedirectController`. This module remains only
  as a safety net if anything still mounts `LoginLive` directly.
  """
  use QlariusWeb, :live_view

  alias Qlarius.Qlink.Urls

  def mount(params, _session, socket) do
    kept =
      params
      |> Map.take(["return_to", "popup", "ref", "invite"])
      |> Enum.reject(fn {_k, v} -> v in [nil, ""] end)
      |> Map.new()

    kept =
      case Map.get(kept, "return_to") do
        nil -> kept
        raw -> Map.put(kept, "return_to", Urls.sanitize_return_to(raw) || raw)
      end

    query = URI.encode_query(kept)
    path = if query == "", do: "/connect", else: "/connect?" <> query
    {:ok, push_navigate(socket, to: path)}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen" />
    """
  end
end
