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
  (hashed into the ephemeral metadata id), `:max_tokens`.
  """
  def stream_conversation(messages, opts \\ [], fun) do
    %{
      model: model_for(:frontier),
      max_tokens: Keyword.get(opts, :max_tokens, @conversation_max_tokens),
      messages: messages
    }
    |> put_system(Keyword.get(opts, :system))
    |> put_metadata(Keyword.get(opts, :session_id))
    |> Anthropic.stream(fun)
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
