defmodule QlariusWeb.MeCPController do
  @moduledoc """
  HTTP transport for the MeCP MCP endpoint (streamable HTTP, JSON responses
  only; no SSE stream in v1). Auth is a bearer token bound to one mecp_grant.
  """

  use QlariusWeb, :controller

  alias Qlarius.MeCP.Grants
  alias Qlarius.MeCP.Grants.Grant
  alias Qlarius.MeCP.MCPServer

  def rpc(conn, _params) do
    case authenticate(conn) do
      {:ok, grant} ->
        case MCPServer.handle(grant, conn.body_params) do
          {:reply, response} -> json(conn, response)
          :accepted -> send_resp(conn, 202, "")
        end

      :error ->
        conn
        |> put_resp_header("www-authenticate", "Bearer")
        |> put_status(:unauthorized)
        |> json(%{
          "jsonrpc" => "2.0",
          "id" => Map.get(conn.body_params, "id"),
          "error" => %{"code" => -32_001, "message" => "unauthorized"}
        })
    end
  end

  # v1 serves plain JSON responses; clients that GET for an SSE stream get 405,
  # which the streamable HTTP spec permits.
  def method_not_allowed(conn, _params) do
    send_resp(conn, 405, "")
  end

  defp authenticate(conn) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         %Grant{} = grant <- Grants.get_grant_by_token(String.trim(token)) do
      {:ok, grant}
    else
      _ -> :error
    end
  end
end
