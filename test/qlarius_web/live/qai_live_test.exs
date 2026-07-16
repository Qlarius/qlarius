defmodule QlariusWeb.QaiLiveTest do
  # async: false so Req.Test can run in shared mode; the provider call happens
  # in a Task spawned by the LiveView process, outside the test's caller chain.
  use QlariusWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Qlarius.MeCP.AccessLog
  alias Qlarius.Qai
  alias Qlarius.Qai.Sessions
  alias Qlarius.Repo

  # The stock register_and_log_in_user fixture predates this app's
  # alias+mobile auth; register the way the app actually does, with the
  # sex/age/birthdate answers require_initialized_mefile checks for.
  # Parent trait ids 1 (sex) and 93 (age) are hardcoded in
  # MeFiles.is_initialized?; explicit high child ids dodge the sequence.
  setup %{conn: conn} do
    alias Qlarius.YouData.Traits.Trait

    Repo.insert!(%Trait{id: 1, trait_name: "Sex", input_type: "text", display_order: 1, modified_by: 0, added_by: 0})
    Repo.insert!(%Trait{id: 93, trait_name: "Age", input_type: "text", display_order: 1, modified_by: 0, added_by: 0})
    male = Repo.insert!(%Trait{id: 100_001, parent_trait_id: 1, trait_name: "Male", input_type: "text", display_order: 1, modified_by: 0, added_by: 0})
    age = Repo.insert!(%Trait{id: 100_093, parent_trait_id: 93, trait_name: "25-34", input_type: "text", display_order: 1, modified_by: 0, added_by: 0})

    {:ok, %{user: user}} =
      Qlarius.Accounts.register_new_user(%{
        alias: "qai-tester-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01],
        sex_trait_id: male.id,
        age_trait_id: age.id
      })

    Req.Test.set_req_test_to_shared(%{})
    on_exit(fn -> Req.Test.set_req_test_to_private(%{}) end)

    %{conn: log_in_user(conn, user), user: user}
  end

  defp me_file(user), do: Qlarius.Accounts.get_me_file_by_user_id(user.id)

  defp stub_completion(reply_text) do
    Req.Test.stub(Qlarius.Qai.Anthropic, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      if Jason.decode!(body)["stream"] do
        events = [
          %{"type" => "message_start", "message" => %{"model" => "claude-sonnet-4-6", "usage" => %{"input_tokens" => 40}}},
          %{"type" => "content_block_delta", "index" => 0, "delta" => %{"type" => "text_delta", "text" => reply_text}},
          %{"type" => "message_delta", "delta" => %{"stop_reason" => "end_turn"}, "usage" => %{"output_tokens" => 12}},
          %{"type" => "message_stop"}
        ]

        conn =
          conn
          |> Plug.Conn.put_resp_header("content-type", "text/event-stream")
          |> Plug.Conn.send_chunked(200)

        Enum.reduce(events, conn, fn event, conn ->
          {:ok, conn} = Plug.Conn.chunk(conn, "data: #{Jason.encode!(event)}\n\n")
          conn
        end)
      else
        # Title call on the cheap tier.
        Req.Test.json(conn, %{
          "content" => [%{"type" => "text", "text" => "Test Chat"}],
          "model" => "claude-haiku-4-5",
          "stop_reason" => "end_turn",
          "usage" => %{}
        })
      end
    end)
  end

  defp stream_sse(conn, events) do
    conn =
      conn
      |> Plug.Conn.put_resp_header("content-type", "text/event-stream")
      |> Plug.Conn.send_chunked(200)

    Enum.reduce(events, conn, fn event, conn ->
      {:ok, conn} = Plug.Conn.chunk(conn, "data: #{Jason.encode!(event)}\n\n")
      conn
    end)
  end

  defp render_until(view, needle, tries \\ 50) do
    html = render(view)

    cond do
      html =~ needle -> html
      tries == 0 -> flunk("timed out waiting for #{inspect(needle)} in:\n#{html}")
      true ->
        Process.sleep(20)
        render_until(view, needle, tries - 1)
    end
  end

  test "first visit shows the opt-in card; enabling creates the MeCP grant", %{
    conn: conn,
    user: user
  } do
    {:ok, view, html} = live(conn, ~p"/qai")

    assert html =~ "Meet Qai"
    assert html =~ "Enable Qai"

    view |> element("form[phx-submit=enable_qai]") |> render_submit(%{})

    grant = Qai.active_grant(user.id, me_file(user).id)
    assert grant
    assert grant.tier == 3
    assert grant.mecp_client.name == "Qai"
    assert grant.mecp_client.client_type == "qai"

    assert render(view) =~ "Message Qai"
  end

  test "sending a message streams a reply, logs a capsule read, and titles the session", %{
    conn: conn,
    user: user
  } do
    {:ok, grant} = Qai.enable(me_file(user).id, user.id)
    stub_completion("Hello back!")

    {:ok, view, _html} = live(conn, ~p"/qai")

    view
    |> element("form[phx-submit=send]")
    |> render_submit(%{"message" => "Hi Qai"})

    html = render_until(view, "Hello back!")
    assert html =~ "Hi Qai"

    [session] = Sessions.list_sessions(me_file(user).id)
    messages = Sessions.list_messages(session.id)
    contents = Enum.map(messages, &{&1.role, &1.content})
    assert {"user", "Hi Qai"} in contents
    assert {"assistant", "Hello back!"} in contents

    # Token usage and the serving model land on the message for economics.
    reply = Enum.find(messages, &(&1.role == "assistant"))
    assert reply.usage["input_tokens"] == 40
    assert reply.usage["output_tokens"] == 12
    assert reply.model == "claude-sonnet-4-6"

    # Dogfooding: the capsule was read through the gateway and logged.
    events = AccessLog.list_events_for_grant(grant.id)
    assert Enum.any?(events, &(&1.kind == "capsule"))

    # The cheap-tier title lands asynchronously.
    render_until(view, "Test Chat")
    assert Qlarius.Repo.reload!(session).title == "Test Chat"
  end

  test "a conversation about updating the MeFile files suggestions into the Builder queue", %{
    conn: conn,
    user: user
  } do
    me_file = me_file(user)
    {:ok, grant} = Qai.enable(me_file.id, user.id)

    # An askable, already-tagged trait: the "eating healthier" update case.
    # nextval could collide with the explicit-id traits from setup; jump past.
    Repo.query!("SELECT setval('traits_id_seq', 1000000)")
    import Qlarius.MeCPFixtures
    category = insert_category!("Eating")
    trait = insert_trait!(category, "Fast Food Frequency")
    insert_tag!(me_file, trait, "Weekly")

    Repo.insert!(%Qlarius.YouData.Surveys.SurveyQuestion{
      text: "How often do you eat fast food?",
      trait_id: trait.id,
      active: "1",
      display_order: 1,
      added_by: 0,
      modified_by: 0
    })

    test_pid = self()

    Req.Test.stub(Qlarius.Qai.Anthropic, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      body = Jason.decode!(body)

      tool_round? =
        not Enum.any?(body["messages"], fn m ->
          is_list(m["content"]) and Enum.any?(m["content"], &(&1["type"] == "tool_result"))
        end)

      cond do
        # The async title call on the cheap tier (non-streaming).
        body["stream"] != true ->
          Req.Test.json(conn, %{
            "content" => [%{"type" => "text", "text" => "Eating Healthier"}],
            "model" => "m",
            "stop_reason" => "end_turn",
            "usage" => %{}
          })

        tool_round? ->
          send(test_pid, {:tools_offered, Enum.map(body["tools"] || [], & &1["name"])})

          input =
            Jason.encode!(%{
              "trait" => "Fast Food Frequency",
              "values" => ["Rarely"],
              "reason" => "You are cutting back on fast food."
            })

          stream_sse(conn, [
            %{"type" => "message_start", "message" => %{"model" => "m", "usage" => %{}}},
            %{"type" => "content_block_start", "index" => 0, "content_block" => %{"type" => "tool_use", "id" => "tu_1", "name" => "suggest_tag"}},
            %{"type" => "content_block_delta", "index" => 0, "delta" => %{"type" => "input_json_delta", "partial_json" => input}},
            %{"type" => "content_block_stop", "index" => 0},
            %{"type" => "message_delta", "delta" => %{"stop_reason" => "tool_use"}, "usage" => %{}},
            %{"type" => "message_stop"}
          ])

        true ->
          stream_sse(conn, [
            %{"type" => "message_start", "message" => %{"model" => "m", "usage" => %{}}},
            %{"type" => "content_block_delta", "index" => 0, "delta" => %{"type" => "text_delta", "text" => "Queued for your review in the Builder."}},
            %{"type" => "message_delta", "delta" => %{"stop_reason" => "end_turn"}, "usage" => %{}},
            %{"type" => "message_stop"}
          ])
      end
    end)

    {:ok, view, _html} = live(conn, ~p"/qai")

    view
    |> element("form[phx-submit=send]")
    |> render_submit(%{"message" => "I'm trying to eat healthier. How should I update my MeFile?"})

    render_until(view, "Queued for your review in the Builder.")

    # The model was offered the shared MeCP tools.
    assert_received {:tools_offered, names}
    assert "suggest_tag" in names and "search_traits" in names

    # The suggestion landed in the Builder queue, marked as an update, filed by Qai.
    alias Qlarius.MeCP.Suggestions
    assert [suggestion] = Suggestions.list_pending_for_me_file(me_file.id)
    assert suggestion.trait_id == trait.id
    assert suggestion.proposed_values == ["Rarely"]
    assert suggestion.grant.mecp_client.name == "Qai"

    assert [entry] = Suggestions.suggested_surveys_for_me_file(me_file.id)
    assert entry.update?

    # And the tool call is in the access log like any counterparty's.
    events = Qlarius.MeCP.AccessLog.list_events_for_grant(grant.id)
    assert Enum.any?(events, &(&1.kind == "suggestion"))
  end

  test "a revoked grant returns the user to the opt-in card", %{conn: conn, user: user} do
    {:ok, grant} = Qai.enable(me_file(user).id, user.id)
    {:ok, _} = Qlarius.MeCP.Grants.revoke_grant(grant)

    {:ok, _view, html} = live(conn, ~p"/qai")
    assert html =~ "Meet Qai"
  end

  test "preserve toggle and history list work", %{conn: conn, user: user} do
    {:ok, _grant} = Qai.enable(me_file(user).id, user.id)
    stub_completion("Sure thing.")

    {:ok, view, _html} = live(conn, ~p"/qai")

    view |> element("form[phx-submit=send]") |> render_submit(%{"message" => "remember this"})
    render_until(view, "Sure thing.")

    [session] = Sessions.list_sessions(me_file(user).id)
    refute Qlarius.Qai.Session.preserved?(session)

    view |> element("button[phx-click=toggle_preserve]") |> render_click()
    assert Qlarius.Qai.Session.preserved?(Qlarius.Repo.reload!(session))

    html = view |> element("button[phx-click=toggle_history]") |> render_click()
    assert html =~ "hero-lock-closed"
  end
end
