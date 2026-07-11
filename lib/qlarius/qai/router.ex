defmodule Qlarius.Qai.Router do
  @moduledoc """
  Model routing for Qai: which model class handles which kind of call.

  Two tiers in v1, both config-overridable under `:qlarius, :qai, :models`:

    * `:frontier` - the conversation itself
    * `:cheap` - utility calls (session titles)

  A local-model tier is deferred per the Phase 2 design. The only identifier
  attached to a request is an ephemeral per-session id (opaque hash, rotates
  with the session), preserving two-sided anonymity while still giving the
  provider an abuse-detection handle.
  """

  alias Qlarius.Qai.Anthropic

  @default_models [cheap: "claude-haiku-4-5", frontier: "claude-sonnet-4-6"]
  @conversation_max_tokens 8192
  @title_max_tokens 64
  # Tool rounds per turn: enough for search + a few suggestions, low enough
  # that a confused model cannot spin.
  @max_tool_rounds 4

  @title_system """
  You title chat conversations. Reply with only a title for the conversation,
  2 to 5 words, no quotes and no trailing punctuation.
  """

  def model_for(tier) when tier in [:cheap, :frontier] do
    Application.get_env(:qlarius, :qai, [])
    |> Keyword.get(:models, [])
    |> Keyword.get(tier, @default_models[tier])
  end

  def configured?, do: Anthropic.configured?()

  @doc """
  Streams a conversation turn on the frontier tier. `messages` is the full
  transcript as `%{role:, content:}` maps; `fun` receives `{:delta, text}`.

  Options: `:system` (the capsule-bearing system prompt), `:session_id`
  (hashed into the ephemeral metadata id), `:max_tokens`, and the tool pair
  `:tools` (Anthropic-shaped definitions) + `:tool_handler` (a
  `fn name, input -> {result_text, is_error} end`). When the model stops on
  tool use, the handler runs each call, the results are appended, and the
  stream continues, so a single visible turn may span several requests; the
  returned `content` is the concatenated text across them.
  """
  def stream_conversation(messages, opts \\ [], fun) do
    base =
      %{
        model: model_for(:frontier),
        max_tokens: Keyword.get(opts, :max_tokens, @conversation_max_tokens)
      }
      |> put_system(Keyword.get(opts, :system))
      |> put_metadata(Keyword.get(opts, :session_id))
      |> put_tools(Keyword.get(opts, :tools))

    run_turn(base, messages, Keyword.get(opts, :tool_handler), @max_tool_rounds, "", fun)
  end

  defp run_turn(base, messages, handler, rounds_left, text_acc, fun) do
    case Anthropic.stream(Map.put(base, :messages, messages), fun) do
      {:ok, %{stop_reason: "tool_use", blocks: blocks} = result}
      when is_function(handler, 2) and rounds_left > 0 ->
        tool_results =
          for %{type: "tool_use"} = tool_use <- blocks do
            {text, is_error} = handler.(tool_use.name, tool_use.input)

            %{
              type: "tool_result",
              tool_use_id: tool_use.id,
              content: text,
              is_error: is_error
            }
          end

        messages =
          messages ++
            [
              %{role: "assistant", content: replayable_blocks(blocks)},
              %{role: "user", content: tool_results}
            ]

        run_turn(base, messages, handler, rounds_left - 1, text_acc <> result.content, fun)

      {:ok, result} ->
        {:ok, %{result | content: text_acc <> result.content}}

      error ->
        error
    end
  end

  # The assistant turn echoed back to the API: text and tool_use blocks in
  # order, minus empty text blocks (the API rejects them).
  defp replayable_blocks(blocks) do
    Enum.flat_map(blocks, fn
      %{type: "text", text: ""} -> []
      %{type: "text", text: text} -> [%{type: "text", text: text}]
      %{type: "tool_use", id: id, name: name, input: input} -> [%{type: "tool_use", id: id, name: name, input: input}]
    end)
  end

  @doc "Titles a session from its opening exchange, on the cheap tier."
  def generate_title(first_user_message, opts \\ []) do
    params =
      %{
        model: model_for(:cheap),
        max_tokens: @title_max_tokens,
        system: @title_system,
        messages: [%{role: "user", content: String.slice(first_user_message, 0, 2000)}]
      }
      |> put_metadata(Keyword.get(opts, :session_id))

    case Anthropic.complete(params) do
      {:ok, %{content: content}} -> {:ok, tidy_title(content)}
      error -> error
    end
  end

  @doc """
  The per-session id the provider sees: an opaque hash of the session id and
  the app secret, so it groups a session's requests for abuse detection but
  maps to nothing outside this app and dies with the session.
  """
  def ephemeral_id(session_id) do
    secret = Application.get_env(:qlarius, QlariusWeb.Endpoint)[:secret_key_base] || ""

    :crypto.mac(:hmac, :sha256, secret, "qai-session-#{session_id}")
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 24)
  end

  defp put_system(params, nil), do: params
  defp put_system(params, system), do: Map.put(params, :system, system)

  defp put_tools(params, tools) when is_list(tools) and tools != [],
    do: Map.put(params, :tools, tools)

  defp put_tools(params, _), do: params

  defp put_metadata(params, nil), do: params

  defp put_metadata(params, session_id),
    do: Map.put(params, :metadata, %{user_id: ephemeral_id(session_id)})

  defp tidy_title(content) do
    content
    |> String.trim()
    |> String.trim("\"")
    |> String.trim("'")
    |> String.slice(0, Qlarius.Qai.Session.title_max_length())
  end
end
