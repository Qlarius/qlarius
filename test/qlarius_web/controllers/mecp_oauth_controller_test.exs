defmodule QlariusWeb.MeCPOAuthControllerTest do
  use QlariusWeb.ConnCase, async: true

  import Qlarius.MeCPFixtures

  alias Qlarius.MeCP.OAuth
  alias Qlarius.Repo
  alias Qlarius.YouData.MeFiles.MeFile

  @redirect_uri "https://claude.ai/api/mcp/auth_callback"

  defp pkce_pair do
    verifier = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    challenge = :sha256 |> :crypto.hash(verifier) |> Base.url_encode64(padding: false)
    {verifier, challenge}
  end

  defp register!(conn) do
    conn
    |> put_req_header("content-type", "application/json")
    |> post(~p"/mecp/oauth/register", %{
      "client_name" => "Claude",
      "redirect_uris" => [@redirect_uri]
    })
    |> json_response(201)
  end

  # Full approval via context (the authorize page needs a browser session;
  # its logic lives in OAuth.validate_authorize_request/approve_authorization,
  # covered in oauth_test.exs).
  defp approved_code!(client_id, challenge) do
    me_file = Repo.insert!(%MeFile{})
    oauth_client = OAuth.get_client_by_client_id(client_id)

    {:ok, code, _grant} =
      OAuth.approve_authorization(oauth_client, me_file, %{tier: 3}, %{
        redirect_uri: @redirect_uri,
        code_challenge: challenge,
        state: "xyz"
      })

    code
  end

  describe "discovery metadata" do
    test "protected resource metadata points at the authorization server", %{conn: conn} do
      body = conn |> get(~p"/.well-known/oauth-protected-resource/mecp/mcp") |> json_response(200)

      assert body["resource"] =~ "/mecp/mcp"
      assert [as] = body["authorization_servers"]
      assert String.starts_with?(body["resource"], as)
    end

    test "authorization server metadata advertises PKCE S256 and DCR", %{conn: conn} do
      body = conn |> get(~p"/.well-known/oauth-authorization-server") |> json_response(200)

      assert body["code_challenge_methods_supported"] == ["S256"]
      assert body["token_endpoint_auth_methods_supported"] == ["none"]
      assert body["grant_types_supported"] == ["authorization_code", "refresh_token"]
      assert body["registration_endpoint"] =~ "/mecp/oauth/register"
    end
  end

  describe "dynamic client registration" do
    test "registers a public client", %{conn: conn} do
      body = register!(conn)

      assert body["client_id"]
      assert body["token_endpoint_auth_method"] == "none"
      assert body["redirect_uris"] == [@redirect_uri]
      refute Map.has_key?(body, "client_secret")
    end

    test "rejects non-https redirect uris", %{conn: conn} do
      resp =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/mecp/oauth/register", %{"redirect_uris" => ["http://evil.example/cb"]})

      assert %{"error" => "invalid_client_metadata"} = json_response(resp, 400)
    end
  end

  describe "token endpoint" do
    test "exchanges a code with PKCE and the access token works on /mecp/mcp", %{conn: conn} do
      %{"client_id" => client_id} = register!(conn)
      {verifier, challenge} = pkce_pair()
      code = approved_code!(client_id, challenge)

      body =
        build_conn()
        |> post(~p"/mecp/oauth/token", %{
          "grant_type" => "authorization_code",
          "client_id" => client_id,
          "code" => code,
          "code_verifier" => verifier,
          "redirect_uri" => @redirect_uri
        })
        |> json_response(200)

      assert %{
               "access_token" => access,
               "token_type" => "Bearer",
               "refresh_token" => _refresh,
               "expires_in" => 3600
             } = body

      # The OAuth access token authenticates the MCP endpoint.
      mcp =
        build_conn()
        |> put_req_header("authorization", "Bearer #{access}")
        |> put_req_header("content-type", "application/json")
        |> post("/mecp/mcp", Jason.encode!(%{"jsonrpc" => "2.0", "id" => 1, "method" => "ping"}))
        |> json_response(200)

      assert %{"result" => %{}} = mcp
    end

    test "wrong verifier fails; replayed code revokes issued tokens", %{conn: conn} do
      %{"client_id" => client_id} = register!(conn)
      {verifier, challenge} = pkce_pair()
      code = approved_code!(client_id, challenge)

      assert %{"error" => "invalid_grant"} =
               build_conn()
               |> post(~p"/mecp/oauth/token", %{
                 "grant_type" => "authorization_code",
                 "client_id" => client_id,
                 "code" => code,
                 "code_verifier" => "wrong-verifier",
                 "redirect_uri" => @redirect_uri
               })
               |> json_response(400)

      # Legitimate exchange succeeds...
      %{"access_token" => access} =
        build_conn()
        |> post(~p"/mecp/oauth/token", %{
          "grant_type" => "authorization_code",
          "client_id" => client_id,
          "code" => code,
          "code_verifier" => verifier,
          "redirect_uri" => @redirect_uri
        })
        |> json_response(200)

      # ...but replaying the same code fails and revokes the minted token.
      assert %{"error" => "invalid_grant"} =
               build_conn()
               |> post(~p"/mecp/oauth/token", %{
                 "grant_type" => "authorization_code",
                 "client_id" => client_id,
                 "code" => code,
                 "code_verifier" => verifier,
                 "redirect_uri" => @redirect_uri
               })
               |> json_response(400)

      assert OAuth.verify_access_token(access) == nil
    end

    test "refresh rotates the pair and kills the old refresh token", %{conn: conn} do
      %{"client_id" => client_id} = register!(conn)
      {verifier, challenge} = pkce_pair()
      code = approved_code!(client_id, challenge)

      %{"access_token" => access1, "refresh_token" => refresh1} =
        build_conn()
        |> post(~p"/mecp/oauth/token", %{
          "grant_type" => "authorization_code",
          "client_id" => client_id,
          "code" => code,
          "code_verifier" => verifier,
          "redirect_uri" => @redirect_uri
        })
        |> json_response(200)

      %{"access_token" => access2, "refresh_token" => refresh2} =
        build_conn()
        |> post(~p"/mecp/oauth/token", %{
          "grant_type" => "refresh_token",
          "client_id" => client_id,
          "refresh_token" => refresh1
        })
        |> json_response(200)

      assert access2 != access1
      assert refresh2 != refresh1
      assert OAuth.verify_access_token(access1) == nil
      assert OAuth.verify_access_token(access2)

      assert %{"error" => "invalid_grant"} =
               build_conn()
               |> post(~p"/mecp/oauth/token", %{
                 "grant_type" => "refresh_token",
                 "client_id" => client_id,
                 "refresh_token" => refresh1
               })
               |> json_response(400)
    end

    test "unsupported grant type", %{conn: conn} do
      assert %{"error" => "unsupported_grant_type"} =
               conn
               |> post(~p"/mecp/oauth/token", %{"grant_type" => "password"})
               |> json_response(400)
    end
  end

  describe "CORS for browser-driven MCP clients" do
    test "MCP endpoint answers cross-origin preflight with wildcard, no credentials", %{
      conn: conn
    } do
      conn =
        conn
        |> put_req_header("origin", "https://claude.ai")
        |> put_req_header("access-control-request-method", "POST")
        |> put_req_header("access-control-request-headers", "authorization,content-type")
        |> options("/mecp/mcp")

      assert get_resp_header(conn, "access-control-allow-origin") == ["*"]
      assert get_resp_header(conn, "access-control-allow-credentials") == []
      assert [exposed] = get_resp_header(conn, "access-control-expose-headers")
      assert exposed =~ "www-authenticate"
    end

    test "discovery and token endpoints carry wildcard CORS on responses", %{conn: conn} do
      resp =
        conn
        |> put_req_header("origin", "https://chatgpt.com")
        |> get(~p"/.well-known/oauth-authorization-server")

      assert json_response(resp, 200)
      assert get_resp_header(resp, "access-control-allow-origin") == ["*"]

      resp =
        build_conn()
        |> put_req_header("origin", "https://claude.ai")
        |> post(~p"/mecp/oauth/token", %{"grant_type" => "password"})

      assert get_resp_header(resp, "access-control-allow-origin") == ["*"]
    end

    test "app routes keep the credentialed allowlist (claude.ai NOT allowed)", %{conn: conn} do
      conn =
        conn
        |> put_req_header("origin", "https://claude.ai")
        |> get("/login")

      assert get_resp_header(conn, "access-control-allow-origin") == []
    end
  end

  describe "MCP 401 discovery hint" do
    test "unauthorized responses point at the resource metadata", %{conn: conn} do
      _ctx = seed!(%{scope: %{}})

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/mecp/mcp", Jason.encode!(%{"jsonrpc" => "2.0", "id" => 1, "method" => "ping"}))

      assert json_response(conn, 401)
      assert [header] = get_resp_header(conn, "www-authenticate")
      assert header =~ ~s(resource_metadata=")
      assert header =~ "/.well-known/oauth-protected-resource/mecp/mcp"
    end
  end
end
