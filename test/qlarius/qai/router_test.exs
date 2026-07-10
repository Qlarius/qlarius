defmodule Qlarius.Qai.RouterTest do
  use ExUnit.Case, async: true

  alias Qlarius.Qai.Anthropic.SSE
  alias Qlarius.Qai.{Anthropic, Router}

  describe "SSE parser" do
    test "decodes complete events and buffers partial ones across feeds" do
      chunk1 = ~s(event: message_start\ndata: {"type":"message_start"}\n\ndata: {"ty)
      chunk2 = ~s(pe":"ping"}\n\n)

      {events, buffer} = SSE.feed(SSE.new(), chunk1)
      assert [%{"type" => "message_start"}] = events
      assert buffer != ""

      {events, ""} = SSE.feed(buffer, chunk2)
      assert [%{"type" => "ping"}] = events
    end

    test "ignores undecodable data" do
      {events, ""} = SSE.feed(SSE.new(), "data: not json\n\nevent: only-a-name\n\n")
      assert events == []
    end
  end

  describe "stream_conversation/3" do
    test "streams deltas to the callback and returns the accumulated result" do
      test_pid = self()

      Req.Test.stub(Anthropic, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        send(test_pid, {:request, Jason.decode!(body), conn.req_headers})

        stream_sse(conn, [
          %{"type" => "message_start", "message" => %{"model" => "claude-sonnet-4-6", "usage" => %{"input_tokens" => 40}}},
          %{"type" => "content_block_start", "index" => 0, "content_block" => %{"type" => "text", "text" => ""}},
          %{"type" => "content_block_delta", "index" => 0, "delta" => %{"type" => "text_delta", "text" => "Hello"}},
          %{"type" => "content_block_delta", "index" => 0, "delta" => %{"type" => "text_delta", "text" => " world"}},
          %{"type" => "content_block_stop", "index" => 0},
          %{"type" => "message_delta", "delta" => %{"stop_reason" => "end_turn"}, "usage" => %{"output_tokens" => 12}},
          %{"type" => "message_stop"}
        ])
      end)

      messages = [%{role: "user", content: "hi"}]

      assert {:ok, result} =
               Router.stream_conversation(
                 messages,
                 [system: "Capsule context here.", session_id: 42],
                 fn {:delta, text} -> send(test_pid, {:delta, text}) end
               )

      assert result.content == "Hello world"
      assert result.model == "claude-sonnet-4-6"
      assert result.stop_reason == "end_turn"
      assert result.usage["input_tokens"] == 40
      assert result.usage["output_tokens"] == 12

      assert_received {:delta, "Hello"}
      assert_received {:delta, " world"}

      assert_received {:request, body, headers}
      assert body["model"] == Router.model_for(:frontier)
      assert body["stream"] == true
      assert body["system"] == "Capsule context here."
      assert body["metadata"]["user_id"] == Router.ephemeral_id(42)
      assert {"x-api-key", "test-key"} in headers
      assert {"anthropic-version", "2023-06-01"} in headers
    end

    test "an SSE error event surfaces as an api error" do
      Req.Test.stub(Anthropic, fn conn ->
        stream_sse(conn, [
          %{"type" => "message_start", "message" => %{"model" => "m", "usage" => %{}}},
          %{"type" => "error", "error" => %{"type" => "overloaded_error", "message" => "busy"}}
        ])
      end)

      assert {:error, {:api_error, %{"type" => "overloaded_error"}}} =
               Router.stream_conversation([%{role: "user", content: "hi"}], [], fn _ -> :ok end)
    end

    test "a non-200 response surfaces status and decoded body" do
      Req.Test.stub(Anthropic, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{"error" => %{"type" => "authentication_error"}}))
      end)

      assert {:error, {:http, 401, %{"error" => %{"type" => "authentication_error"}}}} =
               Router.stream_conversation([%{role: "user", content: "hi"}], [], fn _ -> :ok end)
    end
  end

  describe "generate_title/2" do
    test "asks the cheap tier and tidies the reply" do
      test_pid = self()

      Req.Test.stub(Anthropic, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        send(test_pid, {:request, Jason.decode!(body)})

        Req.Test.json(conn, %{
          "content" => [%{"type" => "text", "text" => ~s("Knitting Trip Plans"\n)}],
          "model" => "claude-haiku-4-5",
          "stop_reason" => "end_turn",
          "usage" => %{"output_tokens" => 6}
        })
      end)

      assert {:ok, "Knitting Trip Plans"} = Router.generate_title("help me plan a trip")

      assert_received {:request, body}
      assert body["model"] == Router.model_for(:cheap)
      assert body["max_tokens"] == 64
    end
  end

  test "ephemeral ids are stable per session and unlinkable to the raw id" do
    id = Router.ephemeral_id(123)
    assert id == Router.ephemeral_id(123)
    assert id != Router.ephemeral_id(124)
    assert String.length(id) == 24
    refute id =~ "123"
  end

  defp stream_sse(conn, events) do
    conn =
      conn
      |> Plug.Conn.put_resp_header("content-type", "text/event-stream")
      |> Plug.Conn.send_chunked(200)

    Enum.reduce(events, conn, fn event, conn ->
      {:ok, conn} =
        Plug.Conn.chunk(conn, "event: #{event["type"]}\ndata: #{Jason.encode!(event)}\n\n")

      conn
    end)
  end
end
