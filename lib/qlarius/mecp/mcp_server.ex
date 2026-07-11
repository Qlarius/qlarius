defmodule Qlarius.MeCP.MCPServer do
  @moduledoc """
  Thin hand-rolled MCP (Model Context Protocol) JSON-RPC handler.

  The build plan blesses this fallback because the MeCP surface is small: a
  handful of tools behind a bearer token bound to one `mecp_grant`. A library
  would mostly add supervision machinery while we would still have to thread
  grant auth and mandatory access logging through it (evaluated hermes_mcp /
  phantom_mcp / emcp, July 2026).

  This module owns only the MCP transport concerns: JSON-RPC framing, the
  initialize handshake (logging + MyTerms proffer/acknowledgment), and
  protocol version negotiation. The tool surface itself (specs, dispatch,
  refusals, envelopes) lives in `Qlarius.MeCP.Tools`, shared with Qai so the
  in-house assistant exercises exactly what external connectors get.

  Speaks the streamable HTTP flavor minimally: JSON request in, JSON response
  out. Methods: `initialize`, `notifications/initialized`, `ping`,
  `tools/list`, `tools/call`.

  Every response that carries MeFile data leads with the do-not-retain
  preamble. Tool-level refusals (revoked grant, exhausted budget, out of
  scope) return `isError: true` tool results, not JSON-RPC errors.
  """

  alias Qlarius.MeCP
  alias Qlarius.MeCP.{AccessLog, Terms, Tools}
  alias Qlarius.MeCP.Grants.Grant

  @protocol_versions ~w(2025-06-18 2025-03-26)
  @server_info %{
    "name" => "mecp",
    "title" => "MeCP (YouData MeFile gateway)",
    "version" => "0.1.0"
  }

  @doc """
  Handles one decoded JSON-RPC message under an authenticated grant.

  Returns `{:reply, response_map}` for requests, or `:accepted` for
  notifications (no `id`), which the transport answers with HTTP 202.
  """
  @spec handle(Grant.t(), map()) :: {:reply, map()} | :accepted
  def handle(%Grant{} = grant, %{"method" => method} = request) do
    id = Map.get(request, "id")
    params = Map.get(request, "params", %{})

    case {method, id} do
      {"notifications/initialized", nil} ->
        acknowledge_terms(grant)
        :accepted

      {"notifications/" <> _, nil} ->
        :accepted

      {_method, nil} ->
        # Unknown notification: accept and ignore per spec.
        :accepted

      {"initialize", id} ->
        {:reply, result(id, initialize(grant, params))}

      {"ping", id} ->
        {:reply, result(id, %{})}

      {"tools/list", id} ->
        {:reply, result(id, %{"tools" => Tools.definitions()})}

      {"tools/call", id} ->
        name = Map.get(params, "name")
        args = Map.get(params, "arguments", %{})
        {:reply, result(id, Tools.call(grant, name, args))}

      {_unknown, id} ->
        {:reply, error(id, -32_601, "method not found: #{method}")}
    end
  end

  def handle(%Grant{}, request) do
    {:reply, error(Map.get(request, "id"), -32_600, "invalid request")}
  end

  # --- lifecycle --------------------------------------------------------------

  defp initialize(grant, params) do
    requested = Map.get(params, "protocolVersion")
    version = if requested in @protocol_versions, do: requested, else: hd(@protocol_versions)

    AccessLog.record!(
      grant,
      "handshake",
      AccessLog.digest({:initialize, requested}),
      %{"method" => "initialize", "protocol_version" => version}
    )

    %{
      "protocolVersion" => version,
      "capabilities" => %{"tools" => %{}},
      "serverInfo" => @server_info,
      "instructions" => instructions(grant)
    }
  end

  defp instructions(grant) do
    myterms =
      case grant.mecp_client do
        %{myterms_roster_ref: ref} when is_binary(ref) and ref != "" ->
          "\n\nAccess is offered under the MyTerms roster agreement \"#{ref}\". " <>
            "Continuing past initialization records your acknowledgment."

        _ ->
          ""
      end

    "MeCP provides scoped, user-granted access to one person's MeFile " <>
      "(self-declared profile data). Use get_capsule for rendered context and " <>
      "ask_me for narrow structured questions.\n\n" <>
      "Keeping the MeFile current: gaps you hit through empty reads are noted " <>
      "for the owner automatically. But only you see the conversation, so when " <>
      "the owner says something that contradicts or extends their MeFile data " <>
      "(new pet, moved cities, changed jobs), or a value's confirmation date " <>
      "looks stale for its subject, propose an update with suggest_tag. The " <>
      "owner reviews it in their MeFile Builder; nothing is written without them.\n\n" <>
      String.trim(MeCP.do_not_retain_preamble()) <> myterms
  end

  defp acknowledge_terms(%Grant{mecp_client: client} = grant) do
    case client do
      %{myterms_roster_ref: ref} when is_binary(ref) and ref != "" ->
        Terms.record_agreement(client.id, grant.me_file_id, ref)

      _ ->
        :ok
    end
  end

  # --- response plumbing ---------------------------------------------------------

  defp result(id, result) do
    %{"jsonrpc" => "2.0", "id" => id, "result" => result}
  end

  defp error(id, code, message) do
    %{"jsonrpc" => "2.0", "id" => id, "error" => %{"code" => code, "message" => message}}
  end
end
