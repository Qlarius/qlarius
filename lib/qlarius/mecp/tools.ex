defmodule Qlarius.MeCP.Tools do
  @moduledoc """
  The MeCP tool surface: one source of truth for tool specs and dispatch,
  shared by every client transport.

  The MCP endpoint (external connectors, JSON-RPC over HTTP) and Qai (the
  in-house assistant, plain function calls) both expose exactly these tools
  under a grant. Descriptions, schemas, refusal strings, gap hints, access
  logging, and budget spend are therefore identical across surfaces: Qai
  dogfoods the same gateway external assistants get, minus only OAuth and
  JSON-RPC framing, which exist to cross the trust boundary Qai lives inside.

  `definitions/0` returns MCP-shaped tool specs; `anthropic_definitions/1`
  reshapes a subset for the Anthropic Messages API `tools` parameter.
  `call/3` dispatches one tool call under a grant and returns the MCP-style
  result envelope (`%{"content" => [...], "isError" => bool}`).
  """

  alias Qlarius.MeCP
  alias Qlarius.MeCP.{Oracle, Suggestions, Terms}
  alias Qlarius.MeCP.Grants.Grant

  # Every read tool is pure. Declaring that via MCP tool annotations lets
  # clients (claude.ai honors readOnlyHint) skip per-use write-safety
  # confirmations instead of prompting on every chat.
  @read_only_annotations %{
    "readOnlyHint" => true,
    "destructiveHint" => false,
    "idempotentHint" => true,
    "openWorldHint" => false
  }

  def definitions do
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
        "title" => "Suggest a MeFile addition or update",
        "description" =>
          "Proposes that the owner add or update tags for a trait, with specific " <>
            "values they mentioned and your reason. Empty gaps you hit via " <>
            "search_traits or ask_me are queued for the owner automatically, so " <>
            "the main reason to call this is an UPDATE: the owner states something " <>
            "that contradicts or extends data the MeFile already has (their tags " <>
            "say Bird and Fish; they just told you they got a dog), or an existing " <>
            "value looks stale from its confirmation date. Updates to existing tags " <>
            "only reach the owner if you call this. Also call it when the owner " <>
            "explicitly asks you to save a suggestion. Nothing is written to the " <>
            "MeFile: the proposal appears as a question in the From Recent Chats " <>
            "survey in their MeFile Builder, where the owner answers or dismisses it.",
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

  @doc """
  A subset of the tool specs reshaped for the Anthropic Messages API `tools`
  parameter (used by Qai's Router).
  """
  def anthropic_definitions(names) do
    definitions()
    |> Enum.filter(&(&1["name"] in names))
    |> Enum.map(fn spec ->
      %{
        name: spec["name"],
        description: spec["description"],
        input_schema: spec["inputSchema"]
      }
    end)
  end

  @doc "The plain text of a tool result envelope."
  def result_text(%{"content" => [%{"text" => text} | _]}), do: text
  def result_text(_), do: ""

  def error?(%{"isError" => is_error}), do: is_error == true

  @doc """
  Dispatches one tool call under a grant. Returns the MCP-style result
  envelope; tool-level refusals (revoked grant, exhausted budget, out of
  scope) come back as `isError: true` envelopes, never raises.
  """
  @spec call(Grant.t(), String.t(), map()) :: map()
  def call(%Grant{} = grant, "get_capsule", _args) do
    case MeCP.request_capsule(grant, terms_opts(grant)) do
      {:ok, rendered} ->
        tool_text(String.trim(MeCP.do_not_retain_preamble()) <> "\n\n" <> rendered)

      {:error, reason} ->
        tool_refusal(reason)
    end
  end

  def call(%Grant{} = grant, "ask_me", args) do
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

  def call(%Grant{} = grant, "search_traits", args) do
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

  def call(%Grant{} = grant, "suggest_tag", args) do
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

  def call(%Grant{}, name, _args) when is_binary(name) do
    tool_refusal("unknown tool: #{name}")
  end

  def call(%Grant{}, _name, _args), do: tool_refusal(:invalid_arguments)

  # --- question building ----------------------------------------------------------

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

  # --- envelopes -------------------------------------------------------------------

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
end
