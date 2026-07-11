defmodule Qlarius.Qai.Anthropic do
  @moduledoc """
  Minimal Anthropic Messages API client over Req: one streaming call and one
  one-shot call. There is no official Elixir SDK, so this speaks the raw HTTP
  surface (`POST /v1/messages` with SSE when `stream: true`).

  All traffic goes out under the pooled org key (`ANTHROPIC_API_KEY`), which
  is half of Qai's two-sided anonymity: the provider sees Qadabra's account,
  never an individual. Callers must not put user identifiers in params beyond
  the ephemeral ids the Router builds.

  Cancellation is by process design rather than API: `stream/2` runs in the
  caller's process, so killing the Task that wraps it drops the connection.
  """

  alias Qlarius.Qai.Anthropic.SSE

  @api_version "2023-06-01"
  @default_url "https://api.anthropic.com/v1/messages"
  @receive_timeout 90_000

  @doc """
  Streams a Messages API call. `fun` receives `{:delta, text}` for each text
  delta. Returns `{:ok, %{content:, blocks:, model:, stop_reason:, usage:}}`
  or `{:error, reason}`. `content` is the accumulated text; `blocks` is the
  ordered content-block list (`%{type: "text", text:}` and
  `%{type: "tool_use", id:, name:, input:}`), which callers running a tool
  loop echo back as the assistant turn.
  """
  def stream(params, fun) when is_map(params) and is_function(fun, 1) do
    with {:ok, api_key} <- fetch_api_key() do
      params
      |> Map.put(:stream, true)
      |> request(api_key, into: &collect_sse(&1, &2, fun))
      |> case do
        {:ok, %Req.Response{status: 200} = resp} ->
          finish(Req.Response.get_private(resp, :qai, initial_state()))

        {:ok, %Req.Response{status: status} = resp} ->
          {:error, {:http, status, error_body(resp)}}

        {:error, exception} ->
          {:error, {:transport, exception}}
      end
    end
  end

  @doc "One-shot (non-streaming) Messages API call for small utility requests."
  def complete(params) when is_map(params) do
    with {:ok, api_key} <- fetch_api_key() do
      case request(params, api_key, []) do
        {:ok, %Req.Response{status: 200, body: body}} ->
          {:ok,
           %{
             content: text_content(body["content"]),
             model: body["model"],
             stop_reason: body["stop_reason"],
             usage: body["usage"] || %{}
           }}

        {:ok, %Req.Response{status: status, body: body}} ->
          {:error, {:http, status, body}}

        {:error, exception} ->
          {:error, {:transport, exception}}
      end
    end
  end

  def configured?, do: match?({:ok, _}, fetch_api_key())

  defp request(params, api_key, extra_opts) do
    [
      url: Keyword.get(config(), :anthropic_api_url, @default_url),
      headers: [
        {"x-api-key", api_key},
        {"anthropic-version", @api_version}
      ],
      json: params,
      receive_timeout: @receive_timeout
    ]
    |> Keyword.merge(extra_opts)
    |> Keyword.merge(Keyword.get(config(), :req_options, []))
    |> Req.post()
  end

  ## SSE collection

  # `blocks` maps stream index -> content block under assembly; text and
  # tool-call JSON both arrive as deltas against an index. `error_chunks`
  # collects the plain-JSON body of non-200 responses.
  defp initial_state do
    %{
      buffer: SSE.new(),
      blocks: %{},
      model: nil,
      stop_reason: nil,
      usage: %{},
      api_error: nil,
      error_chunks: []
    }
  end

  defp collect_sse({:data, chunk}, {req, resp}, fun) do
    state = Req.Response.get_private(resp, :qai, initial_state())

    state =
      if resp.status == 200 do
        {events, buffer} = SSE.feed(state.buffer, chunk)
        Enum.reduce(events, %{state | buffer: buffer}, &handle_event(&1, &2, fun))
      else
        %{state | error_chunks: [chunk | state.error_chunks]}
      end

    {:cont, {req, Req.Response.put_private(resp, :qai, state)}}
  end

  defp handle_event(%{"type" => "message_start", "message" => message}, state, _fun) do
    %{state | model: message["model"], usage: message["usage"] || %{}}
  end

  defp handle_event(
         %{"type" => "content_block_start", "index" => index, "content_block" => block},
         state,
         _fun
       ) do
    started =
      case block do
        %{"type" => "text"} -> %{type: "text", parts: []}
        %{"type" => "tool_use", "id" => id, "name" => name} -> %{type: "tool_use", id: id, name: name, json: []}
        %{"type" => other} -> %{type: other}
      end

    %{state | blocks: Map.put(state.blocks, index, started)}
  end

  defp handle_event(
         %{"type" => "content_block_delta", "index" => index, "delta" => delta},
         state,
         fun
       ) do
    case {delta, state.blocks[index]} do
      {%{"type" => "text_delta", "text" => text}, %{type: "text", parts: parts} = block} ->
        fun.({:delta, text})
        %{state | blocks: Map.put(state.blocks, index, %{block | parts: [text | parts]})}

      # Tolerate a delta with no preceding content_block_start.
      {%{"type" => "text_delta", "text" => text}, nil} ->
        fun.({:delta, text})
        %{state | blocks: Map.put(state.blocks, index, %{type: "text", parts: [text]})}

      {%{"type" => "input_json_delta", "partial_json" => json}, %{type: "tool_use", json: acc} = block} ->
        %{state | blocks: Map.put(state.blocks, index, %{block | json: [json | acc]})}

      # thinking deltas and anything newer.
      _ ->
        state
    end
  end

  defp handle_event(%{"type" => "message_delta"} = event, state, _fun) do
    %{
      state
      | stop_reason: get_in(event, ["delta", "stop_reason"]) || state.stop_reason,
        usage: Map.merge(state.usage, event["usage"] || %{})
    }
  end

  defp handle_event(%{"type" => "error", "error" => error}, state, _fun) do
    %{state | api_error: error}
  end

  # ping, content_block_stop, and anything new.
  defp handle_event(_event, state, _fun), do: state

  defp finish(%{api_error: error}) when not is_nil(error), do: {:error, {:api_error, error}}

  defp finish(state) do
    blocks =
      state.blocks
      |> Enum.sort_by(fn {index, _} -> index end)
      |> Enum.map(fn {_, block} -> finalize_block(block) end)
      |> Enum.reject(&is_nil/1)

    content =
      blocks
      |> Enum.filter(&(&1.type == "text"))
      |> Enum.map_join("", & &1.text)

    {:ok,
     %{
       content: content,
       blocks: blocks,
       model: state.model,
       stop_reason: state.stop_reason,
       usage: state.usage
     }}
  end

  defp finalize_block(%{type: "text", parts: parts}) do
    %{type: "text", text: parts |> Enum.reverse() |> IO.iodata_to_binary()}
  end

  defp finalize_block(%{type: "tool_use", id: id, name: name, json: json}) do
    raw = json |> Enum.reverse() |> IO.iodata_to_binary()

    input =
      case Jason.decode(raw) do
        {:ok, decoded} when is_map(decoded) -> decoded
        # Empty input streams as no deltas at all.
        _ when raw == "" -> %{}
        _ -> %{}
      end

    %{type: "tool_use", id: id, name: name, input: input}
  end

  # thinking and unknown block types carry nothing we replay.
  defp finalize_block(_block), do: nil

  defp error_body(resp) do
    body =
      Req.Response.get_private(resp, :qai, initial_state()).error_chunks
      |> Enum.reverse()
      |> IO.iodata_to_binary()

    case Jason.decode(body) do
      {:ok, decoded} -> decoded
      {:error, _} -> body
    end
  end

  defp text_content(content) when is_list(content) do
    content
    |> Enum.filter(&(&1["type"] == "text"))
    |> Enum.map_join("", & &1["text"])
  end

  defp text_content(_), do: ""

  defp fetch_api_key do
    case Keyword.get(config(), :anthropic_api_key) do
      key when is_binary(key) and key != "" -> {:ok, key}
      _ -> {:error, :not_configured}
    end
  end

  defp config, do: Application.get_env(:qlarius, :qai, [])
end
