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
  delta. Returns `{:ok, %{content:, model:, stop_reason:, usage:}}` with the
  fully accumulated text, or `{:error, reason}`.
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

  defp initial_state do
    %{buffer: SSE.new(), content: [], model: nil, stop_reason: nil, usage: %{}, api_error: nil}
  end

  defp collect_sse({:data, chunk}, {req, resp}, fun) do
    state = Req.Response.get_private(resp, :qai, initial_state())

    state =
      if resp.status == 200 do
        {events, buffer} = SSE.feed(state.buffer, chunk)
        Enum.reduce(events, %{state | buffer: buffer}, &handle_event(&1, &2, fun))
      else
        # Error bodies arrive as plain JSON chunks; reuse content as the sink.
        %{state | content: [chunk | state.content]}
      end

    {:cont, {req, Req.Response.put_private(resp, :qai, state)}}
  end

  defp handle_event(%{"type" => "message_start", "message" => message}, state, _fun) do
    %{state | model: message["model"], usage: message["usage"] || %{}}
  end

  defp handle_event(
         %{"type" => "content_block_delta", "delta" => %{"type" => "text_delta", "text" => text}},
         state,
         fun
       ) do
    fun.({:delta, text})
    %{state | content: [text | state.content]}
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

  # ping, content_block_start/stop, thinking deltas, and anything new.
  defp handle_event(_event, state, _fun), do: state

  defp finish(%{api_error: error}) when not is_nil(error), do: {:error, {:api_error, error}}

  defp finish(state) do
    {:ok,
     %{
       content: state.content |> Enum.reverse() |> IO.iodata_to_binary(),
       model: state.model,
       stop_reason: state.stop_reason,
       usage: state.usage
     }}
  end

  defp error_body(resp) do
    body =
      Req.Response.get_private(resp, :qai, initial_state()).content
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
