defmodule QlariusWeb.Api.Admin.TokenController do
  use QlariusWeb, :controller

  alias Qlarius.Accounts.AdminApiTokens
  alias QlariusWeb.Api.Admin.Responder

  def create(conn, params) do
    label = params["label"] || "agent"

    case AdminApiTokens.issue(conn.assigns.current_scope.true_user, label) do
      {:ok, token, raw} ->
        json(conn, %{id: token.id, label: token.label, token: raw})

      {:error, reason} ->
        Responder.error(conn, reason)
    end
  end

  def delete(conn, %{"id" => id}) do
    case AdminApiTokens.revoke(id) do
      {:ok, token} -> json(conn, %{id: token.id, revoked: true})
      {:error, reason} -> Responder.error(conn, reason)
    end
  end
end
