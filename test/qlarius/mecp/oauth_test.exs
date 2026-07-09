defmodule Qlarius.MeCP.OAuthTest do
  use Qlarius.DataCase, async: true

  alias Qlarius.MeCP.Grants
  alias Qlarius.MeCP.OAuth
  alias Qlarius.YouData.MeFiles.MeFile

  @redirect_uri "https://chatgpt.com/connector_platform_oauth_redirect"

  defp register!(attrs \\ %{}) do
    {:ok, client} =
      attrs
      |> Enum.into(%{"client_name" => "ChatGPT", "redirect_uris" => [@redirect_uri]})
      |> OAuth.register_client()

    client
  end

  defp pkce_pair do
    verifier = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    challenge = :sha256 |> :crypto.hash(verifier) |> Base.url_encode64(padding: false)
    {verifier, challenge}
  end

  defp authorize_params(client, challenge) do
    %{
      "client_id" => client.client_id,
      "redirect_uri" => @redirect_uri,
      "response_type" => "code",
      "code_challenge" => challenge,
      "code_challenge_method" => "S256",
      "state" => "abc123"
    }
  end

  describe "register_client/1" do
    test "creates the fronting mecp_client counterparty" do
      client = register!()
      client = Repo.preload(client, :mecp_client)

      assert client.mecp_client.client_type == "byo_assistant"
      assert client.mecp_client.status == "active"
      assert client.mecp_client.name == "ChatGPT"
      assert client.token_endpoint_auth_method == "none"
    end

    test "rejects empty or non-https redirect uris, allowing http loopback" do
      assert {:error, _} = OAuth.register_client(%{"redirect_uris" => []})
      assert {:error, _} = OAuth.register_client(%{"redirect_uris" => ["http://a.example/cb"]})
      assert {:ok, _} = OAuth.register_client(%{"redirect_uris" => ["http://localhost:3000/cb"]})
    end
  end

  describe "validate_authorize_request/1" do
    setup do
      {_verifier, challenge} = pkce_pair()
      %{client: register!(), challenge: challenge}
    end

    test "accepts a well-formed request", %{client: client, challenge: challenge} do
      assert {:ok, returned_client, checked} =
               OAuth.validate_authorize_request(authorize_params(client, challenge))

      assert returned_client.id == client.id
      assert checked.redirect_uri == @redirect_uri
      assert checked.code_challenge == challenge
      assert checked.state == "abc123"
    end

    test "refuses unknown client, foreign redirect_uri, missing PKCE", %{
      client: client,
      challenge: challenge
    } do
      params = authorize_params(client, challenge)

      assert {:error, :unknown_client} =
               OAuth.validate_authorize_request(%{params | "client_id" => "nope"})

      assert {:error, :unregistered_redirect_uri} =
               OAuth.validate_authorize_request(%{
                 params
                 | "redirect_uri" => "https://evil.example/cb"
               })

      assert {:error, :missing_pkce_challenge} =
               OAuth.validate_authorize_request(Map.delete(params, "code_challenge"))

      assert {:error, :unsupported_challenge_method} =
               OAuth.validate_authorize_request(%{params | "code_challenge_method" => "plain"})
    end
  end

  describe "approve_authorization/5" do
    test "creates a grant bound to the OAuth client's counterparty" do
      client = register!()
      me_file = Repo.insert!(%MeFile{})
      {_verifier, challenge} = pkce_pair()

      demo_scope = %{tier: 2, category_ids: [42], budget_max: 10}

      {:ok, code, grant} =
        OAuth.approve_authorization(client, me_file, demo_scope, %{
          redirect_uri: @redirect_uri,
          code_challenge: challenge,
          state: nil
        })

      assert is_binary(code)
      assert grant.me_file_id == me_file.id
      assert grant.mecp_client_id == client.mecp_client_id
      assert grant.tier == 2
      assert grant.scope == %{"category_ids" => [42]}
      assert grant.budget == %{"period" => "day", "max" => 10}
    end
  end

  describe "exchange_code/5" do
    test "expired code refuses" do
      client = register!()
      me_file = Repo.insert!(%MeFile{})
      {verifier, challenge} = pkce_pair()

      # Approve 11 minutes in the past so the 10-minute code TTL has lapsed.
      past = DateTime.add(DateTime.utc_now(), -660)

      {:ok, code, _grant} =
        OAuth.approve_authorization(
          client,
          me_file,
          %{},
          %{redirect_uri: @redirect_uri, code_challenge: challenge, state: nil},
          past
        )

      assert {:error, :invalid_grant} =
               OAuth.exchange_code(client.client_id, code, verifier, @redirect_uri)
    end

    test "code bound to another client refuses" do
      client_a = register!()
      client_b = register!(%{"client_name" => "Other"})
      me_file = Repo.insert!(%MeFile{})
      {verifier, challenge} = pkce_pair()

      {:ok, code, _grant} =
        OAuth.approve_authorization(client_a, me_file, %{}, %{
          redirect_uri: @redirect_uri,
          code_challenge: challenge,
          state: nil
        })

      assert {:error, :invalid_grant} =
               OAuth.exchange_code(client_b.client_id, code, verifier, @redirect_uri)
    end
  end

  describe "verify_access_token/1" do
    test "resolves to the grant; revoking the grant is still enforced downstream" do
      client = register!()
      me_file = Repo.insert!(%MeFile{})
      {verifier, challenge} = pkce_pair()

      {:ok, code, grant} =
        OAuth.approve_authorization(client, me_file, %{}, %{
          redirect_uri: @redirect_uri,
          code_challenge: challenge,
          state: nil
        })

      {:ok, %{"access_token" => access}} =
        OAuth.exchange_code(client.client_id, code, verifier, @redirect_uri)

      resolved = OAuth.verify_access_token(access)
      assert resolved.id == grant.id

      # Grant revocation gates the gateway even while the token is unexpired.
      {:ok, revoked} = Grants.revoke_grant(resolved)
      assert {:error, :revoked} = Grants.check(revoked, :oracle)
    end

    test "expired access token resolves to nil" do
      client = register!()
      me_file = Repo.insert!(%MeFile{})
      {verifier, challenge} = pkce_pair()

      {:ok, code, _grant} =
        OAuth.approve_authorization(client, me_file, %{}, %{
          redirect_uri: @redirect_uri,
          code_challenge: challenge,
          state: nil
        })

      # Exchange 2 hours in the past: the 1-hour access token is already stale.
      past = DateTime.add(DateTime.utc_now(), -7200)

      {:ok, %{"access_token" => access}} =
        OAuth.exchange_code(client.client_id, code, verifier, @redirect_uri, past)

      assert OAuth.verify_access_token(access) == nil
    end
  end
end
