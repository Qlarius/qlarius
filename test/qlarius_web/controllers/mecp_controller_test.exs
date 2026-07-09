defmodule QlariusWeb.MeCPControllerTest do
  use QlariusWeb.ConnCase, async: true

  import Qlarius.MeCPFixtures

  alias Qlarius.MeCP.{AccessLog, Grants, Terms}
  alias Qlarius.MeCP.Terms.TermsAgreement
  alias Qlarius.Repo

  @path "/mecp/mcp"

  defp seed_with_token!(grant_attrs, opts \\ []) do
    ctx = seed!(grant_attrs, opts)
    {:ok, token, grant} = Grants.issue_token(ctx.grant)
    %{ctx | grant: grant} |> Map.put(:token, token)
  end

  defp rpc(conn, token, body) do
    conn
    |> put_req_header("authorization", "Bearer #{token}")
    |> put_req_header("content-type", "application/json")
    |> post(@path, Jason.encode!(body))
  end

  defp rpc_request(method, params \\ %{}, id \\ 1) do
    %{"jsonrpc" => "2.0", "id" => id, "method" => method, "params" => params}
  end

  defp call_tool(conn, token, name, arguments) do
    conn
    |> rpc(token, rpc_request("tools/call", %{"name" => name, "arguments" => arguments}))
    |> json_response(200)
  end

  # --- auth -------------------------------------------------------------------

  describe "authentication" do
    test "refuses without a token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(@path, Jason.encode!(rpc_request("ping")))

      assert %{"error" => %{"message" => "unauthorized"}} = json_response(conn, 401)
      assert [header] = get_resp_header(conn, "www-authenticate")
      assert header =~ ~r/^Bearer resource_metadata=/
    end

    test "refuses a bad token", %{conn: conn} do
      _ctx = seed_with_token!(%{scope: %{}})
      conn = rpc(conn, "mecp_not_a_real_token", rpc_request("ping"))
      assert json_response(conn, 401)
    end

    test "a valid grant-bound token authenticates", %{conn: conn} do
      ctx = seed_with_token!(%{scope: %{}})
      conn = rpc(conn, ctx.token, rpc_request("ping"))
      assert %{"result" => %{}} = json_response(conn, 200)
    end

    test "GET is not supported (no SSE stream in v1)", %{conn: conn} do
      assert conn |> get(@path) |> response(405)
    end
  end

  # --- lifecycle ----------------------------------------------------------------

  describe "initialize" do
    test "negotiates protocol version, carries instructions, logs a handshake", %{conn: conn} do
      ctx =
        seed_with_token!(%{scope: %{}},
          client: insert_client!(%{myterms_roster_ref: "cc-myterms-ai-v1"})
        )

      body =
        conn
        |> rpc(ctx.token, rpc_request("initialize", %{"protocolVersion" => "2025-06-18"}))
        |> json_response(200)

      assert %{
               "result" => %{
                 "protocolVersion" => "2025-06-18",
                 "serverInfo" => %{"name" => "mecp"},
                 "capabilities" => %{"tools" => %{}},
                 "instructions" => instructions
               }
             } = body

      assert instructions =~ "Do not retain"
      assert instructions =~ "cc-myterms-ai-v1"

      assert [event] = AccessLog.list_events_for_grant(ctx.grant.id)
      assert event.kind == "handshake"
    end

    test "unsupported requested version falls back to the newest supported", %{conn: conn} do
      ctx = seed_with_token!(%{scope: %{}})

      body =
        conn
        |> rpc(ctx.token, rpc_request("initialize", %{"protocolVersion" => "1999-01-01"}))
        |> json_response(200)

      assert body["result"]["protocolVersion"] == "2025-06-18"
    end

    test "notifications/initialized records the MyTerms acknowledgment", %{conn: conn} do
      ctx =
        seed_with_token!(%{scope: %{}},
          client: insert_client!(%{myterms_roster_ref: "cc-myterms-ai-v1"})
        )

      notification = %{"jsonrpc" => "2.0", "method" => "notifications/initialized"}
      conn = rpc(conn, ctx.token, notification)
      assert response(conn, 202)

      assert [agreement] = Repo.all(TermsAgreement)
      assert agreement.mecp_client_id == ctx.client.id
      assert agreement.me_file_id == ctx.me_file.id
      assert agreement.roster_agreement_ref == "cc-myterms-ai-v1"
      assert agreement.agreed_at

      # Idempotent on repeat.
      rpc(build_conn(), ctx.token, notification)
      assert length(Repo.all(TermsAgreement)) == 1
    end
  end

  # --- tools ----------------------------------------------------------------------

  describe "tools/list" do
    test "exposes get_capsule and ask_me", %{conn: conn} do
      ctx = seed_with_token!(%{scope: %{}})

      body = conn |> rpc(ctx.token, rpc_request("tools/list")) |> json_response(200)

      assert [%{"name" => "ask_me"}, %{"name" => "get_capsule"}] =
               body["result"]["tools"] |> Enum.sort_by(& &1["name"])
    end
  end

  describe "tools/call get_capsule" do
    test "returns the scoped capsule with the do-not-retain preamble", %{conn: conn} do
      ctx = seed_with_token!(%{tier: 3, scope: %{}})

      body = call_tool(conn, ctx.token, "get_capsule", %{})

      assert %{
               "result" => %{
                 "isError" => false,
                 "content" => [%{"type" => "text", "text" => text}]
               }
             } =
               body

      assert text =~ "Do not retain"
      assert text =~ "Renter"
      assert text =~ "Dog"
    end

    test "refuses below tier 3 as a tool error, not a transport error", %{conn: conn} do
      ctx = seed_with_token!(%{tier: 2, scope: %{}})

      body = call_tool(conn, ctx.token, "get_capsule", %{})

      assert %{"result" => %{"isError" => true, "content" => [%{"text" => text}]}} = body
      assert text == "refused: insufficient_tier"
    end
  end

  describe "tools/call ask_me" do
    test "answers a structured question in a preambled envelope", %{conn: conn} do
      ctx = seed_with_token!(%{tier: 2, scope: %{}})

      body =
        call_tool(conn, ctx.token, "ask_me", %{
          "form" => "has_trait",
          "trait_id" => ctx.housing.id
        })

      assert %{"result" => %{"isError" => false, "content" => [%{"text" => text}]}} = body
      envelope = Jason.decode!(text)
      assert envelope["answer"] == true
      assert envelope["form"] == "has_trait"
      assert envelope["preamble"] =~ "Do not retain"
    end

    test "bucket answers disclose the label only", %{conn: conn} do
      ctx = seed_with_token!(%{tier: 2, scope: %{}})

      body =
        call_tool(conn, ctx.token, "ask_me", %{
          "form" => "bucket",
          "trait_id" => ctx.pets.id,
          "buckets" => [
            %{"label" => "no_pets", "values" => ["None"]},
            %{"label" => "has_pets", "values" => ["Dog", "Cat"]}
          ]
        })

      envelope = body["result"]["content"] |> hd() |> Map.fetch!("text") |> Jason.decode!()
      assert envelope["answer"] == "has_pets"
      refute inspect(envelope) =~ "\"Dog\""
    end

    test "budget exhaustion and bad arguments surface as tool errors", %{conn: conn} do
      ctx = seed_with_token!(%{tier: 2, scope: %{}, budget: %{"max" => 1}})
      args = %{"form" => "has_trait", "trait_id" => ctx.housing.id}

      assert %{"result" => %{"isError" => false}} = call_tool(conn, ctx.token, "ask_me", args)

      assert %{
               "result" => %{
                 "isError" => true,
                 "content" => [%{"text" => "refused: budget_exhausted"}]
               }
             } =
               call_tool(build_conn(), ctx.token, "ask_me", args)

      assert %{"result" => %{"isError" => true}} =
               call_tool(build_conn(), ctx.token, "ask_me", %{
                 "form" => "value_in",
                 "trait_id" => ctx.pets.id
               })
    end

    test "access events carry the terms agreement once acknowledged", %{conn: conn} do
      ctx =
        seed_with_token!(%{tier: 2, scope: %{}},
          client: insert_client!(%{myterms_roster_ref: "cc-myterms-ai-v1"})
        )

      rpc(conn, ctx.token, %{"jsonrpc" => "2.0", "method" => "notifications/initialized"})
      agreement_id = Terms.latest_agreement_id(ctx.client.id, ctx.me_file.id)
      assert agreement_id

      call_tool(build_conn(), ctx.token, "ask_me", %{
        "form" => "has_trait",
        "trait_id" => ctx.housing.id
      })

      assert [event] = AccessLog.list_events_for_grant(ctx.grant.id)
      assert event.terms_agreement_id == agreement_id
    end
  end

  # --- protocol edges ---------------------------------------------------------------

  describe "protocol edges" do
    test "unknown method returns -32601; unknown tool refuses", %{conn: conn} do
      ctx = seed_with_token!(%{scope: %{}})

      body = conn |> rpc(ctx.token, rpc_request("resources/list")) |> json_response(200)
      assert %{"error" => %{"code" => -32_601}} = body

      assert %{"result" => %{"isError" => true}} =
               call_tool(build_conn(), ctx.token, "drop_tables", %{})
    end

    test "revoked grant refuses tool calls", %{conn: conn} do
      ctx = seed_with_token!(%{tier: 3, scope: %{}})
      {:ok, _} = Grants.revoke_grant(ctx.grant)

      assert %{"result" => %{"isError" => true, "content" => [%{"text" => "refused: revoked"}]}} =
               call_tool(conn, ctx.token, "get_capsule", %{})
    end
  end
end
