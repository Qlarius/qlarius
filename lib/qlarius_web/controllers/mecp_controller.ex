defmodule QlariusWeb.MeCPController do
  @moduledoc """
  HTTP transport for the MeCP MCP endpoint (streamable HTTP, JSON responses
  only; no SSE stream in v1). Auth is a bearer token bound to one mecp_grant.
  """

  use QlariusWeb, :controller

  alias Qlarius.MeCP.Grants
  alias Qlarius.MeCP.Grants.Grant
  alias Qlarius.MeCP.MCPServer
  alias Qlarius.MeCP.OAuth

  def rpc(conn, _params) do
    case authenticate(conn) do
      {:ok, grant} ->
        case MCPServer.handle(grant, conn.body_params) do
          {:reply, response} -> json(conn, response)
          :accepted -> send_resp(conn, 202, "")
        end

      :error ->
        # Points OAuth-capable clients (Claude/ChatGPT connectors) at the
        # discovery metadata per RFC 9728.
        metadata_url = url(conn, ~p"/.well-known/oauth-protected-resource/mecp/mcp")

        conn
        |> put_resp_header("www-authenticate", ~s(Bearer resource_metadata="#{metadata_url}"))
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

  # Static grant tokens (local token-paste clients) and OAuth access tokens
  # (remote connectors) both resolve to a grant; everything downstream is
  # identical.
  defp authenticate(conn) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         token = String.trim(token),
         %Grant{} = grant <-
           Grants.get_grant_by_token(token) || OAuth.verify_access_token(token) do
      {:ok, grant}
    else
      _ -> :error
    end
  end
end
