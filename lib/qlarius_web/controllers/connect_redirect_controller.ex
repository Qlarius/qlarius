defmodule QlariusWeb.ConnectRedirectController do
  @moduledoc """
  Sends legacy `/login` (and public `/register`) entry points to `/connect`,
  preserving Connect-relevant query params.
  """
  use QlariusWeb, :controller

  @kept_params ~w(return_to popup ref invite)

  def to_connect(conn, params) do
    query =
      params
      |> Map.take(@kept_params)
      |> Enum.reject(fn {_k, v} -> v in [nil, ""] end)
      |> URI.encode_query()

    path = if query == "", do: "/connect", else: "/connect?" <> query
    redirect(conn, to: path)
  end
end
