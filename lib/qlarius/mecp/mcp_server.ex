defmodule Qlarius.MeCP.MCPServer do
  @moduledoc """
  Thin hand-rolled MCP (Model Context Protocol) JSON-RPC handler.

  The build plan blesses this fallback because the MeCP surface is small: two
  tools (`get_capsule`, `ask_me`) behind a bearer token bound to one
  `mecp_grant`. A library would mostly add supervision machinery while we
  would still have to thread grant auth and mandatory access logging through
  it (evaluated hermes_mcp / phantom_mcp / emcp, July 2026).

  Speaks the streamable HTTP flavor minimally: JSON request in, JSON response
  out. Methods: `initialize` (logs a handshake event, proffers MyTerms),
  `notifications/initialized` (records the terms acknowledgment), `ping`,
  `tools/list`, `tools/call`.

  Every response that carries MeFile data leads with the do-not-retain
  preamble. Tool-level refusals (revoked grant, exhausted budget, out of
  scope) return `isError: true` tool results, not JSON-RPC errors.
  """

  alias Qlarius.MeCP
  alias Qlarius.MeCP.{AccessLog, Oracle, Suggestions, Terms}
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
        {:reply, result(id, %{"tools" => tool_definitions()})}

      {"tools/call", id} ->
        {:reply, result(id, call_tool(grant, params))}

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

  # --- tools --------------------------------------------------------------------

  # Every MeCP v1 tool is a pure read. Declaring that via MCP tool annotations
  # lets clients (claude.ai honors readOnlyHint) skip per-use write-safety
  # confirmations instead of prompting on every chat.
  @read_only_annotations %{
    "readOnlyHint" => true,
    "destructiveHint" => false,
    "idempotentHint" => true,
    "openWorldHint" => false
  }

  defp tool_definitions do
    [
      %{
        "name" => "get_capsule",
        "title" => "Get MeFile capsule",
        "description" =>
          "Returns the scoped MeFile capsule this grant permits: compact markdown of " <>
            "category > trait > values, each value dated with its confirmation month/year.",
        "annotations" => @read_only_annotations,
        "inputSchema" => %{
          "type" => "object",
          "properties" => %{},
          "additionalProperties" => false
        }
      },
      %{
        "name" => "ask_me",
        "title" => "Ask a narrow question",
        "description" =>
          "Answers one structured question about a single trait, within this grant's " <>
            "scope and disclosure budget. Forms: has_trait (boolean), trait_values " <>
            "(values with dates), value_in (boolean membership), bucket (bucket label only). " <>
            "Target the trait by exact name (see search_traits) or by trait_id. " <>
            "If the answer comes back empty with a missing_data_hint, the owner has no " <>
            "tags there yet; if it fits the conversation, gently let them know they can " <>
            "add tags in the MeFile Builder in their Qadabra app.",
        "annotations" => @read_only_annotations,
        "inputSchema" => %{
          "type" => "object",
          "properties" => %{
            "form" => %{
              "type" => "string",
              "enum" => ["has_trait", "trait_values", "value_in", "bucket"]
            },
            "trait_id" => %{"type" => "integer"},
            "trait" => %{
              "type" => "string",
              "description" => "Exact trait name (case-insensitive); alternative to trait_id"
            },
            "values" => %{
              "type" => "array",
              "items" => %{"type" => "string"},
              "description" => "Candidate values, required for form=value_in"
            },
            "buckets" => %{
              "type" => "array",
              "items" => %{
                "type" => "object",
                "properties" => %{
                  "label" => %{"type" => "string"},
                  "values" => %{"type" => "array", "items" => %{"type" => "string"}}
                },
                "required" => ["label", "values"]
              },
              "description" => "Labeled value buckets, required for form=bucket"
            }
          },
          "required" => ["form"]
        }
      },
      %{
        "name" => "search_traits",
        "title" => "Search the MeFile taxonomy",
        "description" =>
          "Searches the MeFile trait taxonomy by keywords and returns matching traits " <>
            "with a has_data flag for this MeFile. Use topic nouns and synonyms " <>
            "(for a dog question, search 'pet dog'). Matches without data are gaps " <>
            "the owner can fill: when it fits the conversation, gently suggest they " <>
            "add tags in the MeFile Builder in their Qadabra app. Costs one unit of " <>
            "disclosure budget per call.",
        "annotations" => @read_only_annotations,
        "inputSchema" => %{
          "type" => "object",
          "properties" => %{
            "query" => %{
              "type" => "string",
              "description" => "Keywords to match against trait and category names"
            }
          },
          "required" => ["query"]
        }
      },
      %{
        "name" => "suggest_tag",
        "title" => "Suggest a MeFile addition",
        "description" =>
          "Proposes that the owner add tags for a trait, with specific values they " <>
            "mentioned and your reason. Rarely needed: gaps you hit via search_traits " <>
            "or ask_me are queued for the owner automatically. Call this only when " <>
            "the owner explicitly asks you to save a suggestion or mentions concrete " <>
            "values worth attaching. Nothing is written to the MeFile: the proposal " <>
            "appears as a question in the From Recent Chats survey in their MeFile " <>
            "Builder, where the owner answers or dismisses it.",
        # Deliberately NOT read-only: this queues something for the owner, so
        # clients should treat it as a write and confirm with their user.
        "annotations" => %{
          "readOnlyHint" => false,
          "destructiveHint" => false,
          "idempotentHint" => true,
          "openWorldHint" => false
        },
        "inputSchema" => %{
          "type" => "object",
          "properties" => %{
            "trait" => %{
              "type" => "string",
              "description" => "Exact trait name (case-insensitive); alternative to trait_id"
            },
            "trait_id" => %{"type" => "integer"},
            "values" => %{
              "type" => "array",
              "items" => %{"type" => "string"},
              "description" => "Optional values the owner mentioned, shown as context"
            },
            "reason" => %{
              "type" => "string",
              "description" =>
                "One short sentence, in your words, on why this came up (shown to the owner)"
            }
          },
          "required" => ["reason"]
        }
      }
    ]
  end

  defp call_tool(grant, %{"name" => "get_capsule"} = params) do
    _args = Map.get(params, "arguments", %{})

    case MeCP.request_capsule(grant, terms_opts(grant)) do
      {:ok, rendered} ->
        tool_text(String.trim(MeCP.do_not_retain_preamble()) <> "\n\n" <> rendered)

      {:error, reason} ->
        tool_refusal(reason)
    end
  end

  defp call_tool(grant, %{"name" => "ask_me"} = params) do
    args = Map.get(params, "arguments", %{})

    with {:ok, question} <- build_question(args),
         {:ok, answer} <- Oracle.ask(grant, question, terms_opts(grant)) do
      envelope =
        %{
          "preamble" => String.trim(MeCP.do_not_retain_preamble()),
          "form" => args["form"],
          "trait" => args["trait"] || args["trait_id"],
          "answer" => encode_answer(answer)
        }
        |> maybe_add_missing_data_hint(args, answer)

      tool_text(Jason.encode!(envelope))
    else
      {:error, reason} -> tool_refusal(reason)
    end
  end

  defp call_tool(grant, %{"name" => "search_traits"} = params) do
    args = Map.get(params, "arguments", %{})

    case Oracle.search_traits(grant, args["query"] || "", terms_opts(grant)) do
      {:ok, matches} ->
        envelope = %{
          "preamble" => String.trim(MeCP.do_not_retain_preamble()),
          "query" => args["query"],
          "matches" =>
            Enum.map(matches, fn m ->
              %{
                "trait_id" => m.trait_id,
                "trait" => m.trait,
                "category" => m.category,
                "has_data" => m.has_data
              }
            end),
          "guidance" =>
            "Matches with has_data false are gaps in the MeFile; the top gap has " <>
              "been noted for the owner in the From Recent Chats survey in their " <>
              "MeFile Builder. If it fits the conversation, gently let them know " <>
              "it is waiting there."
        }

        tool_text(Jason.encode!(envelope))

      {:error, reason} ->
        tool_refusal(reason)
    end
  end

  defp call_tool(grant, %{"name" => "suggest_tag"} = params) do
    args = Map.get(params, "arguments", %{})

    with {:ok, ref} <- trait_ref(args),
         {:ok, outcome} <-
           Suggestions.create_suggestion(grant, ref, %{
             proposed_values: List.wrap(args["values"] || []),
             reason: args["reason"]
           }) do
      envelope =
        case outcome do
          :already_suggested ->
            %{
              "status" => "already_suggested",
              "note" =>
                "A suggestion for this trait is already waiting for the owner " <>
                  "(or was recently dismissed). No need to suggest it again."
            }

          _suggestion ->
            %{
              "status" => "queued",
              "note" =>
                "Queued. The owner will see this as a question in the From Recent " <>
                  "Chats survey in their MeFile Builder. They decide; nothing was " <>
                  "written to the MeFile."
            }
        end

      tool_text(Jason.encode!(envelope))
    else
      {:error, :suggestion_limit_reached} ->
        tool_refusal(
          "suggestion limit reached: this connector already has the maximum " <>
            "pending suggestions; wait for the owner to review them"
        )

      {:error, :not_askable} ->
        tool_refusal(
          "not_askable: this trait has no survey question, so the owner cannot " <>
            "be asked it in the Builder"
        )

      {:error, reason} ->
        tool_refusal(reason)
    end
  end

  defp call_tool(_grant, %{"name" => name}) do
    tool_refusal("unknown tool: #{name}")
  end

  defp call_tool(_grant, _params), do: tool_refusal(:invalid_arguments)

  defp build_question(args) do
    with {:ok, ref} <- trait_ref(args) do
      case args do
        %{"form" => "has_trait"} ->
          {:ok, {:has_trait, ref}}

        %{"form" => "trait_values"} ->
          {:ok, {:trait_values, ref}}

        %{"form" => "value_in", "values" => values} when is_list(values) ->
          {:ok, {:value_in, ref, values}}

        %{"form" => "bucket", "buckets" => buckets} when is_list(buckets) ->
          build_bucket_question(ref, buckets)

        _ ->
          {:error, :invalid_arguments}
      end
    end
  end

  defp trait_ref(%{"trait_id" => id}) when is_integer(id), do: {:ok, id}
  defp trait_ref(%{"trait" => name}) when is_binary(name) and name != "", do: {:ok, name}
  defp trait_ref(_), do: {:error, "provide trait (name) or trait_id (integer)"}

  defp build_bucket_question(ref, buckets) do
    pairs =
      Enum.map(buckets, fn
        %{"label" => label, "values" => values} when is_binary(label) and is_list(values) ->
          {label, values}

        _ ->
          nil
      end)

    if Enum.any?(pairs, &is_nil/1) do
      {:error, "each bucket needs a label and a values array"}
    else
      {:ok, {:bucket, ref, pairs}}
    end
  end

  # An empty answer means the trait exists in the taxonomy but the owner has
  # no tags there: turn the miss into a gentle enrichment nudge the assistant
  # can relay (build plan: every unanswerable question is a capture prompt).
  defp maybe_add_missing_data_hint(envelope, args, answer) when answer in [false, [], nil] do
    subject =
      case args["trait"] do
        name when is_binary(name) and name != "" -> "'#{name}'"
        _ -> "this topic"
      end

    Map.put(
      envelope,
      "missing_data_hint",
      "The owner has no confirmed tags for #{subject}. This gap has been noted " <>
        "for them in the From Recent Chats survey in their MeFile Builder. If it " <>
        "fits the conversation, gently let them know it is waiting there."
    )
  end

  defp maybe_add_missing_data_hint(envelope, _args, _answer), do: envelope

  defp encode_answer(values) when is_list(values) do
    Enum.map(values, fn %{value: v, confirmed: c} -> %{"value" => v, "confirmed" => c} end)
  end

  defp encode_answer(other), do: other

  defp terms_opts(%Grant{} = grant) do
    case grant.mecp_client do
      %{id: client_id} ->
        [terms_agreement_id: Terms.latest_agreement_id(client_id, grant.me_file_id)]

      _ ->
        []
    end
  end

  # --- response plumbing ---------------------------------------------------------

  defp tool_text(text) do
    %{"content" => [%{"type" => "text", "text" => text}], "isError" => false}
  end

  defp tool_refusal(reason) do
    %{
      "content" => [%{"type" => "text", "text" => "refused: #{format_reason(reason)}"}],
      "isError" => true
    }
  end

  defp format_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_reason(reason) when is_binary(reason), do: reason

  defp result(id, result) do
    %{"jsonrpc" => "2.0", "id" => id, "result" => result}
  end

  defp error(id, code, message) do
    %{"jsonrpc" => "2.0", "id" => id, "error" => %{"code" => code, "message" => message}}
  end
end
