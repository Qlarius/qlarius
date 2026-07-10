defmodule Qlarius.MeCP.OAuth do
  @moduledoc """
  Minimal OAuth 2.1 authorization server for MCP remote connectors
  (build plan Phase 1: Claude and ChatGPT custom connectors).

  Shape verified against client requirements (July 2026): dynamic client
  registration (RFC 7591), PKCE S256 only, public clients
  (`token_endpoint_auth_method: "none"`), authorization_code + refresh_token
  grants, discovery via protected resource metadata (RFC 9728) and
  authorization server metadata (RFC 8414). The web layer serves metadata and
  the approval UI; this module owns all state transitions.

  The user's approval step IS connector onboarding: approving creates the
  `mecp_grant` (scope, tier, budget), and every token minted here stays bound
  to that grant, so revoking the grant kills OAuth access instantly.
  """

  import Ecto.Query

  alias Qlarius.MeCP.Clients
  alias Qlarius.MeCP.Grants
  alias Qlarius.MeCP.Grants.Grant
  alias Qlarius.MeCP.OAuth.{OAuthClient, OAuthCode, OAuthToken}
  alias Qlarius.Repo
  alias Qlarius.YouData.MeFiles.MeFile

  @code_ttl_seconds 600
  @access_token_ttl_seconds 3600

  @doc false
  def access_token_ttl_seconds, do: @access_token_ttl_seconds

  # --- dynamic client registration (RFC 7591) --------------------------------

  @doc """
  Registers an OAuth client from DCR metadata. Creates the fronting
  `mecp_clients` counterparty row in the same transaction.

  Accepts string-keyed metadata as POSTed: `redirect_uris` (required),
  `client_name` (optional). Returns `{:ok, oauth_client}` or
  `{:error, changeset}`.
  """
  def register_client(metadata) when is_map(metadata) do
    client_name = metadata["client_name"] || "Unnamed MCP client"

    Repo.transaction(fn ->
      with {:ok, mecp_client} <-
             Clients.create_client(%{
               name: client_name,
               client_type: "byo_assistant",
               status: "active"
             }),
           {:ok, oauth_client} <-
             %OAuthClient{}
             |> OAuthClient.changeset(%{
               client_id: generate_secret(16),
               client_name: client_name,
               redirect_uris: metadata["redirect_uris"],
               registration_metadata:
                 Map.take(metadata, ~w(client_name client_uri redirect_uris)),
               mecp_client_id: mecp_client.id
             })
             |> Repo.insert() do
        oauth_client
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  def get_client_by_client_id(client_id) when is_binary(client_id) do
    Repo.get_by(OAuthClient, client_id: client_id)
  end

  def get_client_by_client_id(_), do: nil

  # --- authorization ----------------------------------------------------------

  @doc """
  Validates the query params of an authorization request (GET /authorize).

  Returns `{:ok, oauth_client, checked_params}` or `{:error, reason}` where
  reason is an atom suitable for showing the user. Per OAuth 2.1, errors in
  client_id/redirect_uri must NOT redirect; the caller shows an error page.
  """
  def validate_authorize_request(params) do
    with {:client, %OAuthClient{} = client} <-
           {:client, get_client_by_client_id(params["client_id"])},
         {:redirect_uri, uri} when is_binary(uri) <-
           {:redirect_uri, params["redirect_uri"]},
         {:redirect_uri_registered, true} <-
           {:redirect_uri_registered, uri in client.redirect_uris},
         {:response_type, "code"} <- {:response_type, params["response_type"]},
         {:challenge, challenge} when is_binary(challenge) and challenge != "" <-
           {:challenge, params["code_challenge"]},
         {:challenge_method, "S256"} <-
           {:challenge_method, params["code_challenge_method"] || "S256"} do
      {:ok, client,
       %{
         redirect_uri: uri,
         code_challenge: challenge,
         state: params["state"]
       }}
    else
      {:client, _} -> {:error, :unknown_client}
      {:redirect_uri, _} -> {:error, :missing_redirect_uri}
      {:redirect_uri_registered, _} -> {:error, :unregistered_redirect_uri}
      {:response_type, _} -> {:error, :unsupported_response_type}
      {:challenge, _} -> {:error, :missing_pkce_challenge}
      {:challenge_method, _} -> {:error, :unsupported_challenge_method}
    end
  end

  @doc """
  User approved: creates the grant (connector onboarding) and mints the
  single-use authorization code.

  `grant_attrs` uses the same shape as `MeCP.create_connector/2`
  (`:tier`, `:category_ids`, `:budget_max`). Returns
  `{:ok, plaintext_code, grant}`.
  """
  def approve_authorization(
        %OAuthClient{} = oauth_client,
        %MeFile{} = me_file,
        grant_attrs,
        checked_params,
        now \\ DateTime.utc_now()
      ) do
    scope =
      case grant_attrs[:category_ids] do
        ids when is_list(ids) and ids != [] -> %{"category_ids" => ids}
        _ -> %{}
      end

    budget =
      case grant_attrs[:budget_max] do
        max when is_integer(max) and max >= 0 -> %{"period" => "day", "max" => max}
        _ -> %{}
      end

    code = generate_secret(32)

    Repo.transaction(fn ->
      with {:ok, grant} <-
             Grants.create_grant(%{
               me_file_id: me_file.id,
               mecp_client_id: oauth_client.mecp_client_id,
               user_id: grant_attrs[:user_id],
               scope: scope,
               tier: grant_attrs[:tier] || 3,
               budget: budget
             }),
           {:ok, _code_row} <-
             %OAuthCode{}
             |> OAuthCode.changeset(%{
               code_hash: hash(code),
               redirect_uri: checked_params.redirect_uri,
               code_challenge: checked_params.code_challenge,
               code_challenge_method: "S256",
               expires_at: DateTime.add(now, @code_ttl_seconds) |> DateTime.truncate(:second),
               mecp_oauth_client_id: oauth_client.id,
               mecp_grant_id: grant.id
             })
             |> Repo.insert() do
        {code, grant}
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
    |> case do
      {:ok, {code, grant}} -> {:ok, code, grant}
      {:error, changeset} -> {:error, changeset}
    end
  end

  # --- token endpoint ------------------------------------------------------------

  @doc """
  authorization_code exchange with PKCE verification. Single-use: a replayed
  code fails and, per OAuth 2.1, revokes every token already minted from it.

  Returns `{:ok, token_response_map}` or `{:error, oauth_error_atom}`.
  """
  def exchange_code(client_id, code, verifier, redirect_uri, now \\ DateTime.utc_now()) do
    with %OAuthClient{} = client <-
           get_client_by_client_id(client_id) || {:error, :invalid_client},
         %OAuthCode{} = code_row <-
           Repo.get_by(OAuthCode, code_hash: hash(code || "")) || {:error, :invalid_grant},
         true <- code_row.mecp_oauth_client_id == client.id || {:error, :invalid_grant},
         :ok <- check_code_replay(code_row),
         true <-
           DateTime.before?(now, code_row.expires_at) || {:error, :invalid_grant},
         true <- code_row.redirect_uri == redirect_uri || {:error, :invalid_grant},
         :ok <- verify_pkce(code_row.code_challenge, verifier) do
      {:ok, _} =
        code_row
        |> Ecto.Changeset.change(used_at: DateTime.truncate(now, :second))
        |> Repo.update()

      mint_tokens(client.id, code_row.mecp_grant_id, now)
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_grant}
    end
  end

  @doc """
  refresh_token grant: rotates the pair. The old row is revoked in the same
  transaction the new one is minted.
  """
  def refresh(client_id, refresh_token, now \\ DateTime.utc_now()) do
    with %OAuthClient{} = client <-
           get_client_by_client_id(client_id) || {:error, :invalid_client},
         %OAuthToken{} = token_row <-
           Repo.get_by(OAuthToken, refresh_token_hash: hash(refresh_token || "")) ||
             {:error, :invalid_grant},
         true <- token_row.mecp_oauth_client_id == client.id || {:error, :invalid_grant},
         true <- is_nil(token_row.revoked_at) || {:error, :invalid_grant} do
      Repo.transaction(fn ->
        {:ok, _} =
          token_row
          |> Ecto.Changeset.change(revoked_at: DateTime.truncate(now, :second))
          |> Repo.update()

        case mint_tokens(client.id, token_row.mecp_grant_id, now) do
          {:ok, response} -> response
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_grant}
    end
  end

  @doc """
  Resolves a bearer access token to its grant (client preloaded), or nil.
  Checks token expiry and revocation; grant-level checks (tier, revocation,
  budget) stay with the gateway as usual.
  """
  def verify_access_token(token) when is_binary(token) do
    now = DateTime.utc_now()

    Repo.one(
      from g in Grant,
        join: t in OAuthToken,
        on: t.mecp_grant_id == g.id,
        where:
          t.access_token_hash == ^hash(token) and
            is_nil(t.revoked_at) and
            t.expires_at > ^now,
        preload: [:mecp_client]
    )
  end

  def verify_access_token(_), do: nil

  # --- internals ---------------------------------------------------------------

  defp mint_tokens(oauth_client_id, grant_id, now) do
    access = "mecp_at_" <> generate_secret(32)
    refresh = "mecp_rt_" <> generate_secret(32)

    with {:ok, _row} <-
           %OAuthToken{}
           |> OAuthToken.changeset(%{
             access_token_hash: hash(access),
             refresh_token_hash: hash(refresh),
             expires_at:
               DateTime.add(now, @access_token_ttl_seconds) |> DateTime.truncate(:second),
             mecp_oauth_client_id: oauth_client_id,
             mecp_grant_id: grant_id
           })
           |> Repo.insert() do
      {:ok,
       %{
         "access_token" => access,
         "token_type" => "Bearer",
         "expires_in" => @access_token_ttl_seconds,
         "refresh_token" => refresh
       }}
    end
  end

  # OAuth 2.1: a replayed code must revoke everything minted from it.
  defp check_code_replay(%OAuthCode{used_at: nil}), do: :ok

  defp check_code_replay(%OAuthCode{} = code_row) do
    Repo.update_all(
      from(t in OAuthToken,
        where:
          t.mecp_grant_id == ^code_row.mecp_grant_id and
            t.mecp_oauth_client_id == ^code_row.mecp_oauth_client_id and
            is_nil(t.revoked_at)
      ),
      set: [revoked_at: DateTime.truncate(DateTime.utc_now(), :second)]
    )

    {:error, :invalid_grant}
  end

  defp verify_pkce(challenge, verifier) when is_binary(verifier) and verifier != "" do
    computed =
      :sha256
      |> :crypto.hash(verifier)
      |> Base.url_encode64(padding: false)

    if Plug.Crypto.secure_compare(computed, challenge) do
      :ok
    else
      {:error, :invalid_grant}
    end
  end

  defp verify_pkce(_, _), do: {:error, :invalid_grant}

  defp hash(value) do
    :sha256 |> :crypto.hash(value) |> Base.encode16(case: :lower)
  end

  defp generate_secret(bytes) do
    bytes |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end
end
